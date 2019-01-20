module RPM
  class File
    property path : String
    property md5sum : String
    property link_to : String
    property size : UInt32
    property mtime : Time
    property owner : String
    property group : String
    property mode : UInt16
    property attr : FileAttrs
    property state : FileState
    property rdev : UInt16

    def initialize(@path, @md5sum, @link_to, @size, @mtime, @owner,
                   @group, @rdev, @mode, @attr, @state)
    end

    def symlink?
      !@link_to.empty?
    end

    def config?
      @attr.config?
    end

    def doc?
      @attr.doc?
    end

    def is_missingok?
      @attr.missingok?
    end

    def is_noreplace?
      @attr.noreplace?
    end

    def is_specfile?
      @attr.specfile?
    end

    def ghost?
      @attr.ghost?
    end

    def license?
      @attr.license?
    end

    def readme?
      @attr.readme?
    end

    def replaced?
      @state.replaced?
    end

    def notinstalled?
      @state.notinstalled?
    end

    def netshared?
      @state.netshared?
    end

    def missing?
      @state.missing?
    end
  end
end
