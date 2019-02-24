module RPM
  {% begin %}
  class Spec
    getter ptr : LibRPM::Spec
    @hdr : RPM::Package? = nil
    @pkgs : Array(RPM::Package)? = nil
    @buildreqs : Array(RPM::Require)? = nil

    {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
      @ts : LibRPM::Transaction
    {% end %}

    class PackageIterator
      @spec : Spec
      {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
        @iter : Pointer(LibRPM::Package_s)
      {% else %}
        @iter : LibRPM::SpecPkgIter
      {% end %}

      include Iterator(RPM::Package)

      def initialize(@spec)
        {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
          iter = @spec.ptr.value.packages
        {% else %}
          iter = LibRPM.rpmSpecPkgIterInit(@spec.ptr)
        {% end %}
        @iter = iter
      end

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

    def initialize(specfile : String, flags : LibRPM::SpecFlags, buildroot : String?)
      {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
        ts = LibRPM.rpmtsCreate
        ret = LibRPM.parseSpec(ts, specfile, "/", buildroot, 0, "", nil,
                               flags.anyarch? ? 1 : 0,
                               flags.force? ? 1 : 0)
        if ret != 0 || ts.null?
          raise Exception.new("specfile \"#{specfile}\" parsing failed")
        end
        @ts = ts
        spec = LibRPM.rpmtsSpec(ts)
      {% else %}
        spec = LibRPM.rpmSpecParse(specfile, flags, buildroot)
        if spec.null?
          raise Exception.new("specfile \"#{specfile}\" parsing failed")
        end
      {% end %}
      @ptr = spec
    end

    def buildroot
      {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
        String.new(@ptr.value.buildroot)
      {% else %}
        # XXX: This means the value of buildroot is stored globally.
        RPM["buildroot"]
      {% end %}
    end

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

    def packages
      if @pkgs.nil?
        iter = PackageIterator.new(self)
        @pkgs = iter.to_a
      end
      @pkgs.as(Array(RPM::Package))
    end

    def buildrequires
      if @buildreqs.nil?
        hdr = header
        @buildreqs = hdr.requires
      end
      @buildreqs.as(Array(RPM::Require))
    end

    def finalize
      {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
        LibRPM.rpmtsFree(@ts)
      {% else %}
        LibRPM.rpmSpecFree(@ptr)
      {% end %}
    end

    def self.open(specfile : String, flags : LibRPM::SpecFlags = LibRPM::SpecFlags::FORCE | LibRPM::SpecFlags::ANYARCH, buildroot : String? = nil)
      new(specfile, flags, buildroot)
    end
  end
  {% end %}
end
