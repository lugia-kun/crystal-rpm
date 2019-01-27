module RPM
  class DB
  end

  class Transaction
    getter ptr : LibRPM::Transaction
    property fdt : LibRPM::FD? = nil

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
      LibRPM.rpmtsFree(@ptr)
    end

    def init_iterator
      # Value of 0 is not like "None".
      init_iterator(DbiTag::Packages, nil)
    end

    def init_iterator(tag : DbiTag | DbiTagValue, val : String? = nil)
      it_ptr = LibRPM.rpmtsInitIterator(@ptr, tag, val, 0)
      if it_ptr.null?
        raise Exception.new("Can't init iterator for [#{tag}] -> '#{val}'")
      end

      MatchIterator.new(it_ptr)
    end

    def each_match(key, val, &block)
      itr = init_iterator(key, val)

      return itr unless block_given?

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
        ret = RPM.rpmtsAddEraseElement(@ptr, header.ptr, iterator.offset)
        raise Exception.new("Error while adding erase to transaction") if ret != 0
      end
    end

    def delete(pkg : Package)
      iter = if pkg[DbiTag::SigMD5]
               each_match(DbiTag::SigMD5, pkg[DbiTag::SigMD5])
             else
               each_match(DbiTag::Label, pkg[DbiTag::Label])
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
      DB.new(self)
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
        callback = -> (hdr : LibRPM::Header, type : LibRPM::CallbackType,
                       amount : LibRPM::Loff, total : LibRPM::Loff,
                       key : LibRPM::FnpyKey, data : LibRPM::CallbackData) do
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
        callback = -> (hdr : LibRPM::Header, type : LibRPM::CallbackType,
                       amount : LibRPM::Loff, total : LibRPM::Loff,
                       key : LibRPM::FnpyKey, data : LibRPM::CallbackData) do
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
        if rc < 0
          msg = String.new(LibRPM.rpmlogMessage)
          raise Exception.new("#{self}: #{msg}")
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
