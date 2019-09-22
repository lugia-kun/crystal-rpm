require "../spec_helper"
require "tempdir"

describe RPM::Problem do
  describe ".create" do
    it "can create Problem with RPM 4.9 style arguments list" do
      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "foo-1.0-0", "foo.rpm", "bar-1.0-0", "Hello", 1)
      problem.should_not be_nil
    end

    it "can create Problem with RPM 4.8 style arguments list" do
      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "", "  Hello", 0)
      problem.should_not be_nil
    end

    it "generates instance of subclass if available" do
      problem = RPM::Problem.create(RPM::ProblemType::BADARCH, "", "", "", "", 0)
      problem.class.should eq(RPM::Problem::BadArch)

      problem = RPM::Problem.create(RPM::ProblemType::BADOS, "", "", "", "", 0)
      problem.class.should eq(RPM::Problem::BadOS)

      problem = RPM::Problem.create(RPM::ProblemType::PKG_INSTALLED, "", "", "", "", 0)
      problem.class.should eq(RPM::Problem::PackageInstalled)

      problem = RPM::Problem.create(RPM::ProblemType::BADRELOCATE, "", "", "", "", 0)
      problem.class.should eq(RPM::Problem::BadRelocate)

      problem = RPM::Problem.create(RPM::ProblemType::NEW_FILE_CONFLICT, "", "", "", "", 0)
      problem.class.should eq(RPM::Problem::NewFileConflict)

      problem = RPM::Problem.create(RPM::ProblemType::FILE_CONFLICT, "", "", "", "", 0)
      problem.class.should eq(RPM::Problem::FileConflict)

      problem = RPM::Problem.create(RPM::ProblemType::OLDPACKAGE, "", "", "", "", 0)
      problem.class.should eq(RPM::Problem::OldPackage)

      problem = RPM::Problem.create(RPM::ProblemType::DISKSPACE, "", "", "", "", 0)
      problem.class.should eq(RPM::Problem::DiskSpace)

      problem = RPM::Problem.create(RPM::ProblemType::DISKNODES, "", "", "", "", 0)
      problem.class.should eq(RPM::Problem::DiskNodes)

      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "", "", "", "", 0)
      problem.class.should eq(RPM::Problem::Requires)

      problem = RPM::Problem.create(RPM::ProblemType::CONFLICT, "", "", "", "", 0)
      problem.class.should eq(RPM::Problem::Conflict)

      problem = RPM::Problem.create(RPM::ProblemType::OBSOLETES, "", "", "", "", 0)
      problem.class.should eq(RPM::Problem::Obsoletes)

      problem = RPM::Problem.create(RPM::ProblemType::VERIFY, "", "", "", "", 0)
      problem.class.should eq(RPM::Problem::Verify)
    end

    pending "returns the instance of Problem if proper subclass not available" do
      # Crystal does not allow to generate enum value of not available
      problem = RPM::Problem.create(RPM::ProblemType.from_value(-1), "", "", "", "", 0)
      problem.class.should eq(RPM::Problem)
    end
  end

  describe "#type" do
    it "returns type of RPM problem" do
      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", "bar-1.0-0", "Hello", 1)
      problem.type.should eq(RPM::ProblemType::REQUIRES)

      problem = RPM::Problem.create(RPM::ProblemType::BADARCH, "bar-1.0-0", "foo.rpm", nil, "m68k", 0)
      problem.type.should eq(RPM::ProblemType::BADARCH)
    end
  end

  describe "#key" do
    it "returns key value of RPM problem" do
      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", "bar-1.0-0", "Hello", 1)
      String.new(problem.key.as(Pointer(UInt8))).should eq("foo.rpm")

      problem = RPM::Problem.create(RPM::ProblemType::BADARCH, "bar-1.0-0", "", nil, "m68k", 0)
      String.new(problem.key.as(Pointer(UInt8))).should eq("")
    end
  end

  describe "#pkg_nevr" do
    it "returns `PkgNEVR` data of RPM problem" do
      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "foo-1.0-0", "foo.rpm", "bar-1.0-0", "Hello", 1)
      {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
        problem.pkg_nevr.should eq("bar-1.0-0")
      {% else %}
        problem.pkg_nevr.should eq("foo-1.0-0")
      {% end %}

      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "foo-1.0-0", "  Hello", 0)
      {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
        problem.pkg_nevr.should eq("bar-1.0-0")
      {% else %}
        problem.pkg_nevr.should eq("foo-1.0-0")
      {% end %}
    end

    it "raises NilAssertionError if PkgNEVR is not set" do
      problem = RPM::Problem.create(RPM::ProblemType::VERIFY, nil, nil, nil, nil, 0)
      expect_raises(NilAssertionError) do
        problem.pkg_nevr.should eq("")
      end
    end
  end

  describe "#pkg_nevr?" do
    it "returns `PkgNEVR` data of RPM problem" do
      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "foo-1.0-0", "foo.rpm", "bar-1.0-0", "Hello", 1)
      {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
        problem.pkg_nevr?.should eq("bar-1.0-0")
      {% else %}
        problem.pkg_nevr?.should eq("foo-1.0-0")
      {% end %}

      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "foo-1.0-0", "  Hello", 0)
      {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
        problem.pkg_nevr?.should eq("bar-1.0-0")
      {% else %}
        problem.pkg_nevr?.should eq("foo-1.0-0")
      {% end %}
    end

    it "returns nil if PkgNEVR is not set" do
      problem = RPM::Problem.create(RPM::ProblemType::VERIFY, nil, nil, nil, nil, 0)
      problem.pkg_nevr?.should be_nil
    end
  end

  describe "#alt_nevr" do
    it "returns `AltNEVR` data of RPM problem" do
      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "foo-1.0-0", "foo.rpm", "bar-1.0-0", "Hello", 1)
      {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
        problem.alt_nevr.should eq("  Hello")
      {% else %}
        problem.alt_nevr.should eq("bar-1.0-0")
      {% end %}

      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "foo-1.0-0", "  Hello", 0)
      {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
        problem.alt_nevr.should eq("  Hello")
      {% else %}
        problem.alt_nevr.should eq("bar-1.0-0")
      {% end %}
    end

    it "raises NilAssertionError if AltNEVR is not set" do
      problem = RPM::Problem.create(RPM::ProblemType::BADARCH, "bar-1.0-0", "", nil, "m68k", 0)
      expect_raises(NilAssertionError) do
        problem.alt_nevr.should eq("")
      end
    end
  end

  describe "#alt_nevr?" do
    it "returns `AltNEVR` data of RPM problem" do
      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "foo-1.0-0", "foo.rpm", "bar-1.0-0", "Hello", 1)
      {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
        problem.alt_nevr?.should eq("  Hello")
      {% else %}
        problem.alt_nevr?.should eq("bar-1.0-0")
      {% end %}

      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "foo-1.0-0", "  Hello", 0)
      {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
        problem.alt_nevr?.should eq("  Hello")
      {% else %}
        problem.alt_nevr?.should eq("bar-1.0-0")
      {% end %}
    end

    it "returns nil if AltNEVR is not set" do
      problem = RPM::Problem.create(RPM::ProblemType::BADARCH, "bar-1.0-0", "", nil, "m68k", 0)
      problem.alt_nevr?.should be_nil
    end
  end

  describe "#str" do
    it "returns `str` data of RPM problem" do
      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "foo-1.0-0", "foo.rpm", "bar-1.0-0", "Hello", 1)
      {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
        problem.str.should eq("foo-1.0-0")
      {% else %}
        problem.str.should eq("Hello")
      {% end %}

      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "foo-1.0-0", "  Hello", 0)
      {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
        problem.str.should eq("foo-1.0-0")
      {% else %}
        problem.str.should eq("Hello")
      {% end %}
    end

    it "raises NilAssertionError if str is not set" do
      problem = RPM::Problem.create(RPM::ProblemType::OLDPACKAGE, "bar-1.0-0", "", nil, nil, 0)
      expect_raises(NilAssertionError) do
        problem.str.should eq("")
      end
    end
  end

  describe "#str?" do
    it "returns `str` data of RPM problem" do
      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "foo-1.0-0", "foo.rpm", "bar-1.0-0", "Hello", 1)
      {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
        problem.str?.should eq("foo-1.0-0")
      {% else %}
        problem.str?.should eq("Hello")
      {% end %}

      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "foo-1.0-0", "  Hello", 0)
      {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") < 0 %}
        problem.str?.should eq("foo-1.0-0")
      {% else %}
        problem.str?.should eq("Hello")
      {% end %}
    end

    it "returns nil if str is not set" do
      problem = RPM::Problem.create(RPM::ProblemType::OLDPACKAGE, "bar-1.0-0", "", nil, nil, 0)
      problem.str?.should be_nil
    end
  end

  describe "#to_s" do
    it "returns string representation of RPM uses" do
      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "foo-1.0-0", "  Hello", 0)
      problem.to_s.should eq("Hello is needed by (installed) bar-1.0-0")

      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "foo-1.0-0", "foo.rpm", "bar-1.0-0", "Hello", 1)
      problem.to_s.should eq("Hello is needed by (installed) bar-1.0-0")
    end
  end

  describe "#dup" do
    it "can duplicate" do
      problem = RPM::Problem.create(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "", "  Hello", 0)
      d = problem.dup
      d.key.should eq(problem.key)
    end
  end

  {% if compare_versions(RPM::PKGVERSION_COMP, "4.9.0") >= 0 %}
    describe "#==" do
      it "can compare two problems" do
        a = RPM::Problem.create(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "", "  Hello", 0)
        b = RPM::Problem.create(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "", "  Hello", 0)
        (a == b).should be_true
      end

      it "can compare two problems" do
        a = RPM::Problem.create(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "", "  Hello", 0)
        b = RPM::Problem.create(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "", "  Hello", 1)
        (a == b).should be_false
      end
    end
  {% end %}
