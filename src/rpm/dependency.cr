module RPM
  class Package
  end

  class Dependency
    property name : String
    property version : Version
    property flags : Sense
    property owner : Package?

    def initialize(@name, @version, @flags, @owner)
    end

    private def compare(tag, mname, mversion, mflags, oname, oversion, oflags)
      a = nil
      b = nil
      begin
        a = LibRPM.rpmdsSingle(tag, oname, oversion, oflags)
        b = LibRPM.rpmdsSingle(tag, mname, mversion, mflags)
        LibRPM.rpmdsCompare(a, b) != 0
      ensure
        LibRPM.rpmdsFree(a.as(LibRPM::DependencySet)) if a
        LibRPM.rpmdsFree(b.as(LibRPM::DependencySet)) if b
      end
    end

    # Test whether a given package satisfies (or provides) this
    # dependency.
    def satisfies?(pkg : Package)
      pkg.provides.any? do |prov|
        satisfies?(prov)
      end
    end

    # Test whether a given dependency satisfies this dependecy.
    def satisfies?(dep : Dependency)
      compare(Tag::ProvideName,
        dep.name, dep.version.to_vre, dep.flags,
        name, version.to_vre, flags)
    end

    # Test whether a given version satisfies this dependecy.
    def satisfies?(ver : Version)
      vre = ver.to_vre
      if vre.empty?
        sense = Sense::ANY
      else
        sense = Sense::EQUAL
      end
      compare(Tag::ProvideName, name, vre, sense, name, version.to_vre, flags)
    end

    private def for_lib_ptr(&block : LibRPM::DependencySet -> _)
      data = LibRPM.rpmdsSingle(Tag::ProvideName, name, version.to_vre, flags)
      begin
        yield(data)
      ensure
        LibRPM.rpmdsFree(data)
      end
    end

    def to_dnevr
      for_lib_ptr do |data|
        return nil if data.null?
        String.new(LibRPM.rpmdsDNEVR(data))
      end
    end

    # Returns true if '<' or '<=' are used to compare the version
    def lt?
      flags.less?
    end

    # Returns true if '>' or '>=' are used to compare the version
    def gt?
      flags.greater?
    end

    # Returns true if '<=' are used to compare the version
    def le?
      flags.less? && flags.equal?
    end

    # Returns true if '>=' are used to compare the version
    def ge?
      flags.greater? && flags.equal?
    end

    # Returns true if '=', '<=' or '>=' are used to compare the version
    def eq?
      flags.equal?
    end

    # Returns true if this is a pre-requires
    def pre?
      flags.prereq?
    end

    # Name Tag value which is (was) used to obtain this dependency
    #
    # Returns nil if not applicable.
    def nametag : Tag | Nil
      nil
    end

    # Version Tag value which is (was) used to obtain this dependency
    #
    # Returns nil if not applicable.
    def versiontag : Tag | Nil
      nil
    end

    # Flags Tag value which is (was) used to obtain this dependency
    #
    # Returns nil if not applicable.
    def flagstag : Tag | Nil
      nil
    end

    macro define_dependency_class(name)
      class {{name}} < Dependency
        def self.nametag
          Tag::{{name}}Name
        end

        def self.versiontag
          Tag::{{name}}Version
        end

        def self.flagstag
          Tag::{{name}}Flags
        end

        def nametag
          self.class.nametag
        end

        def versiontag
          self.class.versiontag
        end

        def flagstag
          self.class.flagstag
        end
      end
    end
  end

  Dependency.define_dependency_class(Provide)
  Dependency.define_dependency_class(Require)
  Dependency.define_dependency_class(Conflict)
  Dependency.define_dependency_class(Obsolete)
end
