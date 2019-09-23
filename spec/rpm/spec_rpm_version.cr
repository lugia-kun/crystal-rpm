require "../spec_helper"
require "tempdir"

describe RPM::Version do
  describe ".parse_evr" do
    it "parses EVR format into Set of {Epoch, Version, Release}" do
      RPM::Version.parse_evr("23:1.0.3-1suse").should eq({23, "1.0.3", "1suse"})
      RPM::Version.parse_evr("1.0").should eq({nil, "1.0", nil})
      RPM::Version.parse_evr("2.0-3").should eq({nil, "2.0", "3"})
      RPM::Version.parse_evr("2.0-").should eq({nil, "2.0", ""})
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

    it "returns nil for nil release" do
      d = RPM::Version.new("0.9.0")
      d.r.should be_nil
    end

    it "returns empty string for empty release" do
      d = RPM::Version.new("0.9.0-")
      d.r.should eq("")
    end
  end

  describe "#e" do
    it "returns epoch part" do
      d = RPM::Version.new("0.9.0-1m", 1)
      d.e.should eq(1)
    end

    it "returns nil for nil epoch" do
      d = RPM::Version.new("0.9.0-1m")
      d.e.should be_nil
    end

    it "returns 0 for 0 epoch" do
      d = RPM::Version.new("0.9.0-1m", 0)
      d.e.should eq(0)
    end
  end

  describe "#<=>" do
    it "compares epoch in first priority" do
      a = RPM::Version.new("0.9.0", "1m", 0)
      b = RPM::Version.new("0.9.0", "1m", 2)
      c = RPM::Version.new("1.0.0", "1m", 1)

      (a <=> b).should eq(0 <=> 2)
      (b <=> a).should eq(2 <=> 0)
      (b <=> c).should eq(2 <=> 1)
      (c <=> b).should eq(1 <=> 2)
    end

    it "compares to zero epoch and nil epoch are equal" do
      a = RPM::Version.new("0.9.0", "1m", 0)
      b = RPM::Version.new("0.9.0", "1m")
      c = RPM::Version.new("1.0.0", "1m")

      (a <=> b).should eq(0)
      (b <=> a).should eq(0)
      (a <=> c).should eq(b <=> c)
      (c <=> a).should eq(c <=> b)
    end

    it "compares versions" do
      a = RPM::Version.new("0.9.0", "3m")
      b = RPM::Version.new("0.10.0", "2m")
      c = RPM::Version.new("1.0.0", "1m")

      (a <=> b).should eq(RPM::LibRPM.rpmvercmp("0.9.0", "0.10.0"))
      (b <=> a).should eq(RPM::LibRPM.rpmvercmp("0.10.0", "0.9.0"))
      (b <=> c).should eq(RPM::LibRPM.rpmvercmp("0.10.0", "1.0.0"))
      (c <=> b).should eq(RPM::LibRPM.rpmvercmp("1.0.0", "0.10.0"))
    end

    it "comapres as nil-release and empty release are equal" do
      a = RPM::Version.new("0.9.0")
      b = RPM::Version.new("0.9.0", "")
      c = RPM::Version.new("0.9.0", "1m")

      (a <=> b).should eq(0)
      (b <=> a).should eq(0)
      (b <=> c).should eq(RPM::LibRPM.rpmvercmp("", "1m"))
      (c <=> b).should eq(RPM::LibRPM.rpmvercmp("1m", ""))
      (a <=> c).should eq(RPM::LibRPM.rpmvercmp("", "1m"))
      (c <=> a).should eq(RPM::LibRPM.rpmvercmp("1m", ""))
    end

    it "can compare as Comparable" do
      a = RPM::Version.new("1.0.0-0.1m")
      b = RPM::Version.new("0.9.0-1m")
      c = RPM::Version.new("1.0.0-0.11m")
      d = RPM::Version.new("0.9.0-1m", 1)
      e = RPM::Version.new("0.9.0-1m", 0)
      f = RPM::Version.new("0.1")
      g = RPM::Version.new("1.0.0")
      h = RPM::Version.new("1.0.0", "")

      (a > b).should be_true
      (a < c).should be_true
      (a < d).should be_true
      (b == e).should be_true
      (f > a).should be_false
      (a < g).should be_false
      (g > a).should be_false
      (d == e).should be_false
      (g == h).should be_true
      (h == g).should be_true
      (c > h).should be_true
      (h > c).should be_false
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

  describe "#to_s" do
    it "returns stringified Version, Relase and Epoch" do
      v = RPM::Version.new("0.9.0", "1m")
      v.to_s.should eq("0.9.0-1m")

      v = RPM::Version.new("0.9.0")
      v.to_s.should eq("0.9.0")

      v = RPM::Version.new("0.9.0", "1m", 1)
      v.to_s.should eq("1:0.9.0-1m")

      v = RPM::Version.new("0.9.0", "1m", 0)
      v.to_s.should eq("0:0.9.0-1m")
    end
  end

  describe "#to_vre" do
    it "returns stringified Version, Release and Epoch" do
      v = RPM::Version.new("0.9.0", "1m")
      v.to_vre.should eq("0.9.0-1m")

      v = RPM::Version.new("0.9.0")
      v.to_vre.should eq("0.9.0")

      v = RPM::Version.new("0.9.0", "1m", 1)
      v.to_vre.should eq("1:0.9.0-1m")

      v = RPM::Version.new("0.9.0", "1m", 0)
      v.to_vre.should eq("0:0.9.0-1m")
    end
  end

  describe "#to_vr" do
    it "returns stringified Version and Relase" do
      v = RPM::Version.new("0.9.0", "1m")
      v.to_vr.should eq("0.9.0-1m")

      v = RPM::Version.new("0.9.0")
      v.to_vr.should eq("0.9.0")

      v = RPM::Version.new("0.9.0", "1m", 1)
      v.to_vr.should eq("0.9.0-1m")
    end
  end
end
