require "spec"
require "../src/rpm"

def fixture(name : String) : String
  File.expand_path(File.join(File.dirname(__FILE__), "data", name))
end
