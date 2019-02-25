module RPM
  class DB
    include Enumerable(DB)

    getter ptr : LibRPM::Database
    getter ts : Transaction

    def initialize(ts : Transaction, **opts)
      db = LibRPM.rpmtsGetRdb(ts.ptr)
      wrf = opts[:writable]? || false
      if db.null?
        wri = wrf ? (LibC::O_RDWR | LibC::O_CREAT) : LibC::O_RDONLY
        r = LibRPM.rpmtsOpenDB(ts.ptr, wri)
        raise Exception.new("cannot open rpmdb") if r != 0
        db = LibRPM.rpmtsGetRdb(ts.ptr)
      else
        mode = LibRPM.rpmtsGetDBMode(ts.ptr)
        if wrf && (mode & LibC::O_RDWR) != 0
          raise Exception.new("db is not opened writable")
        end
      end
      @ptr = db
      @ts = ts
    end

    def init_iterator(tag : DbiTag | DbiTagValue, val : String? | Slice(UInt8) = nil) : MatchIterator
      {% if compare_versions(PKGVERSION_COMP, "4.9.0") >= 0 %}
        @ts.init_iterator(tag, val)
      {% else %}
        db = LibRPM.rpmtsGetRdb(@ts.ptr)
        if val
          it_ptr = LibRPM.rpmdbInitIterator(db, tag, val, val.size)
        else
          it_ptr = LibRPM.rpmdbInitIterator(db, tag, nil, 0)
        end
        if it_ptr.null?
          raise Exception.new("Can't init iterator for [#{tag}] -> '#{val}'")
        end

        MatchIterator.new(it_ptr)
      {% end %}
    end

    def ptr
      if @ptr.null?
        @ptr = LibRPM.rpmtsGetRdb(@ts.ptr)
      end
      @ptr
    end

    def closed?
      @ptr.null?
    end

    def close
      LibRPM.rpmtsCloseDB(@ts.ptr)
      @ptr = Pointer(Void).null.as(LibRPM::Database)
    end

    def finalize
      close unless closed?
    end
  end
end
