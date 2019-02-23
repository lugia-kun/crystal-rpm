module RPM
  abstract class SpecCommonBase
    abstract def initialize(specfile : String)
    abstract def buildroot : String
  end

  class Spec48 < SpecCommonBase
    getter ptr : LibRPM::Spec
    getter ts : LibRPM::Transaction

    def initialize(specfile : String, flags : LibRPM::SpecFlags = LibRPM::SpecFlags::NONE, buildroot : String? = nil)
      ts = LibRPM.rpmtsCreate
      ret = LibRPM.parseSpec(ts, specfile, "/", buildroot, 0, "", nil, 1, 1)
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

    def finalize
      LibRPM.rpmtsFree(@ts)
    end
  end

  class Spec49 < SpecCommonBase
    getter ptr : LibRPM::Spec
    getter hdr : Package? = nil

    # Sets FORCE in default. (RPM 4.8 does not check sources, so for
    # backward compatibility)
    def initialize(specfile : String, flags : LibRPM::SpecFlags = LibRPM::SpecFlags::FORCE, buildroot : String? = nil)
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

    def self.open(specfile : String)
      new(specfile)
    end
  end
end
