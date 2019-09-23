require "../spec_helper"
require "tempdir"

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
