require "../spec_helper"
require "tempdir"

describe RPM::Package do
  describe "#name" do
    it "has a name" do
      pkg = RPM::Package.create("foo", RPM::Version.new("1.0"))
      pkg.name.should eq("foo")
    end
  end

  describe "#signature" do
    it "has no signature" do
      pkg = RPM::Package.create("foo", RPM::Version.new("1.0"))
      pkg.signature.should eq("(none)")
    end
  end

  describe "reading package" do
    it "provides dependency" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      req = RPM::Require.new("simple", RPM::Version.new("1.0", "0"),
        RPM::Sense.flags(GREATER, EQUAL), nil)
      req.satisfies?(pkg).should be_true
    end

    it "has a known signature" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg.signature.should eq("3b5f9d468c877166532c662e29f43bc3")
    end

    it "can provide TagData" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      tag = pkg.get_tagdata(RPM::Tag::Arch)
      begin
        tag.size.should eq(1)
        tag[0].should eq("i586")
      ensure
        tag.finalize
      end

      tag = pkg.get_tagdata(RPM::Tag::Name)
      begin
        tag.size.should eq(1)
        tag[0].should eq("simple")
      ensure
        tag.finalize
      end
    end

    it "has a name 'simple'" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg[RPM::Tag::Name].should eq("simple")
    end

    it "is built for i586" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg[RPM::Tag::Arch].should eq("i586")
    end

    # [LANG, Summary, Description]
    {% for lang in [["C", "Simple dummy package", "Dummy package"],
                    ["es_ES.UTF-8", "Paquete simple de muestra", "Paquete de muestra"]] %}
      it "has a {{lang[0].id}} summary" do
        pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
        old_lang = ENV["LC_ALL"]?
        begin
          ENV["LC_ALL"] = {{lang[0]}}
          pkg[RPM::Tag::Summary].should eq({{lang[1]}})
        ensure
          ENV["LC_ALL"] = old_lang
        end
      end
      it "has a {{lang[0].id}} description" do
        pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
        old_lang = ENV["LC_ALL"]?
        begin
          ENV["LC_ALL"] = {{lang[0]}}
          pkg[RPM::Tag::Description].should eq({{lang[2]}})
        ensure
          ENV["LC_ALL"] = old_lang
        end
      end
    {% end %}

    it "has a signature" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg[RPM::Tag::SigMD5].should eq(Bytes[0x3b, 0x5f, 0x9d, 0x46, 0x8c, 0x87, 0x71, 0x66, 0x53, 0x2c, 0x66, 0x2e, 0x29, 0xf4, 0x3b, 0xc3])
    end

    it "contains 2 files owned by root" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg[RPM::Tag::FileUserName].should eq(%w[root root])
    end
    it "contains 2 files with known sizes" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg[RPM::Tag::FileSizes].should eq([6, 5])
    end

    it "provides 2 dependencies" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg.provides.map { |x| x.name }.to_set
        .should eq(Set{"simple(x86-32)", "simple"})
    end

    it "contains 2 files with known paths" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg.files.map { |x| x.path }.to_set
        .should eq(Set{
        "/usr/share/simple/README",
        "/usr/share/simple/README.es",
      })
    end

    it "contains a empty link_to for a regular file" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      file = pkg.files.find { |x| x.path == "/usr/share/simple/README" }
      file.is_a?(RPM::File).should be_true

      file = file.as(RPM::File)

      # ruby-rpm asserts this is nil (converted at File#initialize),
      # but RPM API returns an empty string, so we decided to keep it
      # as-is.
      file.link_to.should eq("")
    end
  end

  describe "dependencies of a package" do
    it "has a known name" do
      pkg = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      pkg.name.should eq("simple_with_deps")
    end

    it "provides \"simple_with_deps(x86-32)\"" do
      pkg = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      pkg.provides.any? { |x| x.name == "simple_with_deps(x86-32)" }.should be_true
    end

    it "provides \"simple_with_deps\"" do
      pkg = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      pkg.provides.any? { |x| x.name == "simple_with_deps" }.should be_true
    end

    it "requires \"a\"" do
      pkg = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      pkg.requires.any? { |x| x.name == "a" }.should be_true
    end

    it "requires \"b\"" do
      pkg = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      b = pkg.requires.find { |x| x.name == "b" }
      b.should be_truthy
    end

    it "requires \"b-1.0\"" do
      pkg = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      b = pkg.requires.find { |x| x.name == "b" }
      req = b.as(RPM::Require)
      req.version.to_s.should eq("1.0")
    end

    it "conflicts with \"c\"" do
      pkg = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      pkg.conflicts.any? { |x| x.name == "c" }.should be_true
    end

    it "conflicts with \"d\"" do
      pkg = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      pkg.conflicts.any? { |x| x.name == "d" }.should be_true
    end

    it "obsoletes \"f\"" do
      pkg = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      pkg.obsoletes.any? { |x| x.name == "f" }.should be_true
    end
  end
end