end

describe RPM::Problem::BadArch do
  describe ".for" do
    it "creates BADARCH problem" do
      obj = RPM::Problem::BadArch.for("package-1.0-0", "i686")
      obj.class.should eq(RPM::Problem::BadArch)
    end

    it "creates BADARCH problem from package" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      obj = RPM::Problem::BadArch.for(pkg)
      obj.class.should eq(RPM::Problem::BadArch)
    end
  end

  describe "#package" do
    it "returns pacakge NEVR which has problem" do
      obj = RPM::Problem::BadArch.for("package-1.0-0", "i686")
      obj.package.should eq("package-1.0-0")

      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      obj = RPM::Problem::BadArch.for(pkg)
      obj.package.should eq("simple-1.0-0")
    end
  end

  describe "#arch" do
    it "returns arch name which has problem" do
      obj = RPM::Problem::BadArch.for("package-1.0-0", "i686")
      obj.arch.should eq("i686")

      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      obj = RPM::Problem::BadArch.for(pkg)
      obj.arch.should eq("i586")
    end
  end

  describe "#to_s" do
    it "returns problem representation" do
      obj = RPM::Problem::BadArch.for("package-1.0-0", "i686")
      obj.to_s.should eq("package package-1.0-0 is intended for a i686 architecture")

      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      obj = RPM::Problem::BadArch.for(pkg)
      obj.to_s.should eq("package simple-1.0-0 is intended for a i586 architecture")
    end
  end
