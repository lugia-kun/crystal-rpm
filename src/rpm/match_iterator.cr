module RPM
  class MatchIterator
    include Enumerable(MatchIterator)

    def initialize(@ptr : LibRPM::DatabaseMatchIterator)
    end

    def finalize
      LibRPM.rpmdbFreeIterator(@ptr)
    end

    def each
      while (pkg = next_iterator)
        yield pkg
      end
    end

    def next_iterator
      pkg_ptr = LibRPM.rpmdbNextIterator(@ptr)
      if !pkg_ptr.null?
        RPM::Package.new(pkg_ptr)
      else
        nil
      end
    end

    def offset
      LibRPM.rpmdbGetIteratorOffset(@ptr)
    end

    def set_iterator_re(tag : DbiTag | DbiTagValue, mode : MireMode, string : String)
      ret = LibRPM.rpmdbSetIteratorRE(@ptr, tag, mode, string)
      raise Exception.new("Error when setting regular expression '#{string}'") if ret != 0
      self
    end

    def regexp(*args)
      set_iterator_re(*args)
    end

    def set_iterator_version(version : RPM::Version)
      # DbiTag does not have Version and Release, but seems accept.
      vertag = DbiTagValue.new(Tag::Version.value)
      reltag = DbiTagValue.new(Tag::Release.value)
      set_iterator_re(vertag, MireMode::DEFAULT, version.v)
      if version.r
        set_iterator_re(reltag, MireMode::DEFAULT, version.r.as(String))
      end
      self
    end

    def version(*args)
      set_iterator_version(*args)
    end
  end
end
