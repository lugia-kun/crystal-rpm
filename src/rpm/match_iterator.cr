require "rpm/librpm"

module RPM
  class MatchIterator
    include Enumerable(MatchIterator)

    def initialize(@ptr : LibRPM::DatabaseMatchIterator)
    end

    def finalize
      LibRPM.rpmdbFreeIterator(@ptr)
    end

    def each
      while (pkg = next_itrator)
        yield pkg
      end
    end

    def next_iterator
      pkg_ptr = LibRPM.rpmdbNextIterator(@ptr)
    end

    def offset
      LibRPM.rpmdbGetIteratorOffset(@ptr)
    end
  end
end
