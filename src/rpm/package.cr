require "base64"

module RPM
  # Reperesents Changelog data
  struct ChangeLog
    property time : Time
    property name : String
    property text : String

    def initialize(@time, @name, @text)
    end
  end

  class PackageError < Exception
  end

  # RPM Package Header data container
  class Package
    @hdr : LibRPM::Header

    # Creates a new package header with given name and version
    def self.create(name : String, version : Version)
      hdr = LibRPM.headerNew
      if hdr.null?
        raise AllocationError.new("headerNew")
      end
      begin
        if LibRPM.headerPutString(hdr, Tag::Name, name) != 1
          raise PackageError.new("Can't set package name: #{name}")
        end
        if LibRPM.headerPutString(hdr, Tag::Version, version.v) != 1
          raise PackageError.new("Can't set package version: #{version.v}")
        end
        if (ee = version.e)
          epoch = ee.as(UInt32)
          if LibRPM.headerPutUint32(hdr, Tag::Epoch, pointerof(epoch), 1) != 1
            raise PackageError.new("Can't set package epoch: #{epoch}")
          end
        end
        if (release = version.r)
          if LibRPM.headerPutString(hdr, Tag::Release, release) != 1
            raise PackageError.new("Can't set package release: #{release}")
          end
        end
      rescue e : Exception
        LibRPM.headerFree(hdr)
        raise e
      end
      Package.new(hdr)
    end

    # Open existing RPM Package file
    def self.open(filename)
      RPM.transaction do |ts|
        Package.open(filename, transaction: ts)
      end
    end

    # Open existing RPM package file, using existing transaction
    def self.open(filename, *, transaction : Transaction)
      transaction.read_package_file(filename)
    end

    # :nodoc:
    def initialize(hdr : LibRPM::Header)
      if hdr.null?
        @hdr = LibRPM.headerNew
      else
        @hdr = LibRPM.headerLink(hdr)
      end
    end

    # Cleanup the handle to package header.
    #
    # The package header does not seem to depend to the external
    # resources (fd for the file or DB). So calling this method is not
    # mandated.
    def finalize
      @hdr = LibRPM.headerFree(@hdr)
    end

    # Format a string with package data
    #
    # The format is same to the `--queryformat` argument in `rpm -q`:
    # for example, `%{name}` will be replaced with the name of the
    # package and `%{version}` will be replaced with the version of
    # the package.
    def sprintf(fmt)
      error = uninitialized LibRPM::ErrorMsg
      val = LibRPM.headerFormat(@hdr, fmt, pointerof(error))
      raise PackageError.new(String.new(error)) if val.null?
      String.new(val)
    end

    # Returns the signature string
    #
    # Returns the signature string with hexadecimal charactors.
    # Returns the string `(none)` if not set.
    #
    # If you want a binary data, you may use
    # `#with_tagdata(Tag::SigMD5)` and `TagData#bytes`. But it just
    # converts back to binary from this hexadecimal character representation.
    def signature
      with_tagdata?(Tag::SigMD5) do |md5|
        if md5
          md5.format(0, TagDataFormat::STRING)
        else
          "(none)"
        end
      end
    end

    # Returns the name of package.
    #
    # Shorthand for calling `#[]` with `Tag::Name`.
    def name
      self[Tag::Name].as(String)
    end

    # Get the list of file paths.
    #
    # Handy function for getting file paths. Since RPM stores basename
    # and dirname separately, this method concatenate them to represents
    # list of fullpaths.
    def file_paths : Array(String)
      with_tagdata?(Tag::BaseNames) do |basenames|
        if basenames
          with_tagdata(Tag::DirNames, Tag::DirIndexes) do |dirname, diridxs|
            Array(String).new(basenames.size) do |i|
              basename = basenames[i].as(String)
              diridx = diridxs[i].as(UInt32)
              dirname = dirnames[diridx].as(String)
              File.join(dirname, basename)
            end
          end
        else
          [] of String
        end
      end
    end

    # Get the list of files with extra metadata.
    def files : Array(RPM::File)
      with_tagdata?(Tag::BaseNames) do |basenames|
        if basenames
          # (considered to be) mandatory tags when basenames exists.
          tags = {Tag::DirNames, Tag::DirIndexes, Tag::FileSizes,
                  Tag::FileModes, Tag::FileMTimes, Tag::FileRDEVs,
                  Tag::FileLinkTos, Tag::FileDigests, Tag::FileUserName,
                  Tag::FileGroupName}
          with_tagdata(*tags) do |dirnames, diridxs, sizes, modes, mtimes, rdevs, links, digests, owners, groups|
            with_tagdata?(Tag::FileStates, Tag::FileFlags) do |states, flags|
              if states
                # FileStates is stored in CHAR type, but we want
                # integral values.
                states.force_return_type!(TagData::ReturnTypeInt8)
              end
              Array(RPM::File).new(basenames.size) do |i|
                basename = basenames[i].as(String)
                diridx = diridxs[i].as(UInt32)
                dirname = dirnames[diridx].as(String)
                size = sizes[i].as(UInt32)
                mode = modes[i].as(UInt16)
                mtime = mtimes[i].as(UInt32)
                rdev = rdevs[i].as(UInt16)
                link = links[i].as(String)
                digest = digests[i].as(String)
                owner = owners[i].as(String)
                group = groups[i].as(String)
                state = if states
                          FileState.from_value(states[i].as(UInt8).to_i8!)
                        else
                          FileState::NORMAL
                        end
                attr = if flags
                         FileAttrs.from_value(flags[i].as(UInt32))
                       else
                         FileAttrs::NONE
                       end
                RPM::File.new(
                  path: ::File.join(dirname, basename),
                  digest: digest,
                  link_to: link,
                  size: size,
                  mtime: Time.unix(mtime),
                  owner: owner,
                  group: group,
                  mode: mode,
                  attr: attr,
                  state: state,
                  rdev: rdev,
                )
              end
            end
          end
        else
          [] of RPM::File
        end
      end
    end

    private def dependencies(klass : T.class, nametag : Tag, versiontag : Tag, flagtag : Tag) : Array(T) forall T
      with_tagdata?(nametag, versiontag, flagtag) do |nametd, versiontd, flagtd|
        if nametd && versiontd && flagtd
          Array(T).new(nametd.size) do |i|
            name = nametd[i].as(String)
            version = Version.new(versiontd[i].as(String))
            sense = Sense.from_value(flagtd[i].as(UInt32))
            T.new(name, version, sense, self)
          end
        else
          [] of T
        end
      end
    end

    private def dependencies(klass : T.class) : Array(T) forall T
      dependencies(klass, T.nametag, T.versiontag, T.flagstag)
    end

    # Get the list of "Require" dependencies.
    def requires
      dependencies(Require)
    end

    # Get the list of "Provide" dependencies.
    def provides
      dependencies(Provide)
    end

    # Get the list of "Obsolete" dependencies.
    def obsoletes
      dependencies(Obsolete)
    end

    # Get the list of "Conflict" dependencies.
    def conflicts
      dependencies(Conflict)
    end

    # Get the list of Changelogs.
    def changelogs
      with_tagdata?(Tag::ChangeLogTime, Tag::ChangeLogName, Tag::ChangeLogText) do |timetd, nametd, texttd|
        if timetd && nametd && texttd
          Array(ChangeLog).new(timetd.size) do |i|
            time = timetd[i].as(UInt32)
            name = nametd[i].as(String)
            text = texttd[i].as(String)
            ChangeLog.new(Time.unix(time), name, text)
          end
        else
          [] of ChangeLog
        end
      end
    end

    # Get `TagData` for given `Tag`.
    #
    # Raises KeyError if the given tag is not found.
    def get_tagdata(tag : Tag | TagValue, *, flags : HeaderGetFlags = HeaderGetFlags::MINMEM)
      TagData.create do |ptr|
        if LibRPM.headerGet(@hdr, tag, ptr, flags) == 0
          raise KeyError.new("No entry for tag #{tag} found")
        end
        1
      end
    end

    # Get `TagData` for given `Tag`
    #
    # Returns `nil` if the given tag is not found.
    def get_tagdata?(tag : Tag | TagValue, *, flags : HeaderGetFlags = HeaderGetFlags::MINMEM)
      TagData.create? do |ptr|
        LibRPM.headerGet(@hdr, tag, ptr, flags)
      end
    end

    # Get `TagData` for given `Tag`.
    #
    # Raises `TypeCastError` if the given tag is not valid for `Tag`.
    # Raises `KeyError` if the given tag is not found.
    def get_tagdata(tag : DbiTag, **opts)
      ttag = Tag.from_value?(tag.value)
      if ttag
        get_tagdata(ttag, **opts)
      else
        raise TypeCastError.new("No Tag counterpart for DbiTag::#{tag}")
      end
    end

    # Get `TagData` for given `Tag`
    #
    # Returns `nil` if the given tag is not found, or not valid tag.
    def get_tagdata?(tag : DbiTag, **opts)
      ttag = Tag.from_value?(tag.value)
      if ttag
        get_tagdata?(ttag, **opts)
      else
        nil
      end
    end

    # Get `TagData`(s) for given `Tag`(s), yield them and then cleanup them.
    #
    # Returns the result of given block.
    #
    # Raises `KeyError` if one of `tags` is not found. In this case,
    # the block will not be yielded.
    def with_tagdata(*tags, **opts, &block)
      tdata = tags.map do |tag|
        begin
          get_tagdata(tag, **opts)
        rescue e : Exception
          e
        end
      end
      begin
        if ex = tdata.find { |x| x.is_a?(Exception) }
          raise ex.as(Exception)
        end
        tdata_x = tdata.map do |td|
          td.as(TagData)
        end
        yield(*tdata_x)
      ensure
        tdata.each do |td|
          if td.is_a?(TagData)
            td.finalize
          end
        end
      end
    end

    # Get `TagData`(s) for given `Tag`(s), yield them and then cleanup them.
    #
    # Returns the result of given block.
    #
    # If some of `tags` are not found, this method pass `nil` for them.
    def with_tagdata?(*tags, **opts, &block)
      tdata = tags.map { |tag| get_tagdata?(tag, **opts) }
      begin
        yield(*tdata)
      ensure
        tdata.each do |td|
          if td
            td.finalize
          end
        end
      end
    end

    # Get the value of given `Tag` directly.
    #
    # Raises `KeyError` if given `Tag` is not found.
    def [](tag)
      with_tagdata(tag, flags: HeaderGetFlags.flags(MINMEM, EXT)) do |tg|
        tg.value
      end
    end

    # Get the value of given `Tag` directly.
    #
    # If given `Tag` is not found, returns `nil`.
    def []?(tag)
      with_tagdata?(tag, flags: HeaderGetFlags.flags(MINMEM, EXT)) do |tg|
        if tg
          tg.value
        else
          nil
        end
      end
    end

    # Returns pointer to `header` to deal with librpm C API directly.
    def to_unsafe
      @hdr
    end
  end
end
