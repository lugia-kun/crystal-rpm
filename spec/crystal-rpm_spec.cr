require "./spec_helper"

describe RPM::Package do
  data_dir = File.join(File.dirname(__FILE__), "data")

  it "creates a package like" do
    pkg = RPM::Package.create("foo", RPM::Version.new("1.0"))
    pkg.name.should eq("foo")
    pkg.signature.should eq("(none)")
  end

  it "opens a simple package and ..." do
    pkg = RPM::Package.open(File.join(data_dir, "simple-1.0-0.i586.rpm"))

    pkg.signature.should eq("3b5f9d468c877166532c662e29f43bc3")
    pkg[RPM::Tag::Name].should eq("simple")
    pkg[RPM::Tag::Arch].should eq("i586")

    old_lang = ENV["LC_ALL"]?

    ENV["LC_ALL"] = "C"

    pkg[RPM::Tag::Summary].should eq("Simple dummy package")
    pkg[RPM::Tag::Description].should eq("Dummy package")

    ENV["LC_ALL"] = "es_ES.UTF-8"

    pkg[RPM::Tag::Summary].should eq("Paquete simple de muestra")
    pkg[RPM::Tag::Description].should eq("Paquete de muestra")

    ENV["LC_ALL"] = old_lang

    pkg[RPM::Tag::FileUserName].should eq(%w[root root])
    pkg[RPM::Tag::FileSizes].should eq([6, 5])

    pkg.provides.map { |x| x.name }.to_set
      .should eq(Set{"simple(x86-32)", "simple"})

    pkg.files.map { |x| x.path }.to_set
      .should eq(Set{
                   "/usr/share/simple/README",
                   "/usr/share/simple/README.es",
                 })

    file = pkg.files.find { |x| x.path == "/usr/share/simple/README" }
    file.is_a?(RPM::File).should be_true

    file = file.as(RPM::File)

    # ruby-rpm asserts this is nil, but RPM API itself seems to return
    # an empty string, not a NULL pointer.
    file.link_to.should eq("")
  end
end
