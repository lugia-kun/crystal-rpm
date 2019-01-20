module RPM
  class ChangeLog
    property time : Time
    property name : String
    property text : String

    def initialize(@time, @name, @text)
    end
  end

  class Package
    def self.create(name : String, version : Version)
      hdr = LibRPM.headerNew
      if LibRPM.headerPutString(hdr, Tag::Name, name) != 1
        raise "Can't set package name: #{name}"
      end
      if LibRPM.headerPutString(hdr, Tag::Version, version.v) != 1
        raise "Can't set package version: #{version.v}"
      end
      if version.e
        epoch = UInt32.new(version.e.as(Int32))
        if LibRPM.headerPutUint32(hdr, Tag::Epoch, pointerof(epoch), 1) != 1
          raise "Can't set package epoch: #{version.e}"
        end
      end
      if version.r
        if LibRPM.headerPutString(hdr, Tag::Release, version.r.as(String)) != 1
          raise "Can't set package release: #{version.r}"
        end
      end
      Package.new(hdr)
    end

    def self.open(filename : String)
      Package.new(filename)
    end

    def initialize(hdr : LibRPM::Header)
      if hdr.null?
        @hdr = LibRPM.headerNew
      else
        @hdr = LibRPM.headerLink(hdr)
      end
    end

    def initialize(filename : String)
      @hdr = uninitialized LibRPM::Header
      fd = LibRPM.Fopen(filename, "r")
      raise "#{filename}: #{String.new(LibRPM.Fstrerror(fd))}" if LibRPM.Ferror(fd) != 0
      begin
        RPM.transaction do |ts|
          rc = LibRPM.rpmReadPackageFile(ts.ptr, fd, filename, pointerof(@hdr))
        end
      ensure
        LibRPM.Fclose(fd)
      end
    end

    def finalize
      LibRPM.headerFree(@hdr)
    end

    # def add_dependency(dep : Dependency)
    # end

    def sprintf(fmt)
      error = uninitialized LibRPM::ErrorMsg
      val = LibRPM.headerFormat(@hdr, fmt, pointerof(error))
      raise Exception.new(String.new(error)) if val.null?
      String.new(val)
    end

    def signature
      sprintf("%{sigmd5}")
    end

    def name
      self[Tag::Name].as(String)
    end

    def files
      basenames = self[Tag::BaseNames]
      return [] of RPM::File if basenames.nil?

      basenames = basenames.as(Array(String))
      dirnames = self[Tag::DirNames].as(Array(String))
      diridxs = self[Tag::DirIndexes].as(Array(UInt32))
      statelist = self[Tag::FileStates].as(Array(UInt32) | Nil)
      flaglist = self[Tag::FileFlags].as(Array(UInt32) | Nil)
      sizelist = self[Tag::FileSizes].as(Array(UInt32))
      modelist = self[Tag::FileModes].as(Array(UInt16))
      mtimelist = self[Tag::FileMTimes].as(Array(UInt32))
      rdevlist = self[Tag::FileRDEVs].as(Array(UInt16))
      linklist = self[Tag::FileLinkTos].as(Array(String))
      md5list = self[Tag::FileDigests].as(Array(String))
      ownerlist = self[Tag::FileUserName].as(Array(String))
      grouplist = self[Tag::FileGroupName].as(Array(String))

      basenames.map_with_index do |basename, i|
        state = if statelist.nil?
                  FileState::NORMAL
                else
                  FileState.from_value(statelist.as(Array(UInt32))[i])
                end
        attr = if flaglist.nil?
                 FileAttrs::NONE
               else
                 FileAttrs.from_value(flaglist.as(Array(UInt32))[i])
               end
        RPM::File.new(
          path: ::File.join(dirnames[diridxs[i]], basename),
          md5sum: md5list[i],
          link_to: linklist[i],
          size: sizelist[i],
          mtime: Time.unix(mtimelist[i]),
          owner: ownerlist[i],
          group: grouplist[i],
          mode: modelist[i],
          attr: attr,
          state: state,
          rdev: rdevlist[i]
        )
      end
    end

    private def dependencies(klass : T.class, nametag : Tag, versiontag : Tag, flagtag : Tag) : Array(T) forall T
      deps = [] of T

      nametd = nil
      versiontd = nil
      flagtd = nil
      begin
        nametd = LibRPM.rpmtdNew
        versiontd = LibRPM.rpmtdNew
        flagtd = LibRPM.rpmtdNew

        min = LibRPM::HeaderGetFlags::MINMEM

        return deps if LibRPM.headerGet(@hdr, nametag, nametd, min) != 1
        return deps if LibRPM.headerGet(@hdr, versiontag, versiontd, min) != 1
        return deps if LibRPM.headerGet(@hdr, flagtag, flagtd, min) != 1

        # LibRPM.rpmtdInit(nametd)
        while LibRPM.rpmtdNext(nametd) != -1
          deps << T.new(
            String.new(LibRPM.rpmtdGetString(nametd)),
            Version.new(String.new(LibRPM.rpmtdNextString(versiontd))),
            Sense.from_value(LibRPM.rpmtdNextUint32(flagtd).value), self
          )
        end
        deps
      ensure
        LibRPM.rpmtdFree(nametd) if nametd
        LibRPM.rpmtdFree(versiontd) if versiontd
        LibRPM.rpmtdFree(flagtd) if flagtd
      end
    end

    private def dependencies(klass : T.class) : Array(T) forall T
      dependencies(klass, T.nametag, T.versiontag, T.flagstag)
    end

    def requires
      dependencies(Require)
    end

    def provides
      dependencies(Provide)
    end

    def obsoletes
      dependencies(Obsolete)
    end

    def conflicts
      dependencies(Conflict)
    end

    private def get_tag_data(td : LibRPM::TagData, is_array : Bool,
                             &block : -> T) : T | Array(T) forall T
      if is_array
        ret = [] of T
        while LibRPM.rpmtdNext(td) != -1
          ret << yield
        end
        ret
      else
        yield
      end
    end

    def [](tag : DbiTag)
      tag = Tag.from_value?(tag.value)
      if tag
        self.[tag.as(RPM::Tag)]
      else
        nil
      end
    end

    def [](tag : Tag | TagValue)
      tagc = LibRPM.rpmtdNew
      return nil if tagc.null?
      begin
        return nil if LibRPM.headerGet(@hdr, tag, tagc, LibRPM::HeaderGetFlags::MINMEM) == 0

        type = LibRPM.rpmtdType(tagc)
        count = LibRPM.rpmtdCount(tagc)
        ret_type = RPM.tag_get_return_type(tag)

        is_array = false
        is_array = true if count > 1
        is_array = true if ret_type == TagReturnType::ARRAY

        case type
        when TagType::INT8
          get_tag_data(tagc, is_array) do
            LibRPM.rpmtdGetNumber(tagc).to_u8
          end
        when TagType::CHAR
          get_tag_data(tagc, is_array) do
            LibRPM.rpmtdGetNumber(tagc).to_u8
          end
        when TagType::INT16
          get_tag_data(tagc, is_array) do
            LibRPM.rpmtdGetNumber(tagc).to_u16
          end
        when TagType::INT32
          get_tag_data(tagc, is_array) do
            LibRPM.rpmtdGetNumber(tagc).to_u32
          end
        when TagType::INT64
          get_tag_data(tagc, is_array) do
            LibRPM.rpmtdGetNumber(tagc).to_u64
          end
        when TagType::STRING
          get_tag_data(tagc, is_array) do
            String.new(LibRPM.rpmtdGetString(tagc))
          end
        when TagType::STRING_ARRAY
          get_tag_data(tagc, true) do
            String.new(LibRPM.rpmtdGetString(tagc))
          end
        else
          raise Exception.new("Don't know hot to retrieve #{type}")
        end
      ensure
        LibRPM.rpmtdFree(tagc)
      end
    end
  end
end
