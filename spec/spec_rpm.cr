require "./spec_helper"
require "tempdir"

describe RPM do
  it "should be compiled with a same version to CLI" do
    # output may be localized.
    "RPM version #{RPM::PKGVERSION}".should eq(`env LC_ALL=C rpm --version`.chomp)
  end

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
  describe "#satisfies?" do
    it "returns true if dependencies satisfy" do
      eq = RPM::Sense.flags(EQUAL)
      ge = RPM::Sense.flags(EQUAL, GREATER)
      v1 = RPM::Version.new("2", "1")
      v2 = RPM::Version.new("1", "1")
      prv1 = RPM::Provide.new("foo", v1, eq, nil)
      req1 = RPM::Require.new("foo", v2, ge, nil)

      req1.satisfies?(prv1).should be_true
      prv1.satisfies?(req1).should be_true
    end

    it "returns false if name does not overlap" do
      eq = RPM::Sense.flags(EQUAL)
      ge = RPM::Sense.flags(EQUAL, GREATER)
      v2 = RPM::Version.new("1", "1")
      v3 = RPM::Version.new("2", "1")
      prv2 = RPM::Provide.new("foo", v3, eq, nil)
      req2 = RPM::Require.new("bar", v2, ge, nil)

      req2.satisfies?(prv2).should be_false
    end
  end
end

describe RPM::File do
  it "has flags" do
    time = {% if Time.class.methods.find { |x| x.name == "local" } %}
             Time.local(2019, 1, 1, 9, 0, 0)
           {% else %}
             Time.new(2019, 1, 1, 9, 0, 0)
           {% end %}
    f = RPM::File.new("path", "md5sum", "", 42_u32, time, "owner", "group",
      43_u16, 0o777_u16, RPM::FileAttrs.from_value(44_u32),
      RPM::FileState::NORMAL)

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
      tag = RPM::TagData.for(pkg.hdr, RPM::Tag::Arch)
      tag.size.should eq(1)
      tag[0].should eq("i586")

      tag = RPM::TagData.for(pkg, RPM::Tag::Name)
      tag.size.should eq(1)
      tag[0].should eq("simple")
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

    it "contains 2 files ownd by root" do
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

