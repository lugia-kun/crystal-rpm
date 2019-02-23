module RPM
  abstract class SpecCommonBase
    abstract def initialize(specfile : String, flags : LibRPM::SpecFlags, buildroot : String?)
    abstract def buildroot : String
    abstract def packages : Array(RPM::Package)
  end

  class Spec48 < SpecCommonBase
    getter ptr : LibRPM::Spec
    getter ts : LibRPM::Transaction
    @pkgs : Array(RPM::Package)? = nil

    def initialize(specfile : String, flags : LibRPM::SpecFlags, buildroot : String?)
      ts = LibRPM.rpmtsCreate
      ret = LibRPM.parseSpec(ts, specfile, "/", buildroot, 0, "", nil,
                             flags.anyarch?, flags.force?)
      if ret != 0 || ts.null?
        raise Exception.new("specfile \"#{specfile}\" parsing failed")
      end
      initialize(ts)
    end

    def initialize(@ts)
      @ptr = LibRPM.rpmtsSpec(@ts)
    end

    def buildroot
      String.new(@ptr.value.buildroot)
    end

    def packages
      if @pkgs.nil?
        arr = Array(RPM::Package).new
        pkgs = @ptr.value.packages
        while !pkgs.null?
          arr << RPM::Package.new(pkgs.value.header)
          pkgs = pkgs.value.next
        end
        @pkgs = arr
      else
        @pkgs.as(Array(RPM::Package))
      end
    end

    def finalize
      LibRPM.rpmtsFree(@ts)
    end
  end

  class Spec49 < SpecCommonBase
    getter ptr : LibRPM::Spec
    @hdr : Package? = nil
    @pkgs : Array(RPM::Package)? = nil

    class PackageIterator
      @iter : LibRPM::SpecPkgIter
      @spec : Spec49

      include Iterator(RPM::Package)

      def initialize(@spec)
        iter = LibRPM.rpmSpecPkgIterInit(@spec.ptr)
        raise Exception.new("SpecPkgIter initialization failed") if iter.null?
        @iter = iter
      end

      def finalize
        @iter = LibRPM.rpmSpecPkgIterFree(@iter)
      end

      def next
        pkg = LibRPM.rpmSpecPkgIterNext(@iter)
        if pkg.null?
          stop
        else
          RPM::Package.new(LibRPM.rpmSpecPkgHeader(pkg))
        end
      end

      def rewind
        finalize
        initialize(@spec)
      end
    end

    def initialize(specfile : String, flags : LibRPM::SpecFlags, buildroot : String?)
      spec = LibRPM.rpmSpecParse(specfile, flags, buildroot)
      if spec.null?
        raise Exception.new("specfile \"#{specfile}\" parsing failed")
      end
      initialize(spec)
    end

    def initialize(@ptr)
    end

    def header : RPM::Package
      @hdr ||= Package.new(LibRPM.rpmSpecSourceHeader(@ptr))
      @hdr.as(RPM::Package)
    end

    def buildroot
      root = header[Tag::BuildRoot]
      if root
        root.as(String)
      else
        RPM["buildroot"]
      end
    end

    def packages
      if @pkgs.nil?
        iter = PackageIterator.new(self)
        @pkgs = iter.map { |x| x }
      else
        @pkgs.as(Array(RPM::Package))
      end
    end

    def finalize
      LibRPM.rpmSpecFree(@ptr)
    end
  end

  {% if compare_versions(PKGVERSION_COMP, "4.9.0") < 0 %}
    alias SpecVersionDeps = Spec48
  {% else %}
    alias SpecVersionDeps = Spec49
  {% end %}

  class Spec < SpecVersionDeps
    {% unless Spec.ancestors.find { |x| x == SpecCommonBase } %}
      {% raise "RPM::Spec must be subclass of RPM::SpecCommonBase" %}
    {% end %}

    def self.open(specfile : String, flags : LibRPM::SpecFlags = LibRPM::SpecFlags::FORCE | LibRPM::SpecFlags::ANYARCH, buildroot : String? = nil)
      new(specfile, flags, buildroot)
    end
  end
end
