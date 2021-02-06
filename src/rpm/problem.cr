module RPM
  class ProblemSet
  end

  # Stores Problem.
  class Problem
    @need_gc : Bool = true
    @ptr : LibRPM::Problem

    def finalize
      if @need_gc
        @ptr = LibRPM.rpmProblemFree(@ptr)
      end
    end

    # :nodoc:
    def initialize(@ptr, *, @need_gc = false)
    end

    # Replace `nil` with `Pointer.null`.
    private def self.nil_ptr(cls : T.class, obj) : T forall T
      if obj.nil?
        T.null
      elsif obj.is_a?(T)
        obj
      else
        obj.to_unsafe
      end
    end

    {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
      # Create a problem with calling convention of `rpmProblemCreate`
      # in RPM 4.9 or later.
      def self.create(type, pkg_nevr, key, alt_nevr, str, number)
        case type
        when ProblemType::REQUIRES, ProblemType::CONFLICT, ProblemType::OBSOLETES
          pkg_nevr, str, alt_nevr = alt_nevr, pkg_nevr, "  " + str.not_nil!
          number = (number == 0) ? 1 : 0
        else
          # NOP
        end
        pkg_nevr = nil_ptr(Pointer(UInt8), pkg_nevr)
        alt_nevr = nil_ptr(Pointer(UInt8), alt_nevr)
        str = nil_ptr(Pointer(UInt8), str)
        ptr = LibRPM.rpmProblemCreate(type, pkg_nevr, key, nil, str, alt_nevr, number)
        raise Exception.new("Cannot create RPM problem") if ptr.null?
        self.for(ptr, need_gc: true)
      end

      # Create a problem with calling convention of `rpmProblemCreate`
      # in RPM 4.8.x.
      #
      # The function arguments requires dirname and filename separately,
      # but the upstream implementation simply joins them, so set
      # dirname to `nil` is suffice.
      @[Deprecated("Use `.create` with RPM 4.9 convention")]
      def self.create(type, pkg_nevr, key, dir, file, alt_nevr, number)
        pkg_nevr = nil_ptr(Pointer(UInt8), pkg_nevr)
        alt_nevr = nil_ptr(Pointer(UInt8), alt_nevr)
        dir = nil_ptr(Pointer(UInt8), dir)
        file = nil_ptr(Pointer(UInt8), file)
        ptr = LibRPM.rpmProblemCreate(type, pkg_nevr, key, dir, file, alt_nevr, number)
        raise AllocationError.new("Cannot create RPM problem") if ptr.null?
        self.for(ptr, need_gc: true)
      end
    {% else %}
      # Create a problem with calling convention of `rpmProblemCreate`
      # in RPM 4.9 or later.
      def self.create(type, pkg_nevr, key, alt_nevr, str, number)
        pkg_nevr = nil_ptr(Pointer(UInt8), pkg_nevr)
        alt_nevr = nil_ptr(Pointer(UInt8), alt_nevr)
        str = nil_ptr(Pointer(UInt8), str)
        ptr = LibRPM.rpmProblemCreate(type, pkg_nevr, key, alt_nevr, str, number)
        raise Exception.new("Cannot create RPM problem") if ptr.null?
        self.for(ptr, need_gc: true)
      end

      # Create a problem with calling convention of `rpmProblemCreate`
      # in RPM 4.8.x.
      #
      # `dir` and `file` are simply concatenated (if both of them are
      # not `nil`).
      @[Deprecated("Use `.create` with RPM 4.9 convention")]
      def self.create(type, pkg_nevr, key, dir, file, alt_nevr, number)
        if dir && file
          str = dir + file
        elsif file
          str = file
        else
          str = dir
        end
        case type
        when ProblemType::REQUIRES, ProblemType::CONFLICT, ProblemType::OBSOLETES
          str, alt_nevr, pkg_nevr = alt_nevr.not_nil![2..-1], pkg_nevr, str
          number = (number != 0) ? 0 : 1
        else
          # NOP
        end
        pkg_nevr = nil_ptr(Pointer(UInt8), pkg_nevr)
        alt_nevr = nil_ptr(Pointer(UInt8), alt_nevr)
        str = nil_ptr(Pointer(UInt8), str)
        ptr = LibRPM.rpmProblemCreate(type, pkg_nevr, key, alt_nevr, str, number)
        raise AllocationError.new("Cannot create RPM problem") if ptr.null?
        self.for(ptr, need_gc: true)
      end
    {% end %}

    # Problem indicates a package is for a different architecture.
    class BadArch < Problem
      # Create BADARCH problem with given package.
      def self.for(pkg : Package, arch : String? = nil, key : String? = nil) : BadArch
        key ||= pkg[RPM::Tag::NEVRA].as(String)
        nevr = pkg[RPM::Tag::NEVR].as(String)
        arch ||= pkg[RPM::Tag::Arch].as(String)
        Problem.create(ProblemType::BADARCH, nevr, key, nil, arch, 0).as(BadArch)
      end

      # Create BADARCH problem with given package string and arch name.
      def self.for(pkg : String, arch : String, key : String? = nil) : BadArch
        key ||= pkg
        Problem.create(ProblemType::BADARCH, pkg, key, nil, arch, 0).as(BadArch)
      end

      # Returns package name
      def package
        pkg_nevr
      end

      # Returns arch name
      def arch
        str
      end
    end

    # Problem indicates a package is for a different operating system.
    class BadOS < Problem
      # Create BADOS problem with given package.
      def self.for(pkg : Package, os : String? = nil, key : String? = nil) : BadOS
        key ||= pkg[RPM::Tag::NEVRA].as(String)
        nevr = pkg[RPM::Tag::NEVR].as(String)
        os ||= pkg[RPM::Tag::OS].as(String)
        Problem.create(ProblemType::BADOS, nevr, key, nil, os, 0).as(BadOS)
      end

      # Create BADOS problem with given package string and os name.
      def self.for(pkg : String, os : String, key : String? = nil) : BadOS
        key ||= pkg
        Problem.create(ProblemType::BADOS, pkg, key, nil, os, 0).as(BadOS)
      end

      # Returns package name
      def package
        pkg_nevr
      end

      # Returns os name
      def os
        str
      end
    end

    # Problem indicates a package is already installed.
    class PackageInstalled < Problem
      # Create PKG_INSTALLED problem with given package.
      def self.for(pkg : Package, key : String? = nil) : PackageInstalled
        key ||= pkg[RPM::Tag::NEVRA].as(String)
        nevr = pkg[RPM::Tag::NEVR].as(String)
        Problem.create(ProblemType::PKG_INSTALLED, nevr, key, nil, nil, pkg.instance).as(PackageInstalled)
      end

      # Create PKG_INSTALLED problem with given package string.
      def self.for(pkg : String, key : String? = nil) : PackageInstalled
        key ||= pkg
        Problem.create(ProblemType::PKG_INSTALLED, pkg, key, nil, nil, 0).as(PackageInstalled)
      end

      # Returns package name
      def package
        pkg_nevr
      end
    end

    # Problem indicates a package is going to be badly relocated.
    class BadRelocate < Problem
      # Create BADRELOCATE problem with given package
      def self.for(pkg : Package, reloc : String, key : String? = nil) : BadRelocate
        key ||= pkg[RPM::Tag::NEVRA].as(String)
        nevr = pkg[RPM::Tag::NEVR].as(String)
        Problem.create(ProblemType::BADRELOCATE, nevr, key, nil, reloc, 0).as(BadRelocate)
      end

      # Create BADRELOCATE problem with given package string
      def self.for(pkg : String, reloc : String, key : String? = nil) : BadRelocate
        key ||= pkg
        Problem.create(ProblemType::BADRELOCATE, pkg, key, nil, reloc, 0).as(BadRelocate)
      end

      # Returns package name
      def package
        pkg_nevr
      end

      # Returns path to be relocated
      def path
        str
      end
    end

    # Problem indicates there is a file conflict between packages
    # going to be installed.
    class NewFileConflict < Problem
      # Create NEW_FILE_CONFLICT problem with given packages
      def self.for(pkg1 : Package | String, pkg2 : Package | String,
                   path : String, key : String? = nil) : NewFileConflict
        if key.nil?
          if pkg1.is_a?(Package)
            key = pkg1[RPM::Tag::NEVRA].as(String)
          else
            key = pkg1
          end
        end
        if pkg1.is_a?(Package)
          nevr1 = pkg1[RPM::Tag::NEVR].as(String)
        else
          nevr1 = pkg1
        end
        if pkg2.is_a?(Package)
          nevr2 = pkg2[RPM::Tag::NEVR].as(String)
        else
          nevr2 = pkg2
        end
        Problem.create(ProblemType::NEW_FILE_CONFLICT, nevr1, key, nevr2, path, 0).as(NewFileConflict)
      end

      # Returns a package which has conflict
      def left_package
        pkg_nevr
      end

      # Returns another package which has conflict
      def right_package
        alt_nevr
      end

      # Returns the file path which is conflicting.
      def path
        str
      end
    end

    # Problem indicates there is a file conflict between installed
    # package and installing package.
    class FileConflict < Problem
      # Create FILE_CONFLICT problem with given packages
      def self.for(installing : Package | String, installed : Package | String,
                   path : String, key : String? = nil) : FileConflict
        if key.nil?
          if installing.is_a?(Package)
            key = installing[RPM::Tag::NEVRA].as(String)
          else
            key = installing
          end
        end
        if installing.is_a?(Package)
          nevr1 = installing[RPM::Tag::NEVR].as(String)
        else
          nevr1 = installing
        end
        if installed.is_a?(Package)
          nevr2 = installed[RPM::Tag::NEVR].as(String)
        else
          nevr2 = installed
        end
        Problem.create(ProblemType::FILE_CONFLICT, nevr1, key, nevr2, path, 0).as(FileConflict)
      end

      # Returns the installing package which has conflict
      def installing_package
        pkg_nevr
      end

      # Returns the installed package which has conflict
      def installed_package
        alt_nevr
      end

      # Returns the file path which is conflicting.
      def path
        str
      end
    end

    # Problem indicates that newer or same package is already
    # installed.
    class OldPackage < Problem
      # Create OLD_PACKAGE problem with given packages
      def self.for(installing : Package | String, installed : Package | String,
                   key : String? = nil) : OldPackage
        if key.nil?
          if installing.is_a?(Package)
            key = installing[RPM::Tag::NEVRA].as(String)
          else
            key = installing
          end
        end
        if installing.is_a?(Package)
          nevr1 = installing[RPM::Tag::NEVR].as(String)
        else
          nevr1 = installing
        end
        if installed.is_a?(Package)
          nevr2 = installed[RPM::Tag::NEVR].as(String)
        else
          nevr2 = installed
        end
        Problem.create(ProblemType::OLDPACKAGE, nevr1, key, nevr2, nil, 0).as(OldPackage)
      end

      # Returns the installed package which is newer than the
      # installing one.
      def installed_package
        pkg_nevr
      end

      # Returns the installing package which is older than the
      # installed one.
      def installing_package
        alt_nevr
      end
    end

    # Problem indicates that an installing package needs more disk
    # space than currently available.
    class DiskSpace < Problem
      # Create DISKSPACE problem with given packages
      def self.for(package : Package, filesystem : String,
                   space_required : UInt64, key : String? = nil) : DiskSpace
        key ||= package.to_nevra
        nevr = package.to_nevr
        Problem.create(ProblemType::DISKSPACE, nevr, key, nil, filesystem, space_required)
      end

      # Returns package to be installed
      def package
        pkg_nevr
      end

      # Returns the filesystem which is needed more space
      def filesystem
        str
      end

      # Returns the number of bytes needed to install the package.
      def bytes
        number
      end
    end

    # Problem indicates that an installing package needs more disk
    # i-nodes than currently available.
    class DiskNodes < Problem
      # Create DISKNODES problem with given packages
      def self.for(package : Package, filesystem : String,
                   space_required : UInt64, key : String? = nil) : DiskSpace
        key ||= package.to_nevra
        nevr = package.to_nevr
        Problem.create(ProblemType::DISKNODES, nevr, key, nil, filesystem, space_required)
      end

      # Create DISKNODES problem with given package string.
      def self.for(package : String, filesystem : String,
                   space_required : UInt64, key : String? = nil) : DiskSpace
        key ||= package
        Problem.create(ProblemType::DISKNODES, package, key, nil, filesystem, space_required)
      end

      # Returns package to be installed
      def package
        pkg_nevr
      end

      # Returns the filesystem which is needed more space
      def filesystem
        str
      end

      # Returns the number of i-nodes needed to install the package.
      def inodes
        number
      end
    end

    # Problem indicates that a Require dependency of a package is missing.
    class Requires < Problem
      # Create REQUIRES problem with given packages
      def self.for(package : Package, requires : String,
                   installed : Bool, key : String? = nil) : Requires
        key ||= package[RPM::Tag::NEVRA].as(String)
        nevr = package[RPM::Tag::NEVR].as(String)
        Problem.create(ProblemType::REQUIRES, nil, key, nevr, requires, installed ? 1 : 0).as(Requires)
      end

      # Create REQUIRES problem with given packages
      def self.for(package : String, requires : String,
                   installed : Bool, key : String? = nil) : Requires
        key ||= package
        Problem.create(ProblemType::REQUIRES, nil, key, package, requires, installed ? 1 : 0).as(Requires)
      end

      # Returns a pacakge which has missing Requires dependency
      def package
        {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
          pkg_nevr
        {% else %}
          alt_nevr
        {% end %}
      end

      # Returns a name which is required
      def what_required
        {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
          # The 1st and 2nd characters will not affect to the message
          # generated by the upstream API. So we are cutting them off.
          alt_nevr[2..-1]
        {% else %}
          str
        {% end %}
      end

      # Returns whether the problem package is installed or installing
      def installed?
        {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
          number == 0
        {% else %}
          number == 1
        {% end %}
      end
    end

    # Problem indicates that a Conflicts dependency of a package is missing.
    class Conflicts < Problem
      # Create CONFLICT problem with given packages
      def self.for(package : Package, requires : String,
                   installed : Bool, key : String? = nil) : Conflicts
        key ||= package[RPM::Tag::NEVRA].as(String)
        nevr = package[RPM::Tag::NEVR].as(String)
        Problem.create(ProblemType::CONFLICT, nil, key, nevr, requires, installed ? 1 : 0).as(Conflicts)
      end

      # Create CONFLICT problem with given packages
      def self.for(package : String, requires : String,
                   installed : Bool, key : String? = nil) : Conflicts
        key ||= package
        Problem.create(ProblemType::CONFLICT, nil, key, package, requires, installed ? 1 : 0).as(Conflicts)
      end

      # Returns a pacakge which has missing Conflict dependency
      def package
        {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
          pkg_nevr
        {% else %}
          alt_nevr
        {% end %}
      end

      # Returns a name which conflicts
      def what_conflicts
        {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
          # The 1st and 2nd characters will not affect to the message
          # generated by the upstream API. So we are cutting them off.
          alt_nevr[2..-1]
        {% else %}
          str
        {% end %}
      end

      # Returns whether the problem package is installed or installing
      def installed?
        {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
          number == 0
        {% else %}
          number == 1
        {% end %}
      end
    end

    # Problem indicates that a package is obsoleted by another package.
    #
    # NOTE: Obsoletes problems are introduced at RPM 4.9.0. You can
    # create the instance of `Obsoletes`, but some functions may
    # return unexpected result.
    class Obsoletes < Problem
      # Create OBSOLETES problem with given packages
      def self.for(package : Package, requires : String,
                   installed : Bool, key : String? = nil) : Obsoletes
        key ||= package[RPM::Tag::NEVRA].as(String)
        nevr = package[RPM::Tag::NEVR].as(String)
        Problem.create(ProblemType::OBSOLETES, nil, key, nevr, requires, installed ? 1 : 0).as(Obsoletes)
      end

      # Create OBSOLETES problem with given packages
      def self.for(package : String, requires : String,
                   installed : Bool, key : String? = nil) : Obsoletes
        key ||= package
        Problem.create(ProblemType::OBSOLETES, nil, key, package, requires, installed ? 1 : 0).as(Obsoletes)
      end

      # Returns a pacakge which has been obsoleted
      def package
        {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
          pkg_nevr
        {% else %}
          alt_nevr
        {% end %}
      end

      # Returns a name which obsoletes
      def what_obsoletes
        {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
          # The 1st and 2nd characters will not affect to the message
          # generated by the upstream API. So we are cutting them off.
          alt_nevr[2..-1]
        {% else %}
          str
        {% end %}
      end

      # Returns whether the problem package is installed or installing
      def installed?
        {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
          number == 0
        {% else %}
          number == 1
        {% end %}
      end
    end

    # Problem indicates that a package did not pass verification
    #
    # NOTE: Verify problems are introduced at RPM 4.14.2. You can
    # create the instance of `Verify`, but some functions may return
    # unexpected result.
    class Verify < Problem
      # Create VERIFY problem with given packages
      def self.for(package : Package, content : String, key : String? = nil) : Verify
        key ||= package[RPM::Tag::NEVRA].as(String)
        nevr = package[RPM::Tag::NEVR].as(String)
        Problem.create(ProblemType::VERIFY, nevr, key, nil, content, 0).as(Verify)
      end

      # Create VERIFY problem with given packages
      def self.for(package : String, content : String, key : String? = nil) : Verify
        key ||= package
        Problem.create(ProblemType::VERIFY, package, key, nil, content, 0).as(Verify)
      end

      # Returns the package which has a verification problem
      def package
        pkg_nevr
      end

      # Returns the verification message
      def content
        str
      end
    end

    # Create a Problem instance with type indicated by given problem's
    # type.
    #
    # If given `ptr` is NULL, or, unsupported type, this method
    # returns an instance of `RPM::Problem`.
    def self.for(ptr : LibRPM::Problem, **opts)
      if ptr.null?
        self.new(ptr, **opts)
      else
        {% begin %}
          case LibRPM.rpmProblemGetType(ptr)
            {% for m in [["BADARCH", "BadArch"], ["BADOS", "BadOS"],
                         ["PKG_INSTALLED", "PackageInstalled"],
                         ["BADRELOCATE", "BadRelocate"],
                         ["NEW_FILE_CONFLICT", "NewFileConflict"],
                         ["FILE_CONFLICT", "FileConflict"],
                         ["OLDPACKAGE", "OldPackage"],
                         ["DISKSPACE", "DiskSpace"],
                         ["DISKNODES", "DiskNodes"], ["REQUIRES", "Requires"],
                         ["CONFLICT", "Conflicts"], ["OBSOLETES", "Obsoletes"],
                         ["VERIFY", "Verify"]] %}
              {% tagname = m[0].id %}
              {% clsname = m[1].id %}
            when ProblemType::{{tagname}}
              RPM::Problem::{{clsname}}.new(ptr, **opts)
            {% end %}
          else
            self.new(ptr, **opts)
          end
        {% end %}
      end
    end

    def dup
      nptr = LibRPM.rpmProblemLink(@ptr)
      raise Exception.new("Cannot duplicate RPM problem") if nptr.null?
      self.class.new(nptr, need_gc: true)
    end

    def pkg_nevr?
      ptr = LibRPM.rpmProblemGetPkgNEVR(@ptr)
      if ptr.null?
        nil
      else
        String.new(ptr)
      end
    end

    def pkg_nevr
      pkg_nevr?.not_nil!
    end

    def alt_nevr?
      ptr = LibRPM.rpmProblemGetAltNEVR(@ptr)
      if ptr.null?
        nil
      else
        String.new(ptr)
      end
    end

    def alt_nevr
      alt_nevr?.not_nil!
    end

    def type
      LibRPM.rpmProblemGetType(@ptr)
    end

    def key
      LibRPM.rpmProblemGetKey(@ptr)
    end

    def str?
      m = LibRPM.rpmProblemGetStr(@ptr)
      if m.null?
        nil
      else
        String.new(m)
      end
    end

    def str
      str?.not_nil!
    end

    def number
      LibRPM.rpmProblemGetDiskNeed(@ptr).to_u64
    end

    def to_s(io)
      if @ptr.null?
        io << "#<" << self.class.name << " (null problem)>"
        return
      end
      ptr = LibRPM.rpmProblemString(@ptr)
      if ptr.null?
        io << "#<" << self.class.name << " (empty problem)>"
        return
      end
      begin
        io << String.new(ptr)
      ensure
        LibC.free(ptr)
      end
    end

    # Compares two problems
    #
    # NOTE: RPM 4.8 does not support this method.
    def ==(other)
      LibRPM.rpmProblemCompare(@ptr, other) == 0
    end

    # Returns pointer to `rpmProblem` to deal with librpm C API directly
    def to_unsafe
      @ptr
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
        Problem.for(LibRPM.rpmpsGetProblem(@iter), need_gc: false)
      end
    end

    def finalize
      @iter = LibRPM.rpmpsFreeIterator(@iter)
    end

    # Returns pointer to `rpmpsi` to deal with librpm C API directly
    def to_unsafe
      @iter
    end
  end

  # Set of Problems
  class ProblemSet
    include Iterable(Problem)

    @ptr : LibRPM::ProblemSet

    def initialize(@ptr)
    end

    def each
      iter = LibRPM.rpmpsInitIterator(@ptr)
      ProblemSetIterator.new(self, iter)
    end

    def each(&block)
      iter = LibRPM.rpmpsInitIterator(@ptr)
      begin
        while LibRPM.rpmpsNextIterator(iter) >= 0
          yield Problem.for(LibRPM.rpmpsGetProblem(iter), need_gc: false)
        end
      ensure
        LibRPM.rpmpsFreeIterator(iter)
      end
    end

    def finalize
      unless @ptr.null?
        @ptr = LibRPM.rpmpsFree(@ptr)
      end
    end

    # Returns pointer to `rpmps` to deal with librpm C API directly
    def to_unsafe
      @ptr
    end
  end
end
