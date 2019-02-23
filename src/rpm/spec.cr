module RPM
  abstract class SpecCommonBase
    abstract def initialize(specfile : String)
    abstract def buildroot : String
  end

  class Spec48 < SpecCommonBase
    getter ptr : LibRPM::Spec
    getter ts : LibRPM::Transaction

    def initialize(specfile : String)
      ts = LibRPM.rpmtsCreate
      ret = LibRPM.parseSpec(ts, specfile, "/", nil, 0, "", nil, 1, 1)
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

    def initialize(specfile : String)
      spec = LibRPM.rpmSpecParse(specFile, LibRPM::SpecFlags::NONE, nil)
      if spec.null?
        raise Exception.new("specfile \"#{specfile}\" parsing failed")
      end
      initialize(spec)
    end

    def initialize(@ptr)
    end

    def header
      @hdr ||= Package.new(LibRPM.rpmSpecSourceHeader(@ptr))
      @hdr
    end

    def buildroot
      header[Tag::BuildRoot]
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