describe RPM::Problem do
  describe ".create-ed problem (RPM 4.9 style)" do
    it "has #key" do
      problem = RPM::Problem.new(RPM::ProblemType::REQUIRES, "foo-1.0-0", "foo.rpm", "bar-1.0-0", "Hello", 1)
      String.new(problem.key.as(Pointer(UInt8))).should eq("foo.rpm")
    end

    it "has #type" do
      problem = RPM::Problem.new(RPM::ProblemType::REQUIRES, "foo-1.0-0", "foo.rpm", "bar-1.0-0", "Hello", 1)
      problem.type.should eq(RPM::ProblemType::REQUIRES)
    end

    it "has string #str" do
      problem = RPM::Problem.new(RPM::ProblemType::REQUIRES, "foo-1.0-0", "foo.rpm", "bar-1.0-0", "Hello", 1)
      {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
        problem.str.should eq("foo-1.0-0")
      {% else %}
        problem.str.should eq("Hello")
      {% end %}
    end

    it "descriptive #to_s" do
      problem = RPM::Problem.new(RPM::ProblemType::REQUIRES, "foo-1.0-0", "foo.rpm", "bar-1.0-0", "Hello", 1)
      problem.to_s.should eq("Hello is needed by (installed) bar-1.0-0")
    end
  end

  describe ".create-ed problem (RPM 4.8 style)" do
    it "has #type" do
      problem = RPM::Problem.new(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "", "  Hello", 0)
      problem.type.should eq(RPM::ProblemType::REQUIRES)
    end

    it "has string #str" do
      problem = RPM::Problem.new(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "", "  Hello", 0)
      {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
        problem.str.should eq("")
      {% else %}
        problem.str.should eq("Hello")
      {% end %}
    end

    it "descriptive #to_s" do
      problem = RPM::Problem.new(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "", "  Hello", 0)
      problem.to_s.should eq("Hello is needed by (installed) bar-1.0-0")
    end
  end

  describe ".new from Existing pointer" do
    it "has same key" do
      problem = RPM::Problem.new(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "", "  Hello", 0)
      problem2 = RPM::Problem.new(problem.ptr)
      problem2.key.should eq(problem.key)
    end

    it "has same type" do
      problem = RPM::Problem.new(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "", "  Hello", 0)
      problem2 = RPM::Problem.new(problem.ptr)
      problem2.type.should eq(problem.type)
    end

    it "has same str" do
      problem = RPM::Problem.new(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "", "  Hello", 0)
      problem2 = RPM::Problem.new(problem.ptr)
      problem2.str.should eq(problem.str)
    end

    it "has same description" do
      problem = RPM::Problem.new(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "", "  Hello", 0)
      problem2 = RPM::Problem.new(problem.ptr)
      problem2.to_s.should eq(problem.to_s)
    end

    it "can duplicate" do
      problem = RPM::Problem.new(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "", "  Hello", 0)
      problem2 = RPM::Problem.new(problem.ptr)
      d = problem2.dup
      d.key.should eq(problem.key)
    end
  end
end

describe RPM::Transaction do
  describe "#root_dir" do
    it "has default root directory \"/\"" do
      RPM.transaction do |ts|
        ts.root_dir.should eq("/")
      end
    end
    it "can set to root directory" do
      # just setting rootdir does not require `chroot`.
      RPM.transaction do |ts|
        ts.root_dir = Dir.tempdir
        ts.root_dir.should eq(Dir.tempdir + "/")
      end
    end
  end

  describe "#flags" do
    it "has default transaction flag NONE" do
      RPM.transaction do |ts|
        ts.flags.should eq(RPM::TransactionFlags::NONE)
      end
    end

    it "can set tranaction flag to TEST" do
      RPM.transaction do |ts|
        ts.flags = RPM::TransactionFlags::TEST
        ts.flags.should eq(RPM::TransactionFlags::TEST)
      end
    end
  end

  describe "Test iterator" do
    describe "#init_iterator" do
      it "returns MatchIterator" do
        RPM.transaction do |ts|
          iter = ts.init_iterator
          begin
            if first = iter.first?
              first.name.should start_with("")
            end
            iter.class.should eq(RPM::MatchIterator)
          ensure
            iter.finalize
          end
        end
      end
    end

    describe "#db_iterator" do
      # Base test
      it "looks for a package" do
        a_installed_pkg = nil
        if (chroot = is_chroot_possible?)
          tmpdir = Dir.mktmpdir
          root = tmpdir.path
          install_simple(root: root)
        else
          root = "/"
        end
        RPM.transaction(root) do |ts|
          ts.db_iterator do |iter|
            a_installed_pkg = iter.first?
            if chroot
              a_installed_pkg.should_not be_nil
            end
          end
        end
        if a_installed_pkg.nil?
          ret = rpm("-qa", "-r", root)
          ret.not_nil!.chomp.should eq("") # nothing installed
        else
          name = a_installed_pkg[RPM::Tag::Name].as(String)
          version = a_installed_pkg[RPM::Tag::Version].as(String)
          release = a_installed_pkg[RPM::Tag::Release].as(String)
          arch = a_installed_pkg[RPM::Tag::Arch].as(String)
          nvra = "#{name}-#{version}-#{release}.#{arch}"
          rpm("-q", "-r", root, nvra).not_nil!.chomp.should eq(nvra)
        end
      ensure
        if tmpdir
          tmpdir.close
        end
      end

      if is_chroot_possible?
        it "looks for a package (while nothing installed)" do
          a_installed_pkg = nil
          tmpdir = Dir.mktmpdir
          root = tmpdir.path
          RPM.transaction(root) do |ts|
            ts.db_iterator do |iter|
              a_installed_pkg = iter.first?
              a_installed_pkg.should be_nil
            end
          end
        ensure
          if tmpdir
            tmpdir.close
          end
        end
      end

      it "looks for a package contains a file" do
        a_installed_pkg = nil
        RPM.transaction do |ts|
          ts.db_iterator do |iter|
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
        if a_installed_pkg.nil?
          rpm("-qal").should eq("\n") # no files installed by rpm.
        else
          name = a_installed_pkg[RPM::Tag::Name].as(String)
          version = a_installed_pkg[RPM::Tag::Version].as(String)
          release = a_installed_pkg[RPM::Tag::Release].as(String)
          arch = a_installed_pkg[RPM::Tag::Arch].as(String)
          files = rpm("-ql", "#{name}-#{version}-#{release}.#{arch}") do |prc|
            lines = Set(String).new
            while (l = prc.output.gets)
              lines << l
            end
            lines
          end
          a_installed_pkg.files.map(&.path).to_set.should eq(files)
        end
      end

      # File name search test. (just an example)
      it "looks for packages contains specfic file" do
        a_installed_pkg = nil
        if (chroot = is_chroot_possible?)
          tmpdir = Dir.mktmpdir
          root = tmpdir.path
          install_simple(root: root)
        else
          root = "/"
        end
        target_file = rpm("-qal", "-r", root) do |proc|
          line = proc.output.gets
          proc.output.close
          line ? line.chomp : nil
        end
        if target_file.nil? || target_file == ""
          raise "No package contains files (please run with fakechroot)"
        end
        RPM.transaction(root) do |ts|
          ts.db_iterator(RPM::DbiTag::BaseNames, target_file) do |iter|
            a_installed_pkg = iter.map { |x| x[RPM::Tag::Name].as(String) }
            a_installed_pkg.sort!
          end
        end
        a_installed_pkg.not_nil!
      ensure
        if tmpdir
          tmpdir.close
        end
      end

      it "looks for a package not found by name" do
        RPM.transaction do |ts|
          # NB: "......" is not valid RPM package name.
          ts.db_iterator(RPM::DbiTag::Name, "......") do |iter|
            iter.to_a.should eq([] of RPM::Package)
          end
        end
      end

      it "looks for a package not found by file" do
        Dir.mktmpdir do |tmpdir|
          ret = rpm("-qf", tmpdir, raise_on_failure: false, error: Process::Redirect::Close)
          $?.exit_code.should_not eq(0)
          RPM.transaction do |ts|
            ts.db_iterator(RPM::DbiTag::BaseNames, tmpdir) do |iter|
              iter.to_a.should eq([] of RPM::Package)
            end
          end
        end
      end
    end

    describe "#version" do
      it "looks for packages by version" do
        a_installed_pkg = nil
        if (chroot = is_chroot_possible?)
          tmpdir = Dir.mktmpdir
          root = tmpdir.path
          install_simple(root: root)
        else
          root = "/"
        end
        names, a_version = rpm("-qa", "-r", root, "--queryformat", "%{name}\\t%{epoch}\\t%{version}-%{release}\\t%{arch}\\n") do |prc|
          l = prc.output.gets
          if l
            a = l.split("\t")
            names = Set(Tuple(String, String)).new
            names << {a[0], a[3]}
            epoch = a[1]
            version = a[2]
            while (l = prc.output.gets)
              a = l.split("\t")
              if a[1] == epoch && a[2] == version
                names << {a[0], a[3]}
              end
            end
            if epoch == "(none)"
              evr = version
            else
              evr = epoch + ":" + version
            end
            {names, evr}
          else
            {nil, nil}
          end
        end
        names = names.not_nil!
        a_version = a_version.not_nil!

        RPM.transaction(root) do |ts|
          pkgs = Set(Tuple(String, String)).new
          ts.db_iterator do |iter|
            iter.version(RPM::Version.new(a_version))
            iter.each do |sig|
              pkgs << {sig.name, sig[RPM::Tag::Arch].as(String)}
            end
          end
          pkgs.should eq(names)
        end
      ensure
        if tmpdir
          tmpdir.close
        end
      end
    end

    describe "#regexp" do
      it "looks for packages whose name matches to a glob" do
        a_installed_pkg = nil
        if (chroot = is_chroot_possible?)
          tmpdir = Dir.mktmpdir
          root = tmpdir.path
          install_simple(root: root)
          install_simple(package: "simple_with_deps-1.0-0.i586.rpm", root: root)
        else
          root = "/"
        end
        basename = rpm("-qa", "-r", root, "--queryformat", "%{name}\\n") do |prc|
          l = prc.output.gets
          prc.output.close
          l
        end
        if !basename
          raise "No packages installed (and not allowed to do chroot)"
        end

        # We want a pattern which matches with 2 or more packages.
        reference = nil
        pattern = nil
        (1...basename.size).to_a.bsearch do |i|
          pattern = basename[0..i] + "*"
          reference = rpm("-qa", "-r", root, pattern, "--queryformat", "%{name}\\t%{epoch}\\t%{version}\\t%{release}\\t%{arch}\\n") do |prc|
            names = Set(Tuple(String, String, String, UInt32?, String)).new
            while (l = prc.output.gets)
              a = l.split("\t")
              name = a[0]
              epoch = a[1]
              version = a[2]
              release = a[3]
              arch = a[4]
              if epoch == "(none)"
                e = nil
              else
                e = epoch.to_u32
              end
              names << {name, version, release, e, arch}
            end
            names
          end
          SPEC_DEBUG_LOG.debug {
            "#regexp refenrece pattern \"#{pattern}\", count: #{reference.size}"
          }
          if reference.size <= 1
            true
          else
            break
          end
        end
        reference = reference.not_nil!
        pattern = pattern.not_nil!

        RPM.transaction(root) do |ts|
          ts.db_iterator do |iter|
            iter.regexp(RPM::DbiTag::Name, RPM::MireMode::GLOB, pattern)
            pkgs = Set(Tuple(String, String, String, UInt32?, String)).new
            iter.each do |pkg|
              n = pkg.name
              v = pkg[RPM::Tag::Version].as(String)
              r = pkg[RPM::Tag::Release].as(String)
              e = pkg[RPM::Tag::Epoch].as(UInt32 | Nil)
              a = pkg[RPM::Tag::Arch].as(String)
              tup = {n, v, r, e, a}
              pkgs << tup
            end
            pkgs.should eq(reference)
          end
        end
      ensure
        if tmpdir
          tmpdir.close
        end
      end
    end
  end

  describe "#install" do
    it "installs simple package" do
      # RPM 4.8 has a bug that root directory is not set properly.
      # So we need to run in fresh environment.
      Dir.mktmpdir do |tmproot|
        path = fixture("simple-1.0-0.i586.rpm")
        stat = run_in_subproc(path, tmproot) do
          path = ARGV[0]
          tmproot = ARGV[1]
          pkg = RPM::Package.open(path)
          RPM.transaction(tmproot) do |ts|
            ts.install(pkg, path)
            ts.commit
          end
        end
        stat.exit_code.should eq(0)
        test_path = File.join(tmproot, "usr/share/simple/README")
        File.exists?(test_path).should be_true
      end
    end
  end

  describe "#callback" do
    it "runs expectations in the block" do
      # RPM 4.8 has a bug that root directory is not set properly.
      # So we need to run in fresh environment.
      path = fixture("simple-1.0-0.i586.rpm")
      Dir.mktmpdir do |tmproot|
        r, w = IO.pipe
        stat = run_in_subproc(path, tmproot, output: w) do
          pkg = RPM::Package.open(path)
          pstat = true
          RPM.transaction(tmproot) do |ts|
            ts.install(pkg, path)
            types = [] of RPM::CallbackType
            ts.commit do |pkg, type|
              case type
              when RPM::CallbackType::TRANS_PROGRESS,
                   RPM::CallbackType::TRANS_START,
                   RPM::CallbackType::TRANS_STOP
                if !pkg.nil?
                  pstat = false
                end
              else
                # other values are ignored.
              end
              types << type
              nil
            end

            types.each do |t|
              puts t
            end
          end
          exit pstat ? 0 : 1
        end
        w.close
        arr = [] of String
        while (output = r.gets(chomp: true))
          arr << output
        end
        r.close
        stat.exit_code.should eq(0)
        # We think the number of INST_PROGRESS's is not constant.
        expect =
          {% begin %}
            [
            {% if compare_versions(RPM::PKGVERSION_COMP, "4.14.2") >= 0 %}
              "VERIFY_START", "VERIFY_PROGRESS", "INST_OPEN_FILE",
              "INST_CLOSE_FILE", "VERIFY_STOP",
            {% end %}
              "TRANS_START", "TRANS_PROGRESS", "TRANS_STOP",
            {% if compare_versions(RPM::PKGVERSION_COMP, "4.13.0") == 0 %}
              "ELEM_PROGRESS",
            {% end %}
              "INST_OPEN_FILE",
            {% if (compare_versions(RPM::PKGVERSION_COMP, "4.9.0") >= 0 &&
                    compare_versions(RPM::PKGVERSION_COMP, "4.12.0") < 0) ||
                    (compare_versions(RPM::PKGVERSION_COMP, "4.13.1") >= 0) %}
              # I'm not sure why fc22 (4.12.0) does not evaluate this.
              "ELEM_PROGRESS",
            {% end %}
              "INST_START", "INST_PROGRESS",  "INST_PROGRESS",  "INST_PROGRESS",
            {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") >= 0 %}
              "INST_PROGRESS", "INST_STOP",
            {% end %}
              "INST_CLOSE_FILE",
            ]
          {% end %}
        arr.should eq(expect)
        test_path = File.join(tmproot, "usr/share/simple/README")
        File.exists?(test_path).should be_true
      end
    end
  end

  describe "#check" do
    it "collects problems" do
      # RPM 4.8 has a bug that root directory is not set properly.
      # So we need to run in fresh environment.
      file = "simple_with_deps-1.0-0.i586.rpm"
      path = fixture(file)
      r, w = IO.pipe
      stat = run_in_subproc(path, error: Process::Redirect::Inherit, output: w) do
        ENV["LC_ALL"] = "C"
        pkg = RPM::Package.open(path)
        RPM.transaction do |ts|
          ts.install(pkg, path)
          ts.check
          if (check_probs = ts.problems?)
            check_probs.each { |x| puts x.to_s }
          end
        end
        exit 0
      end
      w.close
      lines = [] of String
      while (l = r.gets(chomp: true))
        lines << l
      end
      r.close
      stat.exit_code.should eq(0)
      expected = [
        "a is needed by simple_with_deps-1.0-0.i586",
        "b > 1.0 is needed by simple_with_deps-1.0-0.i586",
      ]
      lines.sort.should eq(expected)
    end
  end

  describe "#delete" do
    # RPM 4.8 has a bug that root directory is not set properly.
    # So we need to run in fresh environment.
    it "removes a pacakge" do
      Dir.mktmpdir do |tmproot|
        install_simple(root: tmproot)
        install_simple(package: "simple_with_deps-1.0-0.i586.rpm", root: tmproot)
        stat = run_in_subproc(tmproot) do
          RPM.transaction(tmproot) do |ts|
            removed = [] of RPM::Package
            ts.db_iterator(RPM::DbiTag::Name, "simple") do |iter|
              iter.each do |pkg|
                if pkg[RPM::Tag::Version].as(String) == "1.0" &&
                   pkg[RPM::Tag::Release].as(String) == "0" &&
                   pkg[RPM::Tag::Arch].as(String) == "i586"
                  ts.delete(pkg)
                  removed << pkg
                end
              end
            end
            if removed.empty?
              raise Exception.new("No packages found to remove!")
            end

            ts.order
            ts.check
            if (probs = ts.problems?)
              probs.each do |prob|
                STDERR.puts prob.to_s
              end
              raise Exception.new("Transaction has problem")
            end

            ts.clean
            ts.commit
          end
        end
        stat.exit_code.should eq(0)
        test_path = File.join(tmproot, "usr/share/simple/README")
        File.exists?(test_path).should be_false
      end
    end
  end

  describe "#each" do
    it "returns iterator of install/remove elements" do
      RPM.transaction do |ts|
        simple1 = fixture("simple-1.0-0.i586.rpm")
        simple2 = fixture("simple_with_deps-1.0-0.i586.rpm")
        ts.install(ts.read_package_file(simple1), simple1)
        ts.install(ts.read_package_file(simple2), simple2)
        iter = ts.each
        map = iter.map(&.name).to_a
        map.should eq(["simple", "simple_with_deps"])
      end
    end

    it "returns iterator of install elements" do
      RPM.transaction do |ts|
        simple1 = fixture("simple-1.0-0.i586.rpm")
        ts.install(ts.read_package_file(simple1), simple1)
        dbiter = ts.init_iterator(RPM::DbiTag::Packages, nil)
        begin
          remp = dbiter.first?
          if remp
            ts.delete(remp)
          end
        ensure
          dbiter.finalize
        end
        iter = ts.each(RPM::ElementTypes::ADDED)
        map = iter.map(&.name).to_a
        map.should eq(["simple"])
      end
    end

    it "returns iterator of deleted elements" do
      RPM.transaction do |ts|
        simple1 = fixture("simple-1.0-0.i586.rpm")
        ts.install(ts.read_package_file(simple1), simple1)
        dbiter = ts.init_iterator(RPM::DbiTag::Packages, nil)
        remp = nil
        begin
          remp = dbiter.first?
          if remp
            ts.delete(remp)
          end
        ensure
          dbiter.finalize
        end
        iter = ts.each(RPM::ElementTypes::REMOVED)
        map = iter.map(&.name).to_a
        if remp
          map.should eq([remp.name])
        else
          map.should eq([] of String)
        end
      end
    end

    it "iterates over elements" do
      RPM.transaction do |ts|
        simple1 = fixture("simple-1.0-0.i586.rpm")
        simple2 = fixture("simple_with_deps-1.0-0.i586.rpm")

        ts.install(ts.read_package_file(simple1), simple1)
        ts.install(ts.read_package_file(simple2), simple2)
        arr = [] of String
        ts.each do |el|
          arr << el.name
        end
        arr.should eq(["simple", "simple_with_deps"])
      end
    end
  end

  describe RPM::Transaction::Element do
    describe "#type" do
      it "returns ADDED for installing element" do
        RPM.transaction do |ts|
          simple1 = fixture("simple-1.0-0.i586.rpm")
          ts.install(ts.read_package_file(simple1), simple1)
          ts.each do |el|
            el.type.should eq(RPM::ElementType::ADDED)
          end
        end
      end

      it "returns REMOVED for removing element" do
        RPM.transaction do |ts|
          pkg = ts.db_iterator do |iter|
            iter.first?
          end
          if pkg.nil?
            raise "No packages installed!"
          end
          ts.delete(pkg)
          ts.each do |el|
            el.type.should eq(RPM::ElementType::REMOVED)
          end
        end
      end
    end

    describe "#epoch" do
      it "returns nil for no epoch package" do
        RPM.transaction do |ts|
          simple1 = fixture("simple-1.0-0.i586.rpm")
          ts.install(ts.read_package_file(simple1), simple1)
          ts.each do |el|
            el.epoch.should be_nil
          end
        end
      end

      it "returns a epoch" do
        RPM.transaction do |ts|
          simple1 = fixture("simple_with_epoch-1.0-0.noarch.rpm")
          pkg = ts.read_package_file(simple1)
          ts.install(pkg, simple1)

          ts.each do |el|
            el.epoch.should eq("11")
          end
        end
      end
    end

    describe "#version" do
      it "returns version string installed or removed" do
        RPM.transaction do |ts|
          simple1 = fixture("simple-1.0-0.i586.rpm")
          ts.install(ts.read_package_file(simple1), simple1)
          ts.each do |el|
            el.version.should eq("1.0")
          end
        end
      end
    end

    describe "#release" do
      it "returns release string installed or removed" do
        RPM.transaction do |ts|
          simple1 = fixture("simple-1.0-0.i586.rpm")
          ts.install(ts.read_package_file(simple1), simple1)
          ts.each do |el|
            el.release.should eq("0")
          end
        end
      end
    end

    describe "#arch" do
      it "returns arch string installed or moved" do
        RPM.transaction do |ts|
          simple1 = fixture("simple-1.0-0.i586.rpm")
          ts.install(ts.read_package_file(simple1), simple1)
          ts.each do |el|
            el.arch.should eq("i586")
          end
        end
      end
    end

    describe "#key" do
      it "returns key string installed or moved" do
        RPM.transaction do |ts|
          simple1 = fixture("simple-1.0-0.i586.rpm")
          ts.install(ts.read_package_file(simple1), "sample_key")
          ts.each do |el|
            el.key.should eq("sample_key")
          end
        end
      end

      pending "returns nil for NULL key" do
        crystal_rpm_does_not_allow_setting_nil_for_the_key = true
        crystal_rpm_does_not_allow_setting_nil_for_the_key.should be_true
      end
    end

    describe "#is_source?" do
      it "returns false if binary package" do
        RPM.transaction do |ts|
          simple1 = fixture("simple-1.0-0.i586.rpm")
          ts.install(ts.read_package_file(simple1), simple1)
          ts.each do |el|
            el.is_source?.should be_false
          end
        end
      end

      it "returns true if source package" do
        RPM.transaction do |ts|
          simple1 = fixture("simple-1.0-0.src.rpm")
          ts.install(ts.read_package_file(simple1), simple1)
          ts.each do |el|
            el.is_source?.should be_true
          end
        end
      end
    end

    describe "#package_file_size" do
      it "returns the size of pacage" do
        RPM.transaction do |ts|
          simple1 = fixture("simple-1.0-0.i586.rpm")
          ts.install(ts.read_package_file(simple1), simple1)
          ts.each do |el|
            el.package_file_size.should eq(RPM::LibRPM::Loff.new(2249))
          end
        end
      end
    end

    describe "#problems" do
      # The function does not exist in RPM 4.8.
      it "returns install problems" do
        simple1 = fixture("simple_with_deps-1.0-0.i586.rpm")
        simple2 = fixture("simple-1.0-0.i586.rpm")
        r, w = IO.pipe
        ret = run_in_subproc(simple1, simple2, env: {"LC_ALL" => "C"}, error: w) do
          RPM.transaction do |ts|
            ts.install(ts.read_package_file(simple1), simple1)
            ts.install(ts.read_package_file(simple2), simple2)
            ts.check
            ts.each do |el|
              probs = el.problems
              if probs
                str = String.build do |str|
                  str << el.name << ":\n"
                  probs.each do |prob|
                    str << "- " << prob.to_s << "\n"
                  end
                end
                STDERR.print str
              end
            end
          end
          exit 0
        end
        w.close
        lines = [] of String
        while line = r.gets(chomp: true)
          lines << line
        end
        r.close
        {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
          ret.exit_code.should_not eq(0)
          # We do not assume the message of ld.
          lines.each do |l|
            SPEC_DEBUG_LOG.debug do
              String.build do |s|
                s << "TransactionError#problems: " << l
              end
            end
          end
        {% else %}
          ret.exit_code.should eq(0)
          expected = [
            "simple_with_deps:",
            "- a is needed by simple_with_deps-1.0-0.i586",
            "- b > 1.0 is needed by simple_with_deps-1.0-0.i586",
          ]
          lines.should eq(expected)
        {% end %}
      end
    end
  end
end

describe RPM::Version do
  describe ".parse_evr" do
    it "parses EVR format into Set of {Epoch, Version, Release}" do
      RPM::Version.parse_evr("23:1.0.3-1suse").should eq({23, "1.0.3", "1suse"})
      RPM::Version.parse_evr("1.0").should eq({nil, "1.0", nil})
      RPM::Version.parse_evr("2.0-3").should eq({nil, "2.0", "3"})
    end
  end

  describe "#<=>" do
    it "can compare as Comparable" do
      a = RPM::Version.new("1.0.0-0.1m")
      b = RPM::Version.new("0.9.0-1m")
      c = RPM::Version.new("1.0.0-0.11m")
      d = RPM::Version.new("0.9.0-1m", 1)

      (a > b).should be_true
      (a < c).should be_true
      (a < d).should be_true
    end
  end

  describe "#newer?" do
    it "returns true if receiver is newer than given version" do
      a = RPM::Version.new("1.0.0-0.1m")
      b = RPM::Version.new("0.9.0-1m")
      c = RPM::Version.new("1.0.0-0.11m")
      d = RPM::Version.new("0.9.0-1m", 1)

      a.newer?(b).should be_true
      c.newer?(a).should be_true
      d.newer?(a).should be_true
      a.newer?(a).should be_false
    end
  end

  describe "#older?" do
    it "returns true if receiver is older than given version" do
      a = RPM::Version.new("1.0.0-0.1m")
      b = RPM::Version.new("0.9.0-1m")
      c = RPM::Version.new("1.0.0-0.11m")
      d = RPM::Version.new("0.9.0-1m", 1)

      b.older?(a).should be_true
      a.older?(c).should be_true
      a.older?(d).should be_true
      a.older?(a).should be_false
    end
  end

  describe "#v" do
    it "returns version part" do
      d = RPM::Version.new("0.9.0-1m", 1)
      d.v.should eq("0.9.0")
    end
  end

  describe "#r" do
    it "returns release part" do
      d = RPM::Version.new("0.9.0-1m", 1)
      d.r.should eq("1m")
    end
  end

  describe "#e" do
    it "returns epoch part" do
      d = RPM::Version.new("0.9.0-1m", 1)
      d.e.should eq(1)
    end
  end

  describe "#to_s" do
    it "returns stringified Version and Relase" do
      b = RPM::Version.new("0.9.0-1m")
      b.to_s.should eq("0.9.0-1m")

      d = RPM::Version.new("0.9.0-1m", 1)
      d.to_s.should eq("0.9.0-1m")
    end
  end

  describe "#to_vre" do
    it "returns stringified Version, Release and Epoch" do
      b = RPM::Version.new("0.9.0-1m")
      b.to_vre.should eq("0.9.0-1m")

      d = RPM::Version.new("0.9.0-1m", 1)
      d.to_vre.should eq("1:0.9.0-1m")
    end
  end

  describe "zero-epoch and nil-epoch" do
    it "will be nil for nil-epoch" do
      v1 = RPM::Version.new("1-2")
      v1.e.should be_nil
    end

    it "will be 0 for 0-epoch" do
      v2 = RPM::Version.new("0:1-2")
      v2.e.should eq(0)
    end

    it "equals" do
      v1 = RPM::Version.new("1-2")
      v2 = RPM::Version.new("0:1-2")

      (v1 == v2).should be_true
      v1.should eq(v2)
    end

    it "equals their hash" do
      v1 = RPM::Version.new("1-2")
      v2 = RPM::Version.new("0:1-2")

      v1.hash.should eq(v2.hash)
    end
  end
end

describe RPM::Source do
  describe "#fullname" do
    it "returns full source name" do
      a = RPM::Source.new("http://example.com/hoge/hoge.tar.bz2", 0)
      a.fullname.should eq("http://example.com/hoge/hoge.tar.bz2")
    end
  end

  describe "#to_s" do
    it "returns full souce name" do
      a = RPM::Source.new("http://example.com/hoge/hoge.tar.bz2", 0)
      a.fullname.should eq("http://example.com/hoge/hoge.tar.bz2")
    end
  end

  describe "#filename" do
    it "returns basename of the source" do
      a = RPM::Source.new("http://example.com/hoge/hoge.tar.bz2", 0)
      a.filename.should eq("hoge.tar.bz2")
    end
  end

  describe "#number" do
    it "returns number assinged to source" do
      a = RPM::Source.new("http://example.com/hoge/hoge.tar.bz2", 0)
      b = RPM::Source.new("http://example.com/fuga/fuga.tar.gz", 1, true)

      a.number.should eq(0)
      b.number.should eq(1)
    end
  end

  describe "#no?" do
    it "returns whether the source is packeged into src.rpm" do
      a = RPM::Source.new("http://example.com/hoge/hoge.tar.bz2", 0)
      b = RPM::Source.new("http://example.com/fuga/fuga.tar.gz", 1, true)

      a.no?.should be_false
      b.no?.should be_true
    end
  end
end

describe RPM::Spec do
  it "sizeof rpmSpec_s" do
    sz_spec_s = CCheck.sizeof_spec_s
    case sz_spec_s
    when -1
      {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
        raise "compilation failed"
      {% else %}
        # Nothing can be checked.
      {% end %}
    else
      sizeof(RPM::LibRPM::Spec_s).should eq(sz_spec_s)
      offsetof(RPM::LibRPM::Spec_s, @spec_file).should eq(CCheck.offset_spec_s("specFile"))
      offsetof(RPM::LibRPM::Spec_s, @lbuf_ptr).should eq(CCheck.offset_spec_s("lbufPtr"))
      offsetof(RPM::LibRPM::Spec_s, @sources).should eq(CCheck.offset_spec_s("sources"))
      offsetof(RPM::LibRPM::Spec_s, @packages).should eq(CCheck.offset_spec_s("packages"))
    end
  end

  it "sizeof Package_s" do
    sz_pkg_s = CCheck.sizeof_package_s
    case sz_pkg_s
    when -1
      {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
        raise "compilation failed"
      {% else %}
        # Nothing can be checked.
      {% end %}
    else
      sizeof(RPM::LibRPM::Package_s).should eq(sz_pkg_s)
      offsetof(RPM::LibRPM::Package_s, @header).should eq(CCheck.offset_package_s("header"))
      offsetof(RPM::LibRPM::Package_s, @next).should eq(CCheck.offset_package_s("next"))
    end
  end

  it "sizeof BuildArguments_s" do
    sz_bta_s = CCheck.sizeof_buildarguments_s
    case sz_bta_s
    when -1
      raise "compilation failed"
    else
      sizeof(RPM::LibRPM::BuildArguments_s).should eq(sz_bta_s)
      offsetof(RPM::LibRPM::BuildArguments_s, @rootdir).should eq(CCheck.offset_buildarguments_s("rootdir"))
      offsetof(RPM::LibRPM::BuildArguments_s, @build_amount).should eq(CCheck.offset_buildarguments_s("buildAmount"))
    end
  end

  describe "#buildroot" do
    it "reflects %{buildroot}" do
      buildroot = "/buildroot"
      RPM["buildroot"] = buildroot
      spec = RPM::Spec.open(fixture("a.spec"))
      spec.buildroot.should eq(buildroot)
    end
  end

  describe "#package" do
    it "returns packages defined in the specfile" do
      spec = RPM::Spec.open(fixture("a.spec"))
      pkgs = spec.packages
      pkg_names = pkgs.map { |x| x[RPM::Tag::Name].as(String) }
      pkg_names.sort.should eq(["a", "a-devel"])
    end
  end

  describe "#sources" do
    it "returns sources defined in the specfile" do
      spec = RPM::Spec.open(fixture("a.spec"))
      srcs = spec.sources
      srcs.sort_by! { |x| x.number }
      sources = srcs.map { |x| {x.number, x.fullname, x.no?} }
      sources.should eq([{0, "a-1.0.tar.gz", false}])
    end
  end

  describe "#buildrequires" do
    it "#buildrequires" do
      spec = RPM::Spec.open(fixture("a.spec"))
      reqs = spec.buildrequires
      reqs.any? { |x| x.name == "c" }.should be_true
      reqs.any? { |x| x.name == "d" }.should be_true
    end
  end

  describe "#buildconflicts" do
    it "#buildconflicts" do
      spec = RPM::Spec.open(fixture("a.spec"))
      cfts = spec.buildconflicts
      cfts.any? { |x| x.name == "e" }.should be_true
      cfts.any? { |x| x.name == "f" }.should be_true
    end
  end

  describe "#build" do
    it "can build a package successfully" do
      # Use fresh environment for build a spec.
      Dir.mktmpdir do |tmpdir|
        specfile = fixture("simple.spec")
        stat = run_in_subproc(specfile, tmpdir) do
          rootdir = "/"
          homedir = File.join(tmpdir, "home")
          rpmbuild = File.join(homedir, "rpmbuild")
          buildroot = File.join(tmpdir, "buildroot")

          ENV["HOME"] = homedir
          Dir.mkdir_p(rpmbuild)
          Dir.cd(rpmbuild) do
            %w[BUILD RPMS SRPMS BUILDROOT SPECS].each do |d|
              Dir.mkdir_p(d)
            end
          end
          # Re-evaluate rpm macros.
          RPM.read_config_files
          spec = RPM::Spec.open(specfile, buildroot: buildroot, rootdir: nil)
          amount = RPM::BuildFlags.flags(PREP, BUILD, INSTALL, CLEAN,
            PACKAGESOURCE, PACKAGEBINARY, RMSOURCE, RMBUILD)
          ret = spec.build(build_amount: amount)
          exit (ret ? 0 : 1)
        end
        stat.exit_code.should eq(0)
      end
    end
  end
end

describe "Files" do
  {% if flag?("do_openfile_test") %}
    it "should not be opened" do
      pid = Process.pid
      path = "/proc/#{pid}/fd"
      dbpath = RPM["_dbpath"]
      cwd = File.dirname(__FILE__)
      system("ls", ["-l", path])
      Dir.open(path) do |dir|
        dir.each do |x|
          fp = File.join(path, x)
          begin
            info = File.info(fp, follow_symlinks: false)
            next unless info.symlink?
            tg = File.real_path(fp)
          rescue e : Errno
            STDERR.puts e.to_s
            STDERR.flush
            next
          end
          if tg.starts_with?(dbpath) || tg.starts_with?(cwd)
            raise "All DB or file should be closed: '#{tg}' is opened."
          end
        end
      end
    rescue e : Errno
      if e.errno != Errno::ENOENT
        raise e
      else
        STDERR.puts "/proc filesystem not found or not mounted. Skipping open-files check"
      end
    end
  {% else %}
    pending "should not be opened (Add `-Ddo_openfile_test` to run)"
  {% end %}
end
