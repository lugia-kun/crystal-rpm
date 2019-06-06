module RPM
  class ProblemSet
  end

  # Stores Problem.
  #
  # Content changed on RPM 4.9
  #
  # RPM 4.9~
  #
  # ========================================================================
  # type          pkg_nevr      alt_nevr        str            number
  # ------------- ------------- --------------- -------------- -------------
  # BADARCH       target pkg    (unused)        arch name      (unused)
  # BADOS         target pkg    (unused)        os name        (unused)
  # PKG_INSTALLED target pkg    (unused)        (unused)       (unused)
  # BADRELOCATE   target pkg    (unused)        relocated path (unused)
  # NF_CONFLICT   target pkg    conflicting pkg file path      (unused)
  # FILE_CONFLICT installed pkg conflicting pkg file path      (unused)
  # OLD_PACKAGE   target pkg    installed pkg   (unused)       (unused)
  # DISKSPACE     target pkg    (unused)        file system    number bytes
  # DISKNODES     target pkg    (unused)        file system    number inodes
  # REQUIRES      (unused)      required pkg    name requires  1 = installed
  # CONFLICT      (unused)      conflict pkg    name conflicts 1 = installed
  # OBSOLETES     (unused)      obsoletes pkg   name obsoleted 1 = installed
  # VERIFY        target pkg    (unused)        content        (unused)
  # ========================================================================
  #
  # ~RPM4.8
  #
  # (note: the function arguments requires dirname and filename
  #  separatedly, but it simply joins them, so set dirname to `nil` is
  #  suffice.)
  #
  # ========================================================================
  # type          pkg_nevr      alt_nevr        str            number
  # ------------- ------------- --------------- -------------- -------------
  # BADARCH       target pkg    (unused)        arch name      (unused)
  # BADOS         target pkg    (unused)        os name        (unused)
  # PKG_INSTALLED target pkg    (unused)        (unused)       (unused)
  # BADRELOCATE   target pkg    (unused)        relocated path (unused)
  # NF_CONFLICT   target pkg    conflicting pkg file path      (unused)
  # FILE_CONFLICT installed pkg conflicting pkg file path      (unused)
  # OLD_PACKAGE   target pkg    installed pkg   (unused)       (unused)
  # DISKSPACE     target pkg    (unused)        file system    number bytes
  # DISKNODES     target pkg    (unused)        file system    number inodes
  # REQUIRES      required pkg  pkg requires+2  (unused)       0 = installed
  # CONFLICTS     conflict pkg  pkg conflicted+2 (unused)      0 = installed
  # (OBSOLETES)   obsoletes pkg pkg obsoleted+2  (unused)      0 = installed
  # (VERIFY)
  # ========================================================================
  #
  # OBSOLETES is not defined in RPM 4.8, but applies same translation to
  # REQUIRES or CONFLICTS.
  #
  # No translation applies for VERIFY.
  #
  class Problem
    @need_gc : Bool = true
    property ptr : LibRPM::Problem

    def finalize
      if @need_gc
        @ptr = LibRPM.rpmProblemFree(@ptr)
      end
    end

    def initialize(@ptr, *, @need_gc = false)
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

    def dup
      nptr = LibRPM.rpmProblemLink(@ptr)
      raise Exception.new("Cannot duplicate RPM problem") if nptr.null?
      Problem.new(nptr, need_gc: true)
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
      return "#<RPM::Problem (null problem)>" if @ptr.null?
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

  class ProblemSetIterator
    include Iterator(Problem)

    @pset : ProblemSet
    @iter : LibRPM::ProblemSetIterator

    def initialize(@pset, @iter)
    end

    def next
      if LibRPM.rpmpsNextIterator(@iter) < 0
        stop
      else
        Problem.new(LibRPM.rpmpsGetProblem(@iter))
      end
    end

    def finalize
      @iter = LibRPM.rpmpsFreeIterator(@iter)
    end
  end

  # Set of Problems
  class ProblemSet
    include Iterable(Problem)

    property ptr : LibRPM::ProblemSet

    def initialize(@ptr)
    end

    def initialize(ts : Transaction)
      ptr = LibRPM.rpmtsProblems(ts.ptr)
      initialize(ptr)
    end

    def each
      iter = LibRPM.rpmpsInitIterator(self.ptr)
      ProblemSetIterator.new(self, iter)
    end

    def each(&block)
      self.each.each { |x| yield x }
    end

    def finalize
      unless @ptr.null?
        @ptr = LibRPM.rpmpsFree(@ptr)
      end
    end
  end
end
