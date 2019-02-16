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