end

describe RPM::Problem::BadOS do
  describe ".for" do
    it "creates BADOS problem" do
      obj = RPM::Problem::BadOS.for("package-1.0-0", "freebsd")
      obj.class.should eq(RPM::Problem::BadOS)
    end

    it "creates BADOS problem from package" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      obj = RPM::Problem::BadOS.for(pkg)
      obj.class.should eq(RPM::Problem::BadOS)
    end
  end

  describe "#package" do
    it "returns pacakge NEVR which has problem" do
      obj = RPM::Problem::BadOS.for("package-1.0-0", "freebsd")
      obj.package.should eq("package-1.0-0")

      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      obj = RPM::Problem::BadOS.for(pkg)
      obj.package.should eq("simple-1.0-0")
    end
  end

  describe "#os" do
    it "returns os name which has problem" do
      obj = RPM::Problem::BadOS.for("package-1.0-0", "freebsd")
      obj.os.should eq("freebsd")

      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      obj = RPM::Problem::BadOS.for(pkg)
      obj.os.should eq("linux")
    end
  end

  describe "#to_s" do
    it "returns problem representation" do
      obj = RPM::Problem::BadOS.for("package-1.0-0", "freebsd")
      obj.to_s.should eq("package package-1.0-0 is intended for a freebsd operating system")

      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      obj = RPM::Problem::BadOS.for(pkg)
      obj.to_s.should eq("package simple-1.0-0 is intended for a linux operating system")
    end
  end
