module RPM
  class TransactionError < Exception
  end

  # Handles RPM transaction. Any RPM Database work must be accessed
  # via the Transaction.
  class Transaction
    # Element in transaction (install/remove/update)
    #
    # Transaction Element is valid only while the transaction which
    # this element belongs to is allocated.
    struct Element
      @ptr : LibRPM::TransactionElement

      def initialize(@ptr)
      end
    end

    # Iterator of Transaction Element
    class Iterator
      @ptr : LibRPM::TransactionIterator
      @etype : ElementTypes

      include ::Iterator(Element)

      def initialize(@ptr, @etype)
      end

      def finalize
        @ptr = LibRPM.rpmtsiFree(@ptr)
      end

      def next
        ptr = LibRPM.rpmtsiNext(@ptr, @etype)
        if ptr.null?
          stop
        else
          Element.new(ptr)
        end
      end
    end

    include ::Iterable(Element)
    include ::Enumerable(Element)

    @ptr : LibRPM::Transaction
    @keys : Set(String) = Set(String).new

    # Initialize a new transaction object.
    #
    # You must close the DB with `#close_db` after use.
    # Recommended to use `RPM.transaction` instead.
    def initialize(*, root : String = "/")
      @ptr = LibRPM.rpmtsCreate
      if @ptr.null?
        raise Exception.new("Can't create Transaction")
      end
      LibRPM.rpmtsSetRootDir(@ptr, root)
    end

    def finalize
      close_db
      @ptr = LibRPM.rpmtsFree(@ptr)
    end

    # Run transaction check
    #
    # Raises exception if check errored.
    def check
      rc = LibRPM.rpmtsCheck(@ptr)
      raise TransactionError.new("RPM: Failed to check transaction") if rc != 0
      true
    end

    # Return transaction problems
    #
    # If there are no problems, returns nil.
    def problems?
      ptr = LibRPM.rpmtsProblems(@ptr)
      if LibRPM.rpmpsNumProblems(ptr) == 0
        LibRPM.rpmpsFree(ptr)
        nil
      else
        ProblemSet.new(ptr)
      end
    end

    # Read RPM package file
    #
    # For independent use, `RPM::Package.open`.
    def read_package_file(filename : String | Path) : Package
      filename_str = filename.to_s
      fd = LibRPM.Fopen(filename_str, "r")
      if LibRPM.Ferror(fd) != 0
        raise "#{filename_str}: #{String.new(LibRPM.Fstrerror(fd))}"
      end
      begin
        hdr = uninitialized LibRPM::Header
        rc = LibRPM.rpmReadPackageFile(@ptr, fd, filename_str, pointerof(hdr))
        if rc != LibRPM::RC::OK
          msg = String.build do |str|
            str << "Failed to read package: "
            str << filename_str << ": "
            case rc
            when LibRPM::RC::NOTTRUSTED
              str << "key not trusted"
            when LibRPM::RC::NOKEY
              str << "no pubkey available"
            when LibRPM::RC::NOTFOUND
              str << "not found"
            when LibRPM::RC::FAIL
              str << "failed"
            else
              str << "unknown error"
            end
          end
          raise TransactionError.new(msg)
        end
        Package.new(hdr)
      ensure
        LibRPM.Fclose(fd)
      end
    end

    # Create a new package iterator with given `tag` and `val`
    #
    # Please refer RPM's `rpmtsInitIterator()` function for more
    # details.
    #
    # Some examples are:
    #
    #  * For package tag lookup, use `RPM::DbiTag::Packages`.
    #  * For package name lookup, use `RPM::DbiTag::Name`.
    #  * For filename (fullpath) lookup, use `RPM::DbiTag::BaseNames`.
    #  * To lookup by a specific tag, initialize iterator with
    #    `RPM::DbiTag::Packages`, and use `#regexp` method.
    def init_iterator(tag : DbiTag | DbiTagValue = DbiTag::Packages,
                      val : String | Slice(UInt8) | Nil = nil)
      if val
        it_ptr = LibRPM.rpmtsInitIterator(@ptr, tag, val, val.size)
      else
        it_ptr = LibRPM.rpmtsInitIterator(@ptr, tag, nil, 0)
      end
      # Here, they'll return NULL if nothing is found. So we should
      # safely wrap NULL pointers into MatchIterator for handling not
      # found.
      MatchIterator.new(it_ptr)
    end

    # Init DB iterator, yield block and cleanup.
    #
    # Please refer RPM's `rpmtsInitIterator()` function for more
    # details.
    #
    # Some examples are:
    #
    #  * For package tag lookup, use `RPM::DbiTag::Packages`.
    #  * For package name lookup, use `RPM::DbiTag::Name`.
    #  * For filename (fullpath) lookup, use `RPM::DbiTag::BaseNames`.
    #  * To lookup by a specific tag, initialize iterator with
    #    `RPM::DbiTag::Packages`, and use `#regexp` method.
    def db_iterator(tag = DbiTag::Packages, val = nil, &block : MatchIterator -> _)
      iter = init_iterator(tag, val)
      begin
        yield iter
      ensure
        iter.finalize
      end
    end

    # Returns iterator for transaction elements
    def each(etypes : ElementTypes = ElementTypes::ANY)
      ptr = LibRPM.rpmtsiInit(@ptr)
      Iterator.new(ptr, etypes)
    end

    # Iterate over each transaction element
    def each(etypes : ElementTypes = ElementTypes::ANY, &block)
      iterator = LibRPM.rpmtsiInit(@ptr)
      if !iterator.null?
        begin
          while !(el = LibRPM.rpmtsiNext(iterator, etypes)).null?
            yield Element.new(el)
          end
        ensure
          LibRPM.rpmtsiFree(iterator)
        end
      else
        nil
      end
    end

    # Register a package to be installed
    #
    # `key` should (must?) be the path of the source package.
    def install(pkg : Package, key : String)
      install_element(pkg, key, upgrade: false)
    end

    # Register a package to be upgraded
    #
    # `key` should (must?) be the path of the source package.
    def upgrade(pkg : Package, key : String)
      install_element(pkg, key, upgrade: true)
    end

    # Register all matching packages to be deleted.
    #
    # Note: No package will be rejected (even RPM itself). Exception
    # will be raised when some error occured.
    def delete_by_iterator(iter : MatchIterator)
      iter.each do |header|
        ret = LibRPM.rpmtsAddEraseElement(@ptr, header, iter.offset)
        raise TransactionError.new("Error while adding erase to transaction") if ret != 0
      end
    end

    # Register given package to be deleted.
    def delete(pkg : Package)
      sigmd5 = pkg[DbiTag::SigMD5].as(Slice(UInt8))
      if !sigmd5.empty?
        iter = init_iterator(DbiTag::SigMD5, sigmd5)
      else
        labl = pkg[DbiTag::Label].as(String)
        iter = init_iterator(DbiTag::Label, labl)
      end
      begin
        delete_by_iterator(iter)
      ensure
        iter.finalize
      end
    end

    # Register given package to be deleted (by a name)
    def delete(pkg : String)
      db_iterator(DbiTag::Label, pkg) do |iter|
        delete_by_iterator(iter)
      end
    end

    # Register given dependency to be deleted
    def delete(pkg : Dependency)
      db_iterator(DbiTag::Label, pkg.name) do |iter|
        iter.set_iterator_version(pkg.version)
        delete_by_iterator(iter)
      end
    end

    # Determine package order in the transaction according to
    # dependencies
    #
    # The final order ends up as installed packages followed by
    # removed packages, with packages removed for upgrades immediately
    # following the new package to be installed.
    def order
      LibRPM.rpmtsOrder(@ptr)
    end

    # Free memory needed only for dependency checks and ordering
    def clean
      LibRPM.rpmtsClean(@ptr)
    end

    # Sets rootdir
    #
    # This is possible only while no iterators are bound and no
    # installations and/or deletions are set.
    def root_dir=(dir : String | UInt8*)
      LibRPM.rpmtsSetRootDir(@ptr, dir)
    end

    # Gets rootdir
    #
    # Optimization NOTE: The rootdir will not be cached. Each time
    # this method is called, this method allocates a new memory space
    # to store the rootdir pathname, and return it.
    def root_dir
      String.new(LibRPM.rpmtsRootDir(@ptr))
    end

    # Set transaction flags
    def flags=(flg)
      LibRPM.rpmtsSetFlags(@ptr, flg)
    end

    # Get transaction flags
    def flags
      LibRPM.rpmtsFlags(@ptr)
    end

    # Closes the opened DB handle
    def close_db
      LibRPM.rpmtsCloseDB(@ptr)
      if !LibRPM.rpmtsGetRdb(@ptr).null?
        raise "Database were not closed properly"
      end
    end

    # Base method of install, upgrade and delete
    def install_element(pkg : Package, key : String,
                        *, upgrade : Bool = false)
      raise Exception.new("key #{key} must be unique") if @keys.includes?(key)
      @keys << key

      ret = LibRPM.rpmtsAddInstallElement(@ptr, pkg, key, upgrade, nil)
      raise TransactionError.new("Failed add install element") if ret != 0
      nil
    end

    alias CallbackReturnType = IO::FileDescriptor | Int32 | Nil

    alias Callback = Proc(Package?, CallbackType, UInt64, UInt64, Pointer(Void), CallbackReturnType)

    class CallbackBoxData
      property transaction : Transaction
      property callback : Callback
      property fdt : FileDescriptor?
      property cfd : IO::FileDescriptor?

      def initialize(@transaction, @callback)
      end
    end

    # Sets the callback method (for running under running
    # transaction), and yields the given block. Callback is set only
    # while the block is yielded.
    #
    # For user-friendly way to apply callback, use following form
    # instead:
    # ```crystal
    # ts.commit do |header, type, amount, total, key|
    #   # do something here.
    # end
    # ```
    #
    # WARNING: We notifies `rpmtsRun` (`#commit`) may raises an Exception
    # to the compiler, but raising an exception is highly discouraged.
    # It may break the RPM database.
    #
    # WARNING: Call order (by type) and content of arguments are very
    # different by RPM version.
    def set_notify_callback(closure : Callback?, &block)
      if closure
        box_data = CallbackBoxData.new(self, closure)
        box = Box.box(box_data)
        callback = ->(hdr : LibRPM::Header, type : LibRPM::CallbackType, amount : LibRPM::Loff, total : LibRPM::Loff, key : LibRPM::FnpyKey, data : LibRPM::CallbackData) do
          boxed = Box(CallbackBoxData).unbox(data)

          pkg = nil
          if !hdr.null?
            pkg = Package.new(hdr)
          end

          ret = boxed.callback.call(pkg, type, amount, total, key)

          case type
          when CallbackType::INST_OPEN_FILE
            case ret
            when IO::FileDescriptor
              ino = ret.fd
              boxed.cfd = ret
            when Int32
              ino = ret
            else
              fname = key.as(Pointer(UInt8))
              begin
                filename = String.new(fname)
                fp = ::File.open(filename, "r")
                boxed.cfd = fp
                ino = fp.fd
              rescue e : Exception
                STDERR.puts e.message
                return Pointer(Void).null
              end
            end
            fdt = FileDescriptor.for_fd(ino)
            boxed.fdt = fdt
            fdt.to_unsafe.as(Pointer(Void))
          when CallbackType::INST_CLOSE_FILE
            if boxed.fdt
              fd = boxed.fdt.as(FileDescriptor)
              fd.close
              if (cfd = boxed.cfd)
                cfd.close
              end
            end
            Pointer(Void).null
          else
            Pointer(Void).null
          end
        end
      else
        box = Pointer(Void).null
        callback = ->(hdr : LibRPM::Header, type : LibRPM::CallbackType, amount : LibRPM::Loff, total : LibRPM::Loff, key : LibRPM::FnpyKey, data : LibRPM::CallbackData) do
          LibRPM.rpmShowProgress(hdr, type, amount, total, key, data)
        end
      end
      rc = LibRPM.rpmtsSetNotifyCallback(@ptr, callback, box)
      if rc != 0
        raise Exception.new("Can't set callback")
      end
      begin
        yield
      ensure
        box
        LibRPM.rpmtsSetNotifyCallback(@ptr, nil, nil)
      end
    end

    # Run the pending transaction
    #
    # If callback is not given, default callback will be used.
    #
    # Returns true if transaction has been completed successfully,
    # false if transaction has problem(s).
    #
    # Raises TransactionError if any error(s) occured
    def commit(callback : Callback? = nil)
      rc = 0
      set_notify_callback(callback) do
        rc = LibRPM.rpmtsRun(@ptr, nil, LibRPM::ProbFilterFlags::NONE)
        if rc == 0
          @keys.clear
          LibRPM.rpmtsEmpty(@ptr)
        elsif rc < 0
          msg = String.new(LibRPM.rpmlogMessage)
          raise TransactionError.new(msg)
        end
      end
      rc == 0
    end

    # Run the pending transaction, with given callback.
    #
    # To handle exception, following form will be safe:
    # ```crystal
    # e : Exception? = nil
    # ts.commit do |header, type, amount, total, key|
    #   # do something here.
    #
    #
    # rescue ex : Exception
    #   if e.nil?
    #     e = ex
    #   end
    #   Pointer(Void).null
    # end
    # if e
    #   raise e
    # end
    # ```
    #
    # WARNING: Call order (by type) and content of arguments are very
    # different by RPM version.
    def commit(&block : Callback)
      commit(block)
    end

    # Returns pointer to `rpmts` to
    def to_unsafe
      @ptr
    end
  end

  def self.transaction(root = "/", &block)
    ts = Transaction.new(root: root)
    begin
      yield ts
    ensure
      ts.close_db
    end
  end
end
