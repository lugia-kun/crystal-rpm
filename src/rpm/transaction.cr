module RPM
  class DB
  end

  class Transaction
    getter ptr : LibRPM::Transaction
    property fdt : LibRPM::FD? = nil
    @db : DB? = nil

    def initialize(**opts)
      @keys = Set(String).new

      root = opts[:root]?
      root ||= "/"

      @ptr = LibRPM.rpmtsCreate
      if @ptr.null?
        raise Exception.new("Can't create Transaction")
      end

      LibRPM.rpmtsSetRootDir(@ptr, root)
    end

    def finalize
      LibRPM.rpmtsFree(@ptr) unless @ptr.null?
      @ptr = LibRPM::Transaction.null
    end

    def init_iterator
      # Value of 0 is not like "None".
      init_iterator(DbiTag::Packages, nil)
    end

    def init_iterator(tag : DbiTag | DbiTagValue, val : String | Slice(UInt8) | Nil = nil)
      if val
        it_ptr = LibRPM.rpmtsInitIterator(@ptr, tag, val, val.size)
      else
        it_ptr = LibRPM.rpmtsInitIterator(@ptr, tag, nil, 0)
      end
      if it_ptr.null?
        raise Exception.new("Can't init iterator for [#{tag}] -> '#{val}'")
      end

      MatchIterator.new(it_ptr)
    end

    def each_match(key, val)
      self.db.init_iterator(key, val)
    end

    def each_match(key, val, &block)
      itr = self.db.init_iterator(key, val)
      itr.each(&block)
    end

    def each(&block)
      each_match(0, nil, &block)
    end

    def install(pkg : Package, key : String)
      install_element(pkg, key, upgrade: false)
    end

    def upgrade(pkg : Package, key : String)
      install_element(pkg, key, upgrade: true)
    end

    def delete_by_iterator(iter : MatchIterator)
      iter.each do |header|
        ret = LibRPM.rpmtsAddEraseElement(@ptr, header.hdr, iter.offset)
        raise Exception.new("Error while adding erase to transaction") if ret != 0
      end
    end

    def delete(pkg : Package)
      sigmd5 = pkg[DbiTag::SigMD5]
      if !sigmd5.as(Slice(UInt8)).empty?
        iter = each_match(DbiTag::SigMD5, sigmd5.as(Slice(UInt8)))
      else
        labl = pkg[DbiTag::Label].as(String)
        iter = each_match(DbiTag::Label, labl)
      end

      delete_by_iterator(iter)
    end

    def delete(pkg : String)
      iter = each_match(DbiTag::Label, pkg)
      delete_by_iterator(iter)
    end

    def delete(pkg : Dependency)
      iter = each_match(DbiTag::Label, pkg.name).set_iterator_version(pkg.version)
      delete_by_iterator(iter)
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

    def root_dir=(dir : String | UInt8*)
      LibRPM.rpmtsSetRootDir(@ptr, dir)
    end

    def root_dir
      String.new(LibRPM.rpmtsRootDir(@ptr))
    end

    def flags=(flg)
      LibRPM.rpmtsSetFlags(@ptr, flg)
    end

    def flags
      LibRPM.rpmtsFlags(@ptr)
    end

    def db
      @db ||= DB.new(self)
      @db.as(DB)
    end

    def install_element(pkg : Package, key : String, **opts)
      raise Exception.new("#{self}: key #{key} must be unique") if @keys.includes?(key)
      @keys << key

      upgrade = opts[:upgrade]?
      upgrade ||= false

      ret = LibRPM.rpmtsAddInstallElement(@ptr, pkg.hdr, key, upgrade, nil)
      raise Exception.new("Failed add install element") if ret != 0
      nil
    end

    class CallbackData
      property pkg : Package?
      property type : LibRPM::CallbackType
      property amount : LibRPM::Loff
      property total : LibRPM::Loff
      property key : LibRPM::FnpyKey

      def initialize(@pkg, @type, @amount, @total, @key)
      end
    end

    alias Callback = Proc((CallbackData?), IO::FileDescriptor | Pointer(Void))

    class CallbackBoxData
      property transaction : Transaction
      property callback : Callback

      def initialize(@transaction, @callback)
      end
    end

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

          callback_data = CallbackData.new(pkg, type, amount, total, key)
          ret = boxed.callback.call(callback_data)

          case type
          when LibRPM::CallbackType::INST_OPEN_FILE
            case ret
            when IO::FileDescriptor
              ino = ret.as(IO::FileDescriptor).fd
            when Int32
              ino = ret.as(Int32)
            else
              return ret
            end
            fdt = LibRPM.fdDup(ino)
            if fdt.null? || LibRPM.Ferror(fdt) != 0
              errstr = String.new(LibRPM.Fstrerror(fdt))
              raise "Can't use opend file #{key}: #{errstr}"
            end
            boxed.transaction.fdt = fdt
            fdt.as(Pointer(Void))
          when LibRPM::CallbackType::INST_CLOSE_FILE
            if boxed.transaction.fdt
              fd = boxed.transaction.fdt.as(LibRPM::FD)
              LibRPM.Fclose(fd)
            end
            Pointer(Void).null
          else
            ret.as(Pointer(Void))
          end
        end
      else
        box = nil
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

    def commit(callback : Proc? = nil)
      self.flags = TransactionFlags::NONE
      set_notify_callback(callback) do
        rc = LibRPM.rpmtsRun(@ptr, nil, LibRPM::ProbFilterFlags::NONE)
        if rc == 0
          @keys.clear
        elsif rc < 0
          msg = String.new(LibRPM.rpmlogMessage)
          raise Exception.new("#{self}: #{msg}")
        elsif rc > 0
          ps = LibRPM.rpmtsProblems(@ptr)
          psi = LibRPM.rpmpsInitIterator(ps)
          while LibRPM.rpmpsNextIterator(psi) >= 0
            problem = Problem.new(LibRPM.rpmpsGetProblem(psi))
            STDERR.puts problem.str
          end
          LibRPM.rpmpsFreeIterator(psi)
          LibRPM.rpmpsFree(ps)
        end
      end
    end

    def commit(&block)
      commit(block)
    end
  end

  def self.transaction(root = "/", &block)
    ts = Transaction.new
    ts.root_dir = root
    yield ts
  ensure
    unless ts.nil?
      ts.as(Transaction).finalize
    end
  end
end
