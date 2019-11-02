require "../spec_helper"
require "tempdir"

describe RPM::File do
  describe "#flags" do
    it "returns extra file flags" do
      time = Time.utc(2019, 1, 1, 12, 0, 0)
      f = RPM::File.new("path", "md5sum", "", 42_u32, time, "owner", "group",
        43_u16, 0o100777_u16, RPM::FileAttrs.from_value(44_u32),
        RPM::FileState::NORMAL)

      f.flags.should eq(::File::Flags::None)
    end
  end

  describe "#type" do
    it "returns file type" do
      time = Time.utc(2019, 1, 1, 12, 0, 0)
      f = RPM::File.new("path", "md5sum", "", 42_u32, time, "owner", "group",
        43_u16, 0o100777_u16, RPM::FileAttrs.from_value(44_u32),
        RPM::FileState::NORMAL)
      f.type.should eq(::File::Type::File)

      f.mode = 0o777_u16 | LibC::S_IFBLK
      f.type.should eq(::File::Type::BlockDevice)

      f.mode = 0o777_u16 | LibC::S_IFCHR
      f.type.should eq(::File::Type::CharacterDevice)

      f.mode = 0o777_u16 | LibC::S_IFDIR
      f.type.should eq(::File::Type::Directory)

      f.mode = 0o777_u16 | LibC::S_IFLNK
      f.type.should eq(::File::Type::Symlink)

      f.mode = 0o777_u16 | LibC::S_IFIFO
      f.type.should eq(::File::Type::Pipe)

      f.mode = 0o777_u16 | LibC::S_IFSOCK
      f.type.should eq(::File::Type::Socket)

      f.mode = 0o777_u16 | LibC::S_IFREG
      f.type.should eq(::File::Type::File)

      f.mode = 0o777_u16
      f.type.should eq(::File::Type::Unknown)
    end
  end

  describe "#permissions" do
    it "returns permission structure" do
      time = Time.utc(2019, 1, 1, 12, 0, 0)
      f = RPM::File.new("path", "md5sum", "", 42_u32, time, "owner", "group",
                        43_u16, 0o100777_u16, RPM::FileAttrs.from_value(44_u32),
                        RPM::FileState::NORMAL)
      f.permissions.should eq(::File::Permissions.flags(OtherAll, GroupAll, OwnerAll))
    end
  end

  describe "#link_to" do
    it "returns empty string for a regular file" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      file = pkg.files.find { |x| x.path == "/usr/share/simple/README" }
      file = file.as(RPM::File)

      # ruby-rpm asserts this is nil (converted at File#initialize),
      # but RPM API returns an empty string, so we decided to keep it
      # as-is.
      file.link_to.should eq("")
      file.type.should eq(::File::Type::File)
    end
  end
end
