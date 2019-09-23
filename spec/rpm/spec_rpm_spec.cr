require "../spec_helper"
require "tempdir"

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
