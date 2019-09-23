require "../spec_helper"
require "tempdir"

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

  describe "#dup" do
    it "can duplicate" do
      problem = RPM::Problem.new(RPM::ProblemType::REQUIRES, "bar-1.0-0", "foo.rpm", nil, "", "  Hello", 0)
      d = problem.dup
      d.key.should eq(problem.key)
    end
  end
end
