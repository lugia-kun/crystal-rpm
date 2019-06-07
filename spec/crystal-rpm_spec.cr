require "./spec_helper"
require "tempdir"

describe RPM do
  puts "Using RPM version #{RPM::PKGVERSION}"

  it "has a VERSION matches obtained from pkg-config" do
    RPM::RPMVERSION.should eq(RPM::PKGVERSION)
  end

  it "has a VERSION matches comparable version" do
    RPM::RPMVERSION.should start_with(RPM::PKGVERSION_COMP)
  end

  it "has extracted numeric VERSIONs" do
    sp = RPM::RPMVERSION.split(/[^0-9]+/)
    RPM::PKGVERSION_MAJOR.should eq(sp[0].to_i)
    RPM::PKGVERSION_MINOR.should eq(sp[1].to_i)
    RPM::PKGVERSION_PATCH.should eq(sp[2].to_i)
    if sp.size > 3
      RPM::PKGVERSION_EXTRA.should eq(sp[3].to_i)
      RPM::PKGVERSION_EXTRA.should_not eq(0)

      # currently not supported, so we need to know if required.
      sp.size.should be <= 4
    else
      RPM::PKGVERSION_EXTRA.should eq(0)
    end
  end

  describe ".[]" do
    it "can obtain macro value" do
      RPM["_usr"].should eq("/usr")
    end
    it "raises Exception if not found" do
      expect_raises(KeyError) do
        puts RPM["not-defined"]
      end
    end
  end

  describe ".[]?" do
    it "can obtain macro value" do
      RPM["_usr"]?.should eq("/usr")
    end
    it "nil if not found" do
      RPM["not-defined"]?.should be_nil
    end
  end

  describe ".[]=" do
    it "can set macro" do
      RPM["hoge"] = "hoge"
      RPM["hoge"].should eq("hoge")
    end
    it "can remove macro" do
      RPM["hoge"]?.should_not be_nil
      RPM["hoge"] = nil
      RPM["hoge"]?.should be_nil
    end
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

describe RPM::Dependency do
  prv1 = RPM::Provide.new("foo", RPM::Version.new("2", "1"),
    RPM::Sense::EQUAL, nil)
  req1 = RPM::Require.new("foo", RPM::Version.new("1", "1"),
    RPM::Sense::EQUAL | RPM::Sense::GREATER, nil)
  prv2 = RPM::Provide.new("foo", RPM::Version.new("2", "2"),
    RPM::Sense::EQUAL, nil)
  req2 = RPM::Require.new("bar", RPM::Version.new("1", "1"),
    RPM::Sense::EQUAL | RPM::Sense::GREATER, nil)

  describe "#satisfies?" do
    it "returns true if dependencies satisfy" do
      req1.satisfies?(prv1).should be_true
      prv1.satisfies?(req1).should be_true
    end

    it "returns false if name does not overlap" do
      req2.satisfies?(prv2).should be_false
    end
  end
end

describe RPM::File do
  f =
    {% begin %}
    RPM::File.new("path", "md5sum", "", 42_u32,
                  {% if Time.class.methods.find { |x| x.name == "local" } %}
                    Time.local(2019, 1, 1, 9, 0, 0),
                  {% else %}
                    Time.new(2019, 1, 1, 9, 0, 0),
                  {% end %}
                  "owner", "group",
                  43_u16, 0o777_u16, RPM::FileAttrs.from_value(44_u32),
                  RPM::FileState::NORMAL)
    {% end %}
  it "has flags" do
    f.symlink?.should be_false
    f.config?.should be_false
    f.doc?.should be_false
    f.is_missingok?.should be_true
    f.is_noreplace?.should be_false
    f.is_specfile?.should be_true
    f.ghost?.should be_false
    f.license?.should be_false
    f.readme?.should be_false
    f.replaced?.should be_false
    f.notinstalled?.should be_false
    f.netshared?.should be_false
    f.missing?.should be_false
  end
