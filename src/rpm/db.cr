module RPM
  class DB
    include Enumerable(DB)

    property ts : Transaction

    def initialize(@ts : Transaction, **opts)
      wrf = opts[:writable]? || false
      wri = wrf ? (LibC::O_RDWR | LibC::O_CREAT) : LibC::O_RDONLY
      LibRPM.rpmtsOpenDB(@ts.ptr, wri)
    end

    def init_iterator
    end

    def close
      LibRPM.rpmtsCloseDB(@ts.ptr)
    end
  end
end