end

describe RPM::Problem::PackageInstalled do
  describe ".for" do
    it "creates PKG_INSTALLED problem" do
      obj = RPM::Problem::PackageInstalled.for("package-1.0-0")
      obj.class.should eq(RPM::Problem::PackageInstalled)
    end

    it "creates PKG_INSTALLED problem from package" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      obj = RPM::Problem::PackageInstalled.for(pkg)
      obj.class.should eq(RPM::Problem::PackageInstalled)
    end
  end

  describe "#package" do
    it "returns pacakge NEVR which has problem" do
      obj = RPM::Problem::PackageInstalled.for("package-1.0-0")
      obj.package.should eq("package-1.0-0")

      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      obj = RPM::Problem::PackageInstalled.for(pkg)
      obj.package.should eq("simple-1.0-0")
    end
  end

  describe "#to_s" do
    it "returns problem representation" do
      obj = RPM::Problem::PackageInstalled.for("package-1.0-0")
      obj.to_s.should eq("package package-1.0-0 is already installed")

      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      obj = RPM::Problem::PackageInstalled.for(pkg)
      obj.to_s.should eq("package simple-1.0-0 is already installed")
    end
  end
end

describe RPM::Problem::BadRelocate do
  describe ".for" do
    it "creates BADRELOCATE problem" do
      obj = RPM::Problem::BadRelocate.for("package-1.0-0", "/foo/bar")
      obj.class.should eq(RPM::Problem::BadRelocate)
    end

    it "creates BADRELOCATE problem from package" do
      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      obj = RPM::Problem::BadRelocate.for(pkg, "/foo/baz")
      obj.class.should eq(RPM::Problem::BadRelocate)
    end
  end

  describe "#package" do
    it "returns pacakge NEVR which has problem" do
      obj = RPM::Problem::BadRelocate.for("package-1.0-0", "/foo/bar")
      obj.package.should eq("package-1.0-0")

      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      obj = RPM::Problem::BadRelocate.for(pkg, "/foo/baz")
      obj.package.should eq("simple-1.0-0")
    end
  end

  describe "#path" do
    it "returns the path which is going to be relocated" do
      obj = RPM::Problem::BadRelocate.for("package-1.0-0", "/foo/bar")
      obj.path.should eq("/foo/bar")

      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      obj = RPM::Problem::BadRelocate.for(pkg, "/foo/baz")
      obj.path.should eq("/foo/baz")
    end
  end

  describe "#to_s" do
    it "returns problem representation" do
      obj = RPM::Problem::BadRelocate.for("package-1.0-0", "/foo/bar")
      obj.to_s.should eq("path /foo/bar in package package-1.0-0 is not relocatable")

      pkg = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      obj = RPM::Problem::BadRelocate.for(pkg, "/foo/baz")
      obj.to_s.should eq("path /foo/baz in package simple-1.0-0 is not relocatable")
    end
  end
end

