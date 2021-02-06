require "../spec_helper"
require "tempdir"

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

  describe "#read_package_file" do
    it "can read a package" do
      RPM.transaction do |ts|
        pkg = ts.read_package_file(fixture("simple-1.0-0.noarch.rpm"))
      end
    end

    it "raises file error" do
      RPM.transaction do |ts|
        # We are not expected a specific message.
        expect_raises(Exception) do
          ts.read_package_file(fixture("non-existent-file"))
        end
      end
    end

    it "raises TransactionError for reading package" do
      RPM.transaction do |ts|
        path = fixture("broken-rpm-1-0.i586.rpm")
        expect_raises(RPM::TransactionError, "Failed to read package: #{path}: not found") do
          ts.read_package_file(path)
        end
      end

      RPM.transaction do |ts|
        path = fixture("broken-rpm-2-0.i586.rpm")
        expect_raises(RPM::TransactionError, "Failed to read package: #{path}: failed") do
          ts.read_package_file(path)
        end
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
              has_files = x[RPM::Tag::BaseNames]?
              if has_files && has_files.is_a?(Array(String))
                if has_files.size > 0
                  a_installed_pkg = x
                  break
                end
              end
            end
          end
        end
        if a_installed_pkg.nil?
          (rpm("-qal") || [1]).should be_empty # no files installed by rpm.
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
          {% if flag?("debug_transaction_pattern") %}
            STDERR.puts "#regexp refenrece pattern \"#{pattern}\", count: #{reference.size}"
          {% end %}
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
              e = pkg[RPM::Tag::Epoch]?.as(UInt32?)
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
      rescue e : Exception
        if e.message != "No packages installed!"
          raise e
        end
        Dir.mktmpdir do |tmproot|
          install_simple(root: tmproot)
          RPM.transaction(tmproot) do |ts|
            pkg = ts.db_iterator do |iter|
              iter.first?
            end
            pkg.should_not be_nil
            ts.delete(pkg.not_nil!)
            ts.each do |el|
              el.type.should eq(RPM::ElementType::REMOVED)
            end
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
          {% if flag?("debug_transaction_problem") %}
            lines.each do |l|
              STDERR.puts "TransactionError#problems: #{l}"
            end
          {% end %}
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
