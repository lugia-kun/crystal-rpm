module RPM
  class DB
    include Enumerable(DB)

    property ts : Transaction

    def initialize(@ts : Transaction, **opts)
      wrf = opts[:writable]? || false
      wri = wrf ? (LibC::O_RDWR | LibC::O_CREAT) : LibC::O_RDONLY
      r = LibRPM.rpmtsOpenDB(@ts.ptr, wri)
      raise Exception.new("cannot open rpmdb") if r != 0
    end

    def init_iterator
    end

    def finalize
      unless ptr.null?
        close
      end
    end

    def ptr
      if @ts.ptr
        LibRPM.rpmtsGetRdb(@ts.ptr)
      else
        Pointer(Void).null
      end
    end

    def closed?
      ptr.null?
    end

    def close
      LibRPM.rpmtsCloseDB(@ts.ptr)
    end

    def finalize
      close unless closed?
    end
  end
end
