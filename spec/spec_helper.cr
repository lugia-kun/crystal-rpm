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
  {% maj = " -DVERSION_MAJOR=#{RPM::PKGVERSION_MAJOR}" %}
  {% min = " -DVERSION_MINOR=#{RPM::PKGVERSION_MINOR}" %}
  {% pat = " -DVERSION_PATCH=#{RPM::PKGVERSION_PATCH}" %}
  set_compiler({{a[0]}}, {{a[1]}},
               {{`pkg-config rpm --cflags`.stringify.chomp + maj + min + pat}})
{% end %}

{% if CC.size > 0 %}
  {% com = "#{CC} #{CFLAGS.id} -c -o #{OBJPATH} ./spec/c-check.c" %}
  {% puts com %}
  {% l = `(#{com.id}) && echo 1 || :` %}
  {% if l.stringify.starts_with?("1") %}
    @[Link(ldflags: {{OBJPATH}})]
    lib CCheck
      fun sizeof_spec_s() : LibC::Int
      fun offset_spec_s(UInt8*) : LibC::Int
      fun sizeof_package_s() : LibC::Int
      fun offset_package_s(UInt8*) : LibC::Int
    end
  {% else %}
    module CCheck
      def self.sizeof_spec_s()
        return -1
      end

      def self.offset_spec_s(f : String)
        return -1
      end

      def self.sizeof_package_s()
        return -1
      end

      def self.offset_package_s(f : String)
        return -1
      end
    end
  {% end %}
{% end %}

module OffsetOf
  macro included
    macro method_missing(call)
      \{% name_s = call.name.id.stringify %}
      \{% if name_s.starts_with?("__offsetof_") %}
        \{% mem = name_s.gsub(/^__offsetof_/, "") %}
        pointerof(@\{{mem.id}}).as(Pointer(UInt8))
      \{% else %}
        \{% raise "method #{call.name.id} undefined for {{@type.name.id}}" %}
      \{% end %}
    end

    macro offsetof(member)
      Proc(Int64).new do
        x = uninitialized {{@type.name.id}}
        x.__offsetof_\{{member.id.gsub(/^@/, "")}} - pointerof(x).as(Pointer(UInt8))
      end.call
    end
  end
end

struct RPM::LibRPM::Spec_s
  include OffsetOf
end

struct RPM::LibRPM::Package_s
  include OffsetOf
end