describe RPM::Problem::NewFileConflict do
  describe ".for" do
    it "creates NEW_FILE_CONFLICT problem" do
      obj = RPM::Problem::NewFileConflict.for("a-1.0-0", "b-1.0-0", "/foo/bar")
      obj.class.should eq(RPM::Problem::NewFileConflict)
    end

    it "creates NEW_FILE_CONFLICT problem from package" do
      pkg1 = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg2 = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      obj = RPM::Problem::NewFileConflict.for(pkg1, pkg2, "/foo/baz")
      obj.class.should eq(RPM::Problem::NewFileConflict)

      obj = RPM::Problem::NewFileConflict.for(pkg1, "b-1.0-0", "/foo/baz")
      obj.class.should eq(RPM::Problem::NewFileConflict)

      obj = RPM::Problem::NewFileConflict.for("a-1.0-0", pkg2, "/foo/baz")
      obj.class.should eq(RPM::Problem::NewFileConflict)
    end
  end

  describe "#left_package" do
    it "returns first package NEVR which has problem" do
      obj = RPM::Problem::NewFileConflict.for("a-1.0-0", "b-1.0-0", "/foo/bar")
      obj.left_package.should eq("a-1.0-0")

      pkg1 = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg2 = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      obj = RPM::Problem::NewFileConflict.for(pkg1, pkg2, "/foo/baz1")
      obj.left_package.should eq("simple-1.0-0")

      obj = RPM::Problem::NewFileConflict.for(pkg1, "b-1.0-0", "/foo/baz2")
      obj.left_package.should eq("simple-1.0-0")

      obj = RPM::Problem::NewFileConflict.for("a-1.0-0", pkg2, "/foo/baz3")
      obj.left_package.should eq("a-1.0-0")
    end
  end

  describe "#right_package" do
    it "returns second package NEVR which has problem" do
      obj = RPM::Problem::NewFileConflict.for("a-1.0-0", "b-1.0-0", "/foo/bar")
      obj.right_package.should eq("b-1.0-0")

      pkg1 = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg2 = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      obj = RPM::Problem::NewFileConflict.for(pkg1, pkg2, "/foo/baz1")
      obj.right_package.should eq("simple_with_deps-1.0-0")

      obj = RPM::Problem::NewFileConflict.for(pkg1, "b-1.0-0", "/foo/baz2")
      obj.right_package.should eq("b-1.0-0")

      obj = RPM::Problem::NewFileConflict.for("a-1.0-0", pkg2, "/foo/baz3")
      obj.right_package.should eq("simple_with_deps-1.0-0")
    end
  end

  describe "#path" do
    it "returns the path which conflicts" do
      obj = RPM::Problem::NewFileConflict.for("a-1.0-0", "b-1.0-0", "/foo/bar")
      obj.path.should eq("/foo/bar")

      pkg1 = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg2 = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      obj = RPM::Problem::NewFileConflict.for(pkg1, pkg2, "/foo/baz1")
      obj.path.should eq("/foo/baz1")

      obj = RPM::Problem::NewFileConflict.for(pkg1, "b-1.0-0", "/foo/baz2")
      obj.path.should eq("/foo/baz2")

      obj = RPM::Problem::NewFileConflict.for("a-1.0-0", pkg2, "/foo/baz3")
      obj.path.should eq("/foo/baz3")
    end
  end

  describe "#to_s" do
    it "returns problem representation" do
      obj = RPM::Problem::NewFileConflict.for("a-1.0-0", "b-1.0-0", "/foo/bar")
      obj.to_s.should eq("file /foo/bar conflicts between attempted installs of a-1.0-0 and b-1.0-0")

      pkg1 = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg2 = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      obj = RPM::Problem::NewFileConflict.for(pkg1, pkg2, "/foo/baz1")
      obj.to_s.should eq("file /foo/baz1 conflicts between attempted installs of simple-1.0-0 and simple_with_deps-1.0-0")

      obj = RPM::Problem::NewFileConflict.for(pkg1, "b-1.0-0", "/foo/baz2")
      obj.to_s.should eq("file /foo/baz2 conflicts between attempted installs of simple-1.0-0 and b-1.0-0")

      obj = RPM::Problem::NewFileConflict.for("a-1.0-0", pkg2, "/foo/baz3")
      obj.to_s.should eq("file /foo/baz3 conflicts between attempted installs of a-1.0-0 and simple_with_deps-1.0-0")
    end
  end
end

