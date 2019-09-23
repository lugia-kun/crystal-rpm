require "../spec_helper"
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

  describe "::MACROFILES" do
    it "stores the list of macro files" do
      # The actual content is environment dependent.
      RPM::MACROFILES.should start_with("")
    end
  end
end
