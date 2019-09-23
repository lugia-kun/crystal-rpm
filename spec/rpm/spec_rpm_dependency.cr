require "../spec_helper"
require "tempdir"

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
