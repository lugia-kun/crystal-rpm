require "spec"
require "file_utils"
require "path"
require "logger"
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
      fun sizeof_buildarguments_s() : LibC::Int
      fun offset_buildarguments_s(UInt8*) : LibC::Int
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

      def self.sizeof_buildarguments_s()
        return -1
      end

      def self.offset_buildarguments_s(f : String)
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

struct RPM::LibRPM::BuildArguments_s
  include OffsetOf
end

def is_chroot_possible?
  (LibC.chroot("/") == 0).tap { |f| (!f) ? Errno.value = 0 : nil }
end

{% if flag?("verbose_debug_log") %}
  SPEC_LOG_FILE  = File.basename(__FILE__) + ".log"
  SPEC_DEBUG_LOG = Logger.new(File.open(SPEC_LOG_FILE, "w"), level: Logger::DEBUG)
{% else %}
  SPEC_DEBUG_LOG = Logger.new(STDERR, level: Logger::FATAL)
{% end %}

def shellescape(io : IO, str : String)
  m = nil
  cls = true
  str.each_char_with_index do |ch, i|
    case ch
    when '(', ')', '<', '>', '[', ']', '\\', ';', '\'',
         '"', '?', '!', '#', '$', '&', '*', '`', '~'
      if m.nil?
        m = IO::Memory.new
        if i > 0
          m << "'"
          str.each_char_with_index do |chx, j|
            break if i == j
            m << chx
          end
          mnew = false
        else
          mnew = true
        end
      else
        mnew = false
      end
      case ch
      when "\\"
        if mnew
          m << "'"
        end
        m << "\\\\"
      when "'"
        if mnew && str.size == 1
          m << "\\'"
          cls = false
        else
          if mnew
            m << "'"
          end
          m << "'\\''"
        end
      else
        if mnew
          m << "'"
        end
        m << ch
      end
    else
      if m
        m << ch
      end
    end
    mnew = false
  end
  if m.nil?
    io << str
  else
    m.pos = 0
    io << m.gets_to_end
    if cls
      io << "'"
    end
  end
end

def command_to_s(io : IO, command, args, prompt = "$", **opts)
  clenv = opts[:clear_env]? || false
  env = opts[:env]?
  chdir = opts[:chdir]?

  if prompt
    io << prompt << " "
  end
  if chdir
    io << "(cd " << chdir << " && "
  end
  if (env && env.size > 0) || clenv
    io << "env "
    if clenv
      io << "-i "
    end
    if env
      env.each do |k, v|
        if v
          shellescape(io, k + '=' + v)
        else
          io << "-u "
          shellescape(io, k)
        end
        io << " "
      end
    end
  end
  shellescape(io, command)
  io << " "
  args.each do |a|
    shellescape(io, a)
    io << " "
  end
  if chdir
    io << ")"
  end
  io.flush
end

class RPMCLIExectionFailed < Exception
end

def rpm(*args, raise_on_failure : Bool = true, env : Process::Env = nil,
        output = Process::Redirect::Pipe, input = Process::Redirect::Close,
        error = Process::Redirect::Inherit, **opts, &block)
  if env.nil?
    env = {"LANG" => "C"}
  elsif !env.key?("LANG")
    env = env.dup
    env["LANG"] = "C"
  end
  SPEC_DEBUG_LOG.debug do
    String.build do |sio|
      command_to_s(sio, "rpm", args, **opts, env: env, output: output, input: input, error: error)
    end
  end
  process = Process.new("rpm", args, **opts, env: env, output: output, input: input, error: error)
  begin
    yield process
  ensure
    $? = process.wait
    if raise_on_failure && !$?.success?
      raise RPMCLIExectionFailed.new("Execution of 'rpm #{args.join(" ")}' failed")
    end
  end
end

def rpm(*args, **opts)
  rpm(*args, **opts) do |prc|
    if (output = prc.output?)
      output.gets_to_end
    end
  end
ensure
  $? = $?
end

def install_simple(*, root : String, package : String = "simple-1.0-0.i586.rpm")
  is = File.info(root, follow_symlinks = true)
  ir = File.info("/")
  if is.same_file?(ir)
    raise "Rejects installing a package to \"/\""
  end
  rpm_path = Path.new(fixture(package)).expand.normalize
  r, w = IO.pipe
  ret = nil
  begin
    rpm("-i", "-r", root, rpm_path.to_s, "--nodeps", output: w, error: w) do
      w.close
      ret = r.gets_to_end
      r.close
    end
  rescue RPMCLIExectionFailed
    raise "Failed to install simple package: #{ret}"
  end
  nil
end
