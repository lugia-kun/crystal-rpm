module RPM
  class FileDescriptor
    @fd : LibRPM::FD
    @open : Bool

    def self.open(file, mode)
      ptr = LibRPM.Fopen(file, mode)
      if ptr.null?
        raise Exception.new("Can't open #{file}")
      end
      if LibRPM.Ferror(ptr) != 0
        raise Exception.new(String.new(LibRPM.Fstrerror(ptr)))
      end
      new(ptr)
    end

    def self.for_fd(fd : Int32)
      ptr = LibRPM.fdDup(fd)
      if ptr.null?
        raise Exception.new("Can't bind #{fd}")
      end
      new(ptr)
    end

    def initialize(@fd)
      @open = true
    end

    def opened?
      @open
    end

    def close
      if @open
        LibRPM.Fclose(@fd)
        @open = false
      end
    end

    def finalize
      close
    end

    # Returns pointer to `FD_t` to deal with librpm C API directly.
    def to_unsafe
      @fd
    end
  end
end
