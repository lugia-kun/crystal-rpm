require "spec"
require "file_utils"
require "../src/rpm"

def fixture(name : String) : String
  File.expand_path(File.join(File.dirname(__FILE__), "data", name))
end

macro set_compiler(cc, objpath, cflags)
  CC = {{cc}}
  CFLAGS = {{cflags}}
  OBJPATH = {{objpath}}
end
{% begin %}
{% a = run("./cc.cr").chomp.split(":") %}
set_compiler({{a[0]}}, {{a[1]}},
             {{ `pkg-config rpm --cflags`.stringify.chomp }})
{% end %}

{% if CC.size > 0 %}
  {% l = `#{CC} #{CFLAGS.id} -c -o #{OBJPATH} ./spec/c-check.c && echo 1 || :` %}
  {% if l.stringify.starts_with?("1") %}
    @[Link(ldflags: {{OBJPATH}})]
    lib CCheck
      fun sizeof_spec_s() : LibC::SizeT
    end
  {% else %}
    module CCheck
      def self.sizeof_spec_s()
         return -1
      end
    end
  {% end %}
{% end %}

puts CCheck.sizeof_spec_s
