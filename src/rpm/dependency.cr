require "rpm/librpm"
require "rpm/version"

module RPM
  class Package
  end

  class Dependency
    property name : String
    property version : Version
    property flags : Sense
    property package : Package

    def initialize(@name, @version, @flags, @package)
    end

    def nametag : Tag | Nil
      nil
    end

    def versiontag : Tag | Nil
      nil
    end

    def flagstag : Tag | Nil
      nil
    end

    macro define_dependency_class(name)
      class {{name}} < Dependency
        def initislize(**args)
          super(**args)
        end

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
