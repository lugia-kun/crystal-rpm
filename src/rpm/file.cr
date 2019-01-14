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
                   @group, @mode, @attr, @state, @rdev)
    end
  end
end
