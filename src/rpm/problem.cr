module RPM
  class Problem
    property ptr : LibRPM::Problem

    def finalize
      LibRPM.rpmProblemFree(@ptr)
    end

    def self.from_ptr(ptr)
      new(ptr)
    end

    def initialize(@ptr)
    end

    def type
      LibRPM.rpmProblemGetType(@ptr)
    end

    def key
      LibRPM.rpmProblemGetKey(@ptr)
    end

    def str
      m = LibRPM.rpmProblemGetStr(@ptr)
      if m.null?
        "(no problem)"
      else
        String.new(m)
      end
    end

    def to_s
      str
    end

    def <=>(other)
      LibRPM.rpmProblemCompare(@ptr, other.ptr)
    end
  end
end
