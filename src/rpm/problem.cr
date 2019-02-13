module RPM
  class Problem
    property ptr : LibRPM::Problem

    def finalize
      LibRPM.rpmProblemFree(@ptr)
    end

    def initialize(@ptr)
    end

    def initialize(type, pkg_nevr, key, alt_nevr, str, number)
      ptr = RPM.problem_create(type, pkg_nevr, key, alt_nevr, str, number)
      raise Exception.new("Cannot create RPM problem") if ptr.null?
      @ptr = ptr
    end

    def initialize(type, pkg_nevr, key, dir, file, alt_nevr, number)
      ptr = RPM.problem_create(type, pkg_nevr, key, dir, file, alt_nevr, number)
      raise Exception.new("Cannot create RPM problem") if ptr.null?
      @ptr = ptr
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
      ptr = LibRPM.rpmProblemString(@ptr)
      return "#<RPM::Problem (empty problem)>" if ptr.null?
      begin
        String.new(ptr)
      ensure
        LibC.free(ptr)
      end
    end

    def <=>(other)
      LibRPM.rpmProblemCompare(@ptr, other.ptr)
    end
  end
end