describe RPM::Problem::FileConflict do
  describe ".for" do
    it "creates FILE_CONFLICT problem" do
      obj = RPM::Problem::FileConflict.for("a-1.0-0", "b-1.0-0", "/foo/bar")
      obj.class.should eq(RPM::Problem::FileConflict)
    end

    it "creates FILE_CONFLICT problem from package" do
      pkg1 = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg2 = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      obj = RPM::Problem::FileConflict.for(pkg1, pkg2, "/foo/baz")
      obj.class.should eq(RPM::Problem::FileConflict)

      obj = RPM::Problem::FileConflict.for(pkg1, "b-1.0-0", "/foo/baz")
      obj.class.should eq(RPM::Problem::FileConflict)

      obj = RPM::Problem::FileConflict.for("a-1.0-0", pkg2, "/foo/baz")
      obj.class.should eq(RPM::Problem::FileConflict)
    end
  end

  describe "#installing_package" do
    it "returns installing package NEVR which has problem" do
      obj = RPM::Problem::FileConflict.for("a-1.0-0", "b-1.0-0", "/foo/bar")
      obj.installing_package.should eq("a-1.0-0")

      pkg1 = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg2 = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      obj = RPM::Problem::FileConflict.for(pkg1, pkg2, "/foo/baz1")
      obj.installing_package.should eq("simple-1.0-0")

      obj = RPM::Problem::FileConflict.for(pkg1, "b-1.0-0", "/foo/baz2")
      obj.installing_package.should eq("simple-1.0-0")

      obj = RPM::Problem::FileConflict.for("a-1.0-0", pkg2, "/foo/baz3")
      obj.installing_package.should eq("a-1.0-0")
    end
  end

  describe "#installed_package" do
    it "returns installed package NEVR which has problem" do
      obj = RPM::Problem::FileConflict.for("a-1.0-0", "b-1.0-0", "/foo/bar")
      obj.installed_package.should eq("b-1.0-0")

      pkg1 = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg2 = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      obj = RPM::Problem::FileConflict.for(pkg1, pkg2, "/foo/baz1")
      obj.installed_package.should eq("simple_with_deps-1.0-0")

      obj = RPM::Problem::FileConflict.for(pkg1, "b-1.0-0", "/foo/baz2")
      obj.installed_package.should eq("b-1.0-0")

      obj = RPM::Problem::FileConflict.for("a-1.0-0", pkg2, "/foo/baz3")
      obj.installed_package.should eq("simple_with_deps-1.0-0")
    end
  end

  describe "#path" do
    it "returns the path which conflicts" do
      obj = RPM::Problem::FileConflict.for("a-1.0-0", "b-1.0-0", "/foo/bar")
      obj.path.should eq("/foo/bar")

      pkg1 = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg2 = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      obj = RPM::Problem::FileConflict.for(pkg1, pkg2, "/foo/baz1")
      obj.path.should eq("/foo/baz1")

      obj = RPM::Problem::FileConflict.for(pkg1, "b-1.0-0", "/foo/baz2")
      obj.path.should eq("/foo/baz2")

      obj = RPM::Problem::FileConflict.for("a-1.0-0", pkg2, "/foo/baz3")
      obj.path.should eq("/foo/baz3")
    end
  end

  describe "#to_s" do
    it "returns problem representation" do
      obj = RPM::Problem::FileConflict.for("a-1.0-0", "b-1.0-0", "/foo/bar")
      obj.to_s.should eq("file /foo/bar from install of a-1.0-0 conflicts with file from package b-1.0-0")

      pkg1 = RPM::Package.open(fixture("simple-1.0-0.i586.rpm"))
      pkg2 = RPM::Package.open(fixture("simple_with_deps-1.0-0.i586.rpm"))
      obj = RPM::Problem::FileConflict.for(pkg1, pkg2, "/foo/baz1")
      obj.to_s.should eq("file /foo/baz1 from install of simple-1.0-0 conflicts with file from package simple_with_deps-1.0-0")

      obj = RPM::Problem::FileConflict.for(pkg1, "b-1.0-0", "/foo/baz2")
      obj.to_s.should eq("file /foo/baz2 from install of simple-1.0-0 conflicts with file from package b-1.0-0")

      obj = RPM::Problem::FileConflict.for("a-1.0-0", pkg2, "/foo/baz3")
      obj.to_s.should eq("file /foo/baz3 from install of a-1.0-0 conflicts with file from package simple_with_deps-1.0-0")
    end
  end
end
