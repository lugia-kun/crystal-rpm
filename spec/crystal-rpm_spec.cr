require "./spec_helper"

describe RPM do
  puts "Using RPM version #{RPM::PKGVERSION}"

  it "has a VERSION matches obtained from pkg-config" do
    RPM::RPMVERSION.should start_with(RPM::PKGVERSION)
  end

  it "has a version code" do
    RPM.rpm_version_code.should eq(RPM::PKGVERSION_CODE)
  end
end

describe "RPM::Lib" do
  it "create/free a header" do
    ptr = RPM::LibRPM.headerNew
    RPM::LibRPM.headerFree(ptr)
  end

  # TODO: DB entry is empty unless `%{_dbpath}` is correctly set.
  it "create/free a transaction" do
    ts = RPM::LibRPM.rpmtsCreate
    RPM::LibRPM.rpmtsSetRootDir(ts, "/")
    iter = RPM::LibRPM.rpmtsInitIterator(ts, 0, nil, 0)
    hdrs = [] of RPM::LibRPM::Header
    until (hdr = RPM::LibRPM.rpmdbNextIterator(iter)).null?
      hdrs << hdr
      RPM::LibRPM.headerGetAsString(hdr, RPM::Tag::Name)
    end
  ensure
    RPM::LibRPM.rpmdbFreeIterator(iter) if iter
    RPM::LibRPM.rpmtsFree(ts) if ts
  end

  pending "macrofiles is set" do
    RPM::MACROFILES.should start_with("")
  end
end

describe RPM::File do
  f = RPM::File.new("path", "md5sum", "", 42_u32,
    Time.new(2019, 1, 1, 9, 0, 0), "owner", "group",
    43_u16, 0o777_u16, RPM::FileAttrs.from_value(44_u32),
    RPM::FileState::NORMAL)
  it "has flags" do
    f.config?
    f.doc?
    f.is_missingok?
    f.is_noreplace?
    f.is_specfile?
    f.ghost?
    f.license?
    f.readme?
    f.replaced?
    f.notinstalled?
    f.netshared?
    f.missing?
  end
end

describe RPM::Package do
  pkg = RPM::Package.create("foo", RPM::Version.new("1.0"))
  describe "created package #{pkg}" do
    it "has name 'foo'" do
      pkg.name.should eq("foo")
    end

    it "has no signature" do
      pkg.signature.should eq("(none)")
    end
  end

  pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
  describe "opened package #{pkg}" do
    req = RPM::Require.new("simple", RPM::Version.new("1.0", "0"),
      RPM::Sense::GREATER | RPM::Sense::EQUAL, nil)
    it "provides dependency #{req.to_dnevr}" do
      req.satisfies?(pkg).should be_true
    end

    it "has a known signature" do
      pkg.signature.should eq("3b5f9d468c877166532c662e29f43bc3")
    end

    it "has a name 'simple'" do
      pkg[RPM::Tag::Name].should eq("simple")
    end

    it "is built for i586" do
      pkg[RPM::Tag::Arch].should eq("i586")
    end

    old_lang = ENV["LC_ALL"]?
    ENV["LC_ALL"] = "C"

    it "has a summary" do
      pkg[RPM::Tag::Summary].should eq("Simple dummy package")
    end
    it "has a description" do
      pkg[RPM::Tag::Description].should eq("Dummy package")
    end

    ENV["LC_ALL"] = "es_ES.UTF-8"

    it "has a Spanish summary" do
      pkg[RPM::Tag::Summary].should eq("Paquete simple de muestra")
    end
    it "has a Spanish description" do
      pkg[RPM::Tag::Description].should eq("Paquete de muestra")
    end

    ENV["LC_ALL"] = old_lang

    it "contains 2 files ownd by root" do
      pkg[RPM::Tag::FileUserName].should eq(%w[root root])
    end
    it "contains 2 files with known sizes" do
      pkg[RPM::Tag::FileSizes].should eq([6, 5])
    end

    it "provides 2 dependencies" do
      pkg.provides.map { |x| x.name }.to_set
        .should eq(Set{"simple(x86-32)", "simple"})
    end

    it "contains 2 files with known paths" do
      pkg.files.map { |x| x.path }.to_set
        .should eq(Set{
        "/usr/share/simple/README",
        "/usr/share/simple/README.es",
      })
    end

    it "contains a empty link_to for a regular file" do
      file = pkg.files.find { |x| x.path == "/usr/share/simple/README" }
      file.is_a?(RPM::File).should be_true

      file = file.as(RPM::File)

      # ruby-rpm asserts this is nil (converted at File#initialize),
      # but RPM API returns an empty string, so we decided to keep it
      # as-is.
      file.link_to.should eq("")
    end
  end
end
