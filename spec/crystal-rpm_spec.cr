require "./spec_helper"
require "file_utils"

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

  it "create/free a transaction" do
    ts = RPM::LibRPM.rpmtsCreate
    RPM::LibRPM.rpmtsSetRootDir(ts, "/")
    iter = RPM::LibRPM.rpmtsInitIterator(ts, 0, nil, 0)
    hdrs = [] of RPM::LibRPM::Header
    until (hdr = RPM::LibRPM.rpmdbNextIterator(iter)).null?
      hdrs << hdr
      ptr = RPM::LibRPM.headerGetAsString(hdr, RPM::Tag::Name)
      begin
        str = String.new(ptr)
      ensure
        LibC.free(ptr)
      end
    end
  ensure
    RPM::LibRPM.rpmdbFreeIterator(iter) if iter
    RPM::LibRPM.rpmtsFree(ts) if ts
  end

  it "macrofiles is set" do
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

  pkg = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
  describe "dependencies of #{pkg}" do
    it "has a known name" do
      pkg.name.should eq("simple_with_deps")
    end

    it "provides \"simple_with_deps(x86-32)\"" do
      pkg.provides.any? { |x| x.name == "simple_with_deps(x86-32)" }.should be_true
    end

    it "provides \"simple_with_deps\"" do
      pkg.provides.any? { |x| x.name == "simple_with_deps" }.should be_true
    end

    it "requires \"a\"" do
      pkg.requires.any? { |x| x.name == "a" }.should be_true
    end

    b = pkg.requires.find { |x| x.name == "b" }
    it "requires \"b\"" do
      b.should be_truthy
    end

    it "requires \"b-1.0\"" do
      req = b.as(RPM::Require)
      req.version.to_s.should eq("1.0")
    end

    it "conflicts with \"c\"" do
      pkg.conflicts.any? { |x| x.name == "c" }.should be_true
    end

    it "conflicts with \"d\"" do
      pkg.conflicts.any? { |x| x.name == "d" }.should be_true
    end

    it "obsoletes \"f\"" do
      pkg.obsoletes.any? { |x| x.name == "f" }.should be_true
    end
  end
end

tmproot = File.join(File.dirname(__FILE__), "work")
Dir.mkdir(tmproot)
begin
  describe RPM::Transaction do
    describe "#root_dir" do
      RPM.transaction do |ts|
        it "has default root directory \"/\"" do
          ts.root_dir.should eq("/")
        end
        it "has been set to root directory \"#{tmproot}\"" do
          ts.root_dir = tmproot
          ts.root_dir.should eq(tmproot + "/")
        end
      end
    end

    describe "#flags" do
      RPM.transaction do |ts|
        it "has default transaction flag NONE" do
          ts.flags.should eq(RPM::TransactionFlags::NONE)
        end
        ts.flags = RPM::TransactionFlags::TEST
        it "has now tranaction flag TEST" do
          ts.flags.should eq(RPM::TransactionFlags::TEST)
        end
      end
    end

    describe "Test install" do
      path = fixture("simple-1.0-0.i586.rpm")
      pkg = RPM::Package.open(path)
      RPM.transaction(tmproot) do |ts|
        begin
          ts.install(pkg, path)
          ts.commit
        ensure
          ts.db.close
        end
      end
      describe "#install-ed \"#{pkg[RPM::Tag::Name]}\"" do
        test_path = File.join(tmproot, "usr/share/simple/README")
        it "#{test_path} exists?" do
          File.exists?(test_path).should be_true
        end
      end
    end

    describe "Test iterator" do
      RPM.transaction do |ts|
        describe "#init_iterator" do
          iter = ts.init_iterator
          it "returns MatchIterator" do
            iter.class.should eq(RPM::MatchIterator)
          end
        end
      end

      a_installed_pkg = nil
      RPM.transaction do |ts|
        iter = ts.init_iterator
        iter.each do |pkg|
          a_installed_pkg = pkg
          break
        end
      end
      if a_installed_pkg.nil?
        STDERR.puts "No packages installed in your system!!"
      else
        # Uses an installed package as an example
        sample_pkg = a_installed_pkg.as(RPM::Package)
        RPM.transaction do |ts|
          vers = sample_pkg[RPM::Tag::Version].as(String)
          iter = ts.init_iterator
          describe "#version" do
            it "looks for packages whose version is \"#{vers}\"" do
              iter.version(RPM::Version.new(vers))
              iter.each do |sig|
                sig[RPM::Tag::Version].should eq(vers)
              end
            end
          end
        end
      end

    end
  end
ensure
  FileUtils.rm_rf(tmproot)
end
