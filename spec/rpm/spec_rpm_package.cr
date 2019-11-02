require "../spec_helper"
require "tempdir"

describe RPM::Package do
  describe "#name" do
    it "returns package name" do
      pkg = RPM::Package.create("foo", RPM::Version.new("1.0"))
      pkg.name.should eq("foo")
    end
  end

  describe "#signature" do
    it "returns \"(none)\" for no signature" do
      pkg = RPM::Package.create("foo", RPM::Version.new("1.0"))
      pkg.signature.should eq("(none)")
    end

    it "returns hexadecimal string sigunature" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg.signature.should eq("3b5f9d468c877166532c662e29f43bc3")
    end
  end

  describe "#get_tagdata" do
    it "provides tagdata" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      tagdata = pkg.get_tagdata(RPM::Tag::Arch)
      begin
        tagdata.size.should eq(1)
        tagdata[0].should eq("i586")
      ensure
        tagdata.finalize
      end
    end

    it "can get EXT data with flag" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      tagdata = pkg.get_tagdata(RPM::Tag::NVR, flags: RPM::HeaderGetFlags.flags(MINMEM, EXT))
      begin
        tagdata.size.should eq(1)
        tagdata[0].should eq("simple-1.0-0")
      ensure
        tagdata.finalize
      end
    end

    it "raises KeyError if not found" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      expect_raises(KeyError) do
        pkg.get_tagdata(RPM::Tag::NEVRA)
      end
    end
  end

  describe "#get_tagdata?" do
    it "provides tagdata" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      tagdata = pkg.get_tagdata?(RPM::Tag::Arch)
      begin
        tagdata.should_not be_nil
        tagdata = tagdata.not_nil!
        tagdata.size.should eq(1)
        tagdata[0].should eq("i586")
      ensure
        if tagdata
          tagdata.finalize
        end
      end
    end

    it "raises KeyError if not found" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg.get_tagdata?(RPM::Tag::NEVRA).should be_nil
    end
  end

  describe "#with_tagdata" do
    it "provides tagdata" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      ret = pkg.with_tagdata(RPM::Tag::Arch) do |arch|
        arch.value.should eq("i586")
        true
      end
      ret.should be_true
    end

    it "can handle multiple tagdata" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      ret = pkg.with_tagdata(RPM::Tag::Name, RPM::Tag::Arch) do |name, arch|
        name.value.should eq("simple")
        arch.value.should eq("i586")
        true
      end
      ret.should be_true
    end

    it "raises KeyError if not found" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      expect_raises(KeyError) do
        pkg.with_tagdata(RPM::Tag::NEVRA) do |nevra|
          # NOP
        end
      end
    end
  end

  describe "#[]" do
    it "can obtain base data" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg[RPM::Tag::Name].should eq("simple")
    end

    it "can obtain array string data" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg[RPM::Tag::FileUserName].should eq(%w[root root])
    end

    it "can obtain array integral data" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg[RPM::Tag::FileSizes].should eq([6, 5])
    end

    it "can obtain ext data" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg[RPM::Tag::NEVRA].should eq("simple-1.0-0.i586")
    end

    it "returns binary data for signature" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg[RPM::Tag::SigMD5].should eq(Bytes[0x3b, 0x5f, 0x9d, 0x46, 0x8c, 0x87, 0x71, 0x66, 0x53, 0x2c, 0x66, 0x2e, 0x29, 0xf4, 0x3b, 0xc3])
    end

    describe "returns localized summary" do
      it "for C locale" do
        old_lang = ENV["LC_ALL"]?
        ENV["LC_ALL"] = "C"
        begin
          pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
          pkg[RPM::Tag::Summary].should eq("Simple dummy package")
        ensure
          ENV["LC_ALL"] = old_lang
        end
      end

      it "for es locale" do
        old_lang = ENV["LC_ALL"]?
        ENV["LC_ALL"] = "es_ES.UTF-8"
        begin
          pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
          pkg[RPM::Tag::Summary].should eq("Paquete simple de muestra")
        ensure
          ENV["LC_ALL"] = old_lang
        end
      end
    end
  end

  describe "#provides" do
    it "returns list of Provides" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg.provides.map { |x| x.name }.to_set
        .should eq(Set{"simple(x86-32)", "simple"})
    end

    it "returns list of Provides" do
      pkg = RPM::Package.create("foo", RPM::Version.new("1.0"))
      pkg.provides.should eq([] of RPM::Provide)
    end
  end

  describe "#requires" do
    it "returns list of Requires" do
      pkg = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      requires = pkg.requires
      requires.any? { |x| x.name == "a" }.should be_true
      b = requires.find { |x| x.name == "b" }.tap { |x| x.should be_truthy }
      req = b.as(RPM::Require)
      req.version.to_s.should eq("1.0")
    end

    it "returns list of Requires" do
      pkg = RPM::Package.create("foo", RPM::Version.new("1.0"))
      pkg.requires.should eq([] of RPM::Require)
    end
  end

  describe "#conflicts" do
    it "returns list of Conflicts" do
      pkg = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      conflicts = pkg.conflicts
      conflicts.any? { |x| x.name == "c" }.should be_true
      conflicts.any? { |x| x.name == "d" }.should be_true
    end

    it "returns list of Conflicts" do
      pkg = RPM::Package.create("foo", RPM::Version.new("1.0"))
      pkg.requires.should eq([] of RPM::Conflict)
    end
  end

  describe "#obsoletes" do
    it "returns list of Obsoletes" do
      pkg = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      obsoletes = pkg.obsoletes
      obsoletes.any? { |x| x.name == "f" }.should be_true
    end

    it "returns list of Obsoletes" do
      pkg = RPM::Package.create("foo", RPM::Version.new("1.0"))
      pkg.obsoletes.should eq([] of RPM::Obsolete)
    end
  end

  describe "#files" do
    it "returns list of files" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg.files.map { |x| x.path }.to_set
        .should eq(Set{
        "/usr/share/simple/README",
        "/usr/share/simple/README.es",
      })
    end
  end

  describe "#changelogs" do
    it "returns list of ChangeLogs" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      changelogs = pkg.changelogs
      changelogs[0].should eq(RPM::ChangeLog.new(Time.utc(2011, 11, 6, 12, 0, 0), "Duncan Mac-Vicar P. <dmacvicar@suse.de>", "- Fix something"))
      changelogs[1].should eq(RPM::ChangeLog.new(Time.utc(2011, 11, 5, 12, 0, 0), "Duncan Mac-Vicar P. <dmacvicar@suse.de>", "- Fix something else"))
      expect_raises(IndexError) do
        changelogs[2]
      end
    end
  end
end
