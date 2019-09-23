require "../spec_helper"
require "tempdir"

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
