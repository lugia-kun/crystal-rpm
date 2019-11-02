module RPM
  # Represents information of a file or a directory stored in RPM db
  # or RPM package
  struct File
    # Fullpath to the file or the directory
    property path : String

    # (Cryptographic) Digest of the file
    #
    # For directory, digest will be filled with `0`.
    property digest : String

    # Link destination of the symbolic link
    #
    # If the file is not a symbolic link, `#link_to` will be an empty string.
    property link_to : String

    # Bytesize of a file
    property size : UInt32

    # Modification time of a file
    property mtime : Time

    # Owner's name
    property owner : String

    # Group's name
    property group : String

    # UNIX mode value
    property mode : UInt16

    # RPM-specific File attributes
    property attr : FileAttrs

    # Current state of the file (missing, replaced, ...)
    property state : FileState

    # Device ID for special files
    #
    # If the file is not a special file, `#rdev` will be 0.
    property rdev : UInt16

    def initialize(@path, @digest, @link_to, @size, @mtime, @owner,
                   @group, @rdev, @mode, @attr, @state)
    end

    # Returns modification time.
    #
    # Provided for interoperability with Crystal's `File::Info`,
    # this method just return `mtime`.
    def modification_time : Time
      mtime
    end

    # Returns extra mode bit flags which is set for the path
    def flags : ::File::Flags
      flags = ::File::Flags::None
      flags |= ::File::Flags::SetUser if @mode.bits_set? LibC::S_ISUID
      flags |= ::File::Flags::SetGroup if @mode.bits_set? LibC::S_ISGID
      flags |= ::File::Flags::Sticky if @mode.bits_set? LibC::S_ISVTX
      flags
    end

    # Returns permissions of the path
    def permissions : ::File::Permissions
      ::File::Permissions.new(@mode & 0o777)
    end

    # Returns type of the path
    def type : ::File::Type
      case @mode & LibC::S_IFMT
      when LibC::S_IFBLK
        ::File::Type::BlockDevice
      when LibC::S_IFCHR
        ::File::Type::CharacterDevice
      when LibC::S_IFDIR
        ::File::Type::Directory
      when LibC::S_IFIFO
        ::File::Type::Pipe
      when LibC::S_IFLNK
        ::File::Type::Symlink
      when LibC::S_IFREG
        ::File::Type::File
      when LibC::S_IFSOCK
        ::File::Type::Socket
      else
        ::File::Type::Unknown
      end
    end
  end
end
