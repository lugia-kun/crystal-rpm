module RPM
  class Spec
    getter ptr : LibRPM::Spec
    @hdr : RPM::Package? = nil
    @pkgs : Array(RPM::Package)? = nil
    @srcs : Array(RPM::SourceBase)? = nil
    @filename : String

    {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
      @ts : LibRPM::Transaction
    {% else %}
      @rootdir : String?
      @buildroot : String?
    {% end %}

    class PackageIterator
      @spec : Spec
      {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
        @iter : Pointer(LibRPM::Package_s)
      {% else %}
        @iter : LibRPM::SpecPkgIter
      {% end %}

      include Iterator(RPM::Package)

      {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
        def initialize(@spec)
          @iter = @spec.ptr.value.packages
        end
      {% else %}
        def initialize(@spec)
          @iter = LibRPM.rpmSpecPkgIterInit(@spec.ptr)
        end
      {% end %}

      def finalize
        {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
          # NOP.
        {% else %}
          @iter = LibRPM.rpmSpecPkgIterFree(@iter)
        {% end %}
      end

      def next
        {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
          if @iter.null?
            stop
          else
            pkg = RPM::Package.new(@iter.value.header)
            @iter = @iter.value.next
            pkg
          end
        {% else %}
          pkg = LibRPM.rpmSpecPkgIterNext(@iter)
          if pkg.null?
            stop
          else
            RPM::Package.new(LibRPM.rpmSpecPkgHeader(pkg))
          end
        {% end %}
      end

      def rewind
        finalize
        initialize(@spec)
      end
    end

    class SourceIterator
      @spec : Spec
      {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
        @iter : Pointer(LibRPM::Source_s)
      {% else %}
        @iter : LibRPM::SpecSrcIter
      {% end %}

      include Iterator(RPM::SourceBase)

      {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
        def initialize(@spec)
          @iter = @spec.ptr.value.sources
        end
      {% else %}
        def initialize(@spec)
          @iter = LibRPM.rpmSpecSrcIterInit(@spec.ptr)
        end
      {% end %}

      def finalize
        {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
          # NOP.
        {% else %}
          @iter = LibRPM.rpmSpecSrcIterFree(@iter)
        {% end %}
      end

      private def make_source_instance(flag, fullname, number)
        sflag = LibRPM::SourceFlags.new(flag.to_u32)
        no = sflag.isno?
        if sflag.issource?
          Source.new(fullname, number.to_i32, no)
        elsif sflag.ispatch?
          Patch.new(fullname, number.to_i32, no)
        elsif sflag.isicon?
          Icon.new(fullname, number.to_i32, no)
        else
          raise Exception.new("Invalid source flags")
        end
      end

      def next
        {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
          if @iter.null?
            stop
          else
            src = make_source_instance(@iter.value.flags,
              String.new(@iter.value.full_source),
              @iter.value.num)
            @iter = @iter.value.next
            src
          end
        {% else %}
          src = LibRPM.rpmSpecSrcIterNext(@iter)
          if src.null?
            stop
          else
            make_source_instance(LibRPM.rpmSpecSrcFlags(src),
              String.new(LibRPM.rpmSpecSrcFilename(src)),
              LibRPM.rpmSpecSrcNum(src))
          end
        {% end %}
      end

      def rewind
        finalize
        initialize(@spec)
      end
    end

    # Open a specfile and parse it.
    #
    # Recommend to use `RPM::Spec.open`.
    {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
      def initialize(specfile : String, flags : LibRPM::SpecFlags, buildroot : String?, rootdir : String? = "/")
        @filename = specfile
        ts = LibRPM.rpmtsCreate
        ret = LibRPM.parseSpec(ts, specfile, rootdir, buildroot, 0, "", nil,
          flags.anyarch? ? 1 : 0,
          flags.force? ? 1 : 0)
        if ret != 0 || ts.null?
          raise Exception.new("specfile \"#{specfile}\" parsing failed")
        end
        spec = LibRPM.rpmtsSpec(ts)
        @ts = ts
        @ptr = spec
      end
    {% else %}
      def initialize(specfile : String, flags : LibRPM::SpecFlags, buildroot : String?, rootdir : String? = "/")
        @filename = specfile
        spec = LibRPM.rpmSpecParse(specfile, flags, buildroot)
        if spec.null?
          raise Exception.new("specfile \"#{specfile}\" parsing failed")
        end
        @rootdir = rootdir
        @buildroot = buildroot
        @ptr = spec
      end
    {% end %}

    # Returns buildroot associated with the specfile.
    #
    # Warning: In rpm 4.9 or later, this is the result of expanding
    # `%{buildroot}`. So, if you open two or more specfiles
    # simultaneously, you may get incorrect result.
    def buildroot
      {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
        String.new(@ptr.value.buildroot)
      {% else %}
        @buildroot || RPM["buildroot"]
      {% end %}
    end

    # Header data would be stored into SRPM, as a `RPM::Package`.
    #
    # Warning: In rpm 4.8, this method returns the header data from
    # `buildRestrictions`. Some tags may not be set.
    def header : RPM::Package
      if @hdr.nil?
        {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
          @hdr = Package.new(@ptr.value.build_restrictions)
        {% else %}
          @hdr = Package.new(LibRPM.rpmSpecSourceHeader(@ptr))
        {% end %}
      end
      @hdr.as(RPM::Package)
    end

    # Returns array of packages defined in the spec file.
    def packages
      if @pkgs.nil?
        iter = PackageIterator.new(self)
        @pkgs = iter.to_a
      end
      @pkgs.as(Array(RPM::Package))
    end

    # Returns array of sources defined in the spec file.
    def sources
      if @srcs.nil?
        iter = SourceIterator.new(self)
        @srcs = iter.to_a
      end
      @srcs.as(Array(RPM::SourceBase))
    end

    # Returns array of BuildRequires specified in the spec file.
    def buildrequires
      header.requires
    end

    # Returns array of BuildConflicts specified in the spec file.
    def buildconflicts
      header.conflicts
    end

    def build(*, build_amount : BuildFlags, pkg_flags : BuildPkgFlags = BuildPkgFlags::NONE)
      build_amount &= ~BuildFlags::RMSPEC
      if build_amount == BuildFlags::NONE
        raise "No build steps given"
      end
      {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
        rc = LibRPM.buildSpec(@ts, @ptr, build_amount.value,
          build_amount.nobuild? ? 1 : 0)
        if rc == LibRPM::RC::OK
          true
        else
          false
        end
      {% else %}
        buildroot = (@buildroot || RPM["buildroot"]).not_nil!
        rootdir = @rootdir
        null = Pointer(UInt8).null
        xflags = uninitialized LibRPM::BuildArguments_s
        xflags.pkg_flags = pkg_flags
        xflags.build_amount = build_amount
        xflags.build_root = buildroot.to_unsafe
        xflags.rootdir = rootdir ? rootdir.to_unsafe : null
        xflags.cookie = null
        pflags = pointerof(xflags).as(LibRPM::BuildArguments)
        rc = LibRPM.rpmSpecBuild(@ptr, pflags)
        if rc == LibRPM::RC::OK
          true
        else
          false
        end
      {% end %}
    end

    # Cleanup
    def finalize
      {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
        LibRPM.rpmtsFree(@ts)
      {% else %}
        LibRPM.rpmSpecFree(@ptr)
      {% end %}
    end

    # Open a specfile
    #
    # This method gives reasonable defaults for each parameters.
    def self.open(specfile : String, flags : LibRPM::SpecFlags = LibRPM::SpecFlags::FORCE | LibRPM::SpecFlags::ANYARCH, buildroot : String? = nil, rootdir : String? = "/")
      new(specfile, flags, buildroot, rootdir)
    end
  end
end