end

describe RPM::TagData do
  describe "#create" do
    it "creates string data" do
      data = RPM::TagData.create("foo", RPM::Tag::Name)
      data.value_no_array.should eq("foo")
      expect_raises(TypeCastError) do
        data.value_array
      end
      data.value.should eq("foo")
      data.base64.should eq("(not a blob)")
      data.to_s.should eq("foo")
    end

    it "creates array string data" do
      data = RPM::TagData.create(["foo", "bar", "baz"], RPM::Tag::BaseNames)
      data.size.should eq(3)
      data.value_array.should eq(["foo", "bar", "baz"])
      data.value.should eq(["foo", "bar", "baz"])
      data.base64.should eq("(not a blob)")
      data.to_s.should eq(%(["foo", "bar", "baz"]))
    end

    it "creates integer data" do
      expect_raises(TypeCastError) do
        RPM::TagData.create([1_u8], RPM::Tag::DirIndexes)
      end
      data = RPM::TagData.create([1_u32, 2_u32], RPM::Tag::DirIndexes)
      data.size.should eq(2)
      expect_raises(TypeCastError) do
        data.value_no_array
      end
      data.value_array.should eq(Slice[1_u32, 2_u32])
      data.value.should eq(Slice[1_u32, 2_u32])
      data.base64.should eq("(not a blob)")
      data.to_s.should eq(%(["1", "2"]))
    end

    it "creates binary data" do
      slice = Array(UInt8).build(16) do |x|
        (1..16).each do |m|
          x[m] = m.to_u8
        end
        16
      end
      data = RPM::TagData.create(slice, RPM::Tag::SigMD5)
      data.value.should eq(Bytes[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
      data.base64.should eq("AAECAwQFBgcICQoLDA0ODw==\n")
      data.to_s.should eq("000102030405060708090a0b0c0d0e0f")
    end
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

    it "can provide TagData" do
      tag = RPM::TagData.for(pkg.hdr, RPM::Tag::Arch)
      tag.size.should eq(1)
      tag[0].should eq("i586")

      tag = RPM::TagData.for(pkg, RPM::Tag::Name)
      tag.size.should eq(1)
      tag[0].should eq("simple")
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
    it "has a signature" do
      pkg[RPM::Tag::SigMD5].should eq(Bytes[0x3b, 0x5f, 0x9d, 0x46, 0x8c, 0x87, 0x71, 0x66, 0x53, 0x2c, 0x66, 0x2e, 0x29, 0xf4, 0x3b, 0xc3])
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

describe RPM::Problem do
  describe ".create-ed problem (RPM 4.9 style)" do
    problem = RPM::Problem.new(RPM::ProblemType::REQUIRES, "foo-1.0-0", "foo.rpm", "bar-1.0-0", "Hello", 1)
    it "has #key" do
      String.new(problem.key.as(Pointer(UInt8))).should eq("foo.rpm")
    end

    it "has #type" do
      problem.type.should eq(RPM::ProblemType::REQUIRES)
    end

    it "has string #str" do
      {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
        problem.str.should eq("foo-1.0-0")
      {% else %}
        problem.str.should eq("Hello")
      {% end %}
    end

    it "descriptive #to_s" do
      problem.to_s.should eq("Hello is needed by (installed) bar-1.0-0")
    end
  end

  problem = RPM::Problem.new(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "", "  Hello", 0)
  describe ".create-ed problem (RPM 4.8 style)" do
    it "has #type" do
      problem.type.should eq(RPM::ProblemType::REQUIRES)
    end

    it "has string #str" do
      {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
        problem.str.should eq("")
      {% else %}
        problem.str.should eq("Hello")
      {% end %}
    end

    it "descriptive #to_s" do
      problem.to_s.should eq("Hello is needed by (installed) bar-1.0-0")
    end
  end

  problem2 = RPM::Problem.new(problem.ptr)
  describe ".new from Existing pointer" do
    it "has same key" do
      problem2.key.should eq(problem.key)
    end

    it "has same type" do
      problem2.type.should eq(problem.type)
    end

    it "has same str" do
      problem2.str.should eq(problem.str)
    end

    it "has same description" do
      problem2.to_s.should eq(problem.to_s)
    end

    it "can duplicate" do
      d = problem2.dup
      d.key.should eq(problem.key)
    end
  end
end

describe RPM::Transaction do
  describe "#root_dir" do
    RPM.transaction do |ts|
      it "has default root directory \"/\"" do
        ts.root_dir.should eq("/")
      end
      it "has been set to root directory \"#{Dir.tempdir}\"" do
        ts.root_dir = Dir.tempdir
        ts.root_dir.should eq(Dir.tempdir + "/")
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

  Dir.mktmpdir do |tmproot|
    describe "Test install" do
      path = fixture("simple-1.0-0.i586.rpm")
      pkg = RPM::Package.open(path)
      it "#install-ed \"#{pkg[RPM::Tag::Name]}\"" do
        RPM.transaction(tmproot) do |ts|
          ts.install(pkg, path)
          ts.commit
        end
        test_path = File.join(tmproot, "usr/share/simple/README")
        File.exists?(test_path).should be_true
      end
    end

    describe "Test iterator" do
      a_installed_pkg = nil
      dir = tmproot

      describe "#init_iterator" do
        RPM.transaction do |ts|
          iter = ts.init_iterator
          it "returns MatchIterator" do
            iter.class.should eq(RPM::MatchIterator)
          end
        end

        # Base test
        it "looks for a package" do
          RPM.transaction(dir) do |ts|
            iter = ts.init_iterator
            a_installed_pkg = iter.first?
            a_installed_pkg.should_not be_nil
          end
        end

        it "looks for a package contains a file" do
          RPM.transaction(dir) do |ts|
            iter = ts.init_iterator
            iter.each do |x|
              if (has_files = x[RPM::Tag::BaseNames]).is_a?(Array(String))
                if has_files.size > 0
                  a_installed_pkg = x
                  break
                end
              end
            end
          end
        end

        # File name search test. (just an example)
        it "looks for packages contains a file" do
          files = a_installed_pkg.as(RPM::Package).files
          idx = Random.rand(files.size)
          path = files[idx].path
          RPM.transaction(dir) do |ts|
            iter = ts.init_iterator(RPM::DbiTag::BaseNames, path)
            n = 0
            iter.each do |pkg|
              pkg.files.any? { |file| file.path == path }.should be_true
              n += 1
            end
            n.should be > 0
          end
        end

        it "looks for package not found (by searching package '......')" do
          RPM.transaction(dir) do |ts|
            iter = ts.init_iterator(RPM::DbiTag::Name, "......")
            iter.to_a.should eq([] of RPM::Package)
          end
        end

        it "looks for package not found (by searching filename '/tmp/foo')" do
          RPM.transaction(dir) do |ts|
            iter = ts.init_iterator(RPM::DbiTag::BaseNames, "/tmp/foo")
            iter.to_a.should eq([] of RPM::Package)
          end
        end
      end

      describe "#db" do
        RPM.transaction do |ts|
          db = nil
          it "opens db" do
            db = ts.db
            db.should be_a(RPM::DB)
          end

          it "can generate iterator" do
            iter = db.as(RPM::DB).init_iterator(RPM::DbiTag::Name)
            a_pkg = iter.first
            a_pkg.should_not be_nil
          end
        end
      end

      describe "#version" do
        pkg = a_installed_pkg.as(RPM::Package)
        vers = pkg[RPM::Tag::Version].as(String)
        it "looks for packages whose version is \"#{vers}\"" do
          RPM.transaction(dir) do |ts|
            iter = ts.init_iterator
            iter.version(RPM::Version.new(vers))
            n = 0
            iter.each do |sig|
              n += 1
              sig[RPM::Tag::Version].should eq(vers)
            end
            n.should be > 0
          end
        end
      end

      describe "#regexp" do
        pkg = a_installed_pkg.as(RPM::Package)
        name = pkg[RPM::Tag::Name].as(String)
        patname = name[0..1]
        pat = patname + "*"
        it "looks for packages whose name matches \"#{pat}\"" do
          RPM.transaction(dir) do |ts|
            iter = ts.init_iterator
            iter.regexp(RPM::DbiTag::Name, RPM::MireMode::GLOB, pat)
            n = 0
            iter.each do |pkg|
              n += 1
              pkg[RPM::Tag::Name].as(String).should start_with(patname)
            end
            n.should be > 0
          end
        end

        files = pkg.files
        idx = Random.rand(files.size)
        basename = File.basename(files[idx].path)
        it "looks for packages which contain a file whose basename is \"#{basename}\"" do
          RPM.transaction(dir) do |ts|
            iter = ts.init_iterator
            iter.regexp(RPM::DbiTag::BaseNames, RPM::MireMode::STRCMP, basename)
            n = 0
            iter.each do |pkg|
              n += 1
              pkg.files.any? { |x| File.basename(x.path) == basename }.should be_true
            end
            n.should be > 0
          end
        end
      end
    end

    describe "Test callback" do
      path = fixture("simple-1.0-0.i586.rpm")
      pkg = RPM::Package.open(path)
      RPM.transaction(tmproot) do |ts|
        ts.install(pkg, path)
        types = [] of RPM::CallbackType
        ts.commit do |pkg, type|
          it "runs expectations in the block" do
            case type
            when RPM::CallbackType::TRANS_PROGRESS,
                 RPM::CallbackType::TRANS_START,
                 RPM::CallbackType::TRANS_STOP
              pkg.should be_nil
            else
              # other values are ignored.
            end
          end
          types << type
          nil
        end
        it "collects transaction callback types" do
          types[-3..-1].should eq([RPM::CallbackType::TRANS_START,
                                   RPM::CallbackType::TRANS_PROGRESS,
                                   RPM::CallbackType::TRANS_STOP])
        end
      end
    end

    describe "Test problem" do
      path = fixture("simple-1.0-0.i586.rpm")
      pkg = RPM::Package.open(path)
      RPM.transaction(tmproot) do |ts|
        ts.install(pkg, path)
        ts.order
        ts.clean
        it "rejects installation" do
          ts.commit.should_not eq(0)
        end

        it "collects problems" do
          probs = RPM::ProblemSet.new(ts)
          prob = probs.each.find do |prob|
            prob.to_s == "package simple-1.0-0.i586 is already installed"
          end
          prob.should_not be_nil
        end
      end
    end

    describe "Test remove" do
      # TODO: RPM in OpenSUSE works with this semantic, but not in
      # others. This must be investigated...
      pending "#remove-ed properly" do
        RPM.transaction(tmproot) do |ts|
          iter = ts.init_iterator(RPM::DbiTag::Name, "simple")
          removed = [] of RPM::Package
          iter.each do |pkg|
            if pkg[RPM::Tag::Version].as(String) == "1.0" &&
               pkg[RPM::Tag::Release].as(String) == "0" &&
               pkg[RPM::Tag::Arch].as(String) == "i586"
              ts.delete(pkg)
              removed << pkg
            end
          end
          raise Exception.new("No packages found to remove!") if removed.empty?

          ts.order

          probs = ts.check
          bad = false
          probs.each do |prob|
            bad = true
            STDERR.puts prob.to_s
          end
          raise Exception.new("Transaction has problem") if bad

          ts.clean
          ts.commit
        end
        test_path = File.join(tmproot, "usr/share/simple/README")
        File.exists?(test_path).should be_false
      end
    end
  end
end

describe RPM::Version do
  a = RPM::Version.new("1.0.0-0.1m")
  b = RPM::Version.new("0.9.0-1m")
  c = RPM::Version.new("1.0.0-0.11m")
  d = RPM::Version.new("0.9.0-1m", 1)

  describe ".parse_evr" do
    it "parses EVR format into Set of {Epoch, Version, Release}" do
      RPM::Version.parse_evr("23:1.0.3-1suse").should eq({23, "1.0.3", "1suse"})
      RPM::Version.parse_evr("1.0").should eq({nil, "1.0", nil})
      RPM::Version.parse_evr("2.0-3").should eq({nil, "2.0", "3"})
    end
  end

  describe "#<=>" do
    it "can compare as Comparable" do
      (a > b).should be_true
      (a < c).should be_true
      (a < d).should be_true
    end
  end

  describe "#newer?" do
    it "returns true if receiver is newer than given version" do
      a.newer?(b).should be_true
      c.newer?(a).should be_true
      d.newer?(a).should be_true
      a.newer?(a).should be_false
    end
  end

  describe "#older?" do
    it "returns true if receiver is older than given version" do
      b.older?(a).should be_true
      a.older?(c).should be_true
      a.older?(d).should be_true
      a.older?(a).should be_false
    end
  end

  describe "#v" do
    it "returns version part" do
      d.v.should eq("0.9.0")
    end
  end

  describe "#r" do
    it "returns release part" do
      d.r.should eq("1m")
    end
  end

  describe "#e" do
    it "returns epoch part" do
      d.e.should eq(1)
    end
  end

  describe "#to_s" do
    it "returns stringified Version and Relase" do
      b.to_s.should eq("0.9.0-1m")
      d.to_s.should eq("0.9.0-1m")
    end
  end

  describe "#to_vre" do
    it "returns stringified Version, Release and Epoch" do
      b.to_vre.should eq("0.9.0-1m")
      d.to_vre.should eq("1:0.9.0-1m")
    end
  end

  describe "zero-epoch and nil-epoch" do
    v1 = RPM::Version.new("1-2")
    v2 = RPM::Version.new("0:1-2")

    it "will be nil for nil-epoch" do
      v1.e.should be_nil
    end

    it "will be 0 for 0-epoch" do
      v2.e.should eq(0)
    end

    it "equals" do
      (v1 == v2).should be_true
      v1.should eq(v2)
    end

    it "equals their hash" do
      v1.hash.should eq(v2.hash)
    end
  end
end

describe RPM::Source do
  a = RPM::Source.new("http://example.com/hoge/hoge.tar.bz2", 0)
  b = RPM::Source.new("http://example.com/fuga/fuga.tar.gz", 1, true)

  describe "#fullname" do
    it "returns full source name" do
      a.fullname.should eq("http://example.com/hoge/hoge.tar.bz2")
    end
  end

  describe "#to_s" do
    it "returns full souce name" do
      a.fullname.should eq("http://example.com/hoge/hoge.tar.bz2")
    end
  end

  describe "#filename" do
    it "returns basename of the source" do
      a.filename.should eq("hoge.tar.bz2")
    end
  end

  describe "#number" do
    it "returns number assinged to source" do
      a.number.should eq(0)
      b.number.should eq(1)
    end
  end

  describe "#no?" do
    it "returns whether the source is packeged into src.rpm" do
      a.no?.should be_false
      b.no?.should be_true
    end
  end
end

describe RPM::Spec do
  sz_spec_s = CCheck.sizeof_spec_s
  case sz_spec_s
  when -1
    {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
      pending "sizeof rpmSpec_s (compilation error)" do
      end
    {% else %}
      it "sizeof rpmSpec_s (it's not public in rpm 4.9 or later)" do
        true.should be_true
      end
    {% end %}
  else
    it "sizeof rpmSpec_s" do
      sizeof(RPM::LibRPM::Spec_s).should eq(sz_spec_s)
    end
  end

  {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
    if sz_spec_s != -1
      it "offsetof members in rpmSpec_s" do
        RPM::LibRPM::Spec_s.offsetof(@spec_file).should eq(CCheck.offset_spec_s("specFile"))
        RPM::LibRPM::Spec_s.offsetof(@lbuf_ptr).should eq(CCheck.offset_spec_s("lbufPtr"))
        RPM::LibRPM::Spec_s.offsetof(@sources).should eq(CCheck.offset_spec_s("sources"))
        RPM::LibRPM::Spec_s.offsetof(@packages).should eq(CCheck.offset_spec_s("packages"))
      end
    else
      pending "offsetof members in rpmSpec_s (compilation error)" do
      end
    end
  {% end %}

  sz_pkg_s = CCheck.sizeof_package_s
  case sz_pkg_s
  when -1
    {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
      pending "sizeof Package_s (compilation error)" do
      end
    {% else %}
      it "sizeof Package_s (it's not public in rpm 4.9 or later)" do
        true.should be_true
      end
    {% end %}
  else
    it "sizeof Package_s" do
      sizeof(RPM::LibRPM::Package_s).should eq(sz_pkg_s)
    end
  end

  {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
    if sz_pkg_s != -1
      it "offsetof members in Package_s" do
        RPM::LibRPM::Package_s.offsetof(@header).should eq(CCheck.offset_package_s("header"))
        RPM::LibRPM::Package_s.offsetof(@next).should eq(CCheck.offset_package_s("next"))
      end
    else
      pending "offsetof members in Package_s (compilation error)" do
      end
    end
  {% end %}

  sz_bta_s = CCheck.sizeof_buildarguments_s
  case sz_bta_s
  when -1
    pending "sizoef BuildArguments_s (compilation error)" do
    end

    pending "offsetof members in BuildArguments_s (compilation error)" do
    end
  else
    it "sizeof BuildArguments_s" do
      sizeof(RPM::LibRPM::BuildArguments_s).should eq(sz_bta_s)
    end

    it "offsetof members in BuildArguments_s" do
      RPM::LibRPM::BuildArguments_s.offsetof(@rootdir).should eq(CCheck.offset_buildarguments_s("rootdir"))
      RPM::LibRPM::BuildArguments_s.offsetof(@build_amount).should eq(CCheck.offset_buildarguments_s("buildAmount"))

    end
  end

  describe "sample specfile" do
    spec = RPM::Spec.open(fixture("a.spec"))

    it "#buildroot" do
      buildroot = RPM["buildroot"]
      buildroot = buildroot.sub(/%{name}/i, "a")
      buildroot = buildroot.sub(/%{version}/i, "1.0")
      buildroot = buildroot.sub(/%{release}/i, "0")
      spec.buildroot.should eq(buildroot)
    end

    it "#packages" do
      pkgs = spec.packages
      pkgs.size.should eq(2)
      pkgs.any? { |x| x[RPM::Tag::Name] == "a" }.should be_true
      pkgs.any? { |x| x[RPM::Tag::Name] == "a-devel" }.should be_true
    end

    it "#sources" do
      srcs = spec.sources
      srcs.size.should eq(1)
      src = srcs.find { |x| x.fullname == "a-1.0.tar.gz" }
      src.class.should eq(RPM::Source)
      if src
        src.number.should eq(0)
        src.no?.should be_false
      end
    end

    it "#buildrequires" do
      reqs = spec.buildrequires
      reqs.any? { |x| x.name == "c" }.should be_true
      reqs.any? { |x| x.name == "d" }.should be_true
    end

    it "#buildconflicts" do
      cfts = spec.buildconflicts
      cfts.any? { |x| x.name == "e" }.should be_true
      cfts.any? { |x| x.name == "f" }.should be_true
    end
  end
end
