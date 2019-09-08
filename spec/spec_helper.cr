require "spec"
require "file_utils"
require "path"
require "logger"
require "tempdir"
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

ORIGINAL_DIR = File.dirname(__FILE__)

# Run small Crystal program as an external program
macro run_in_subproc(*args, **opts, &block)
  begin
    %script = File.tempfile("run", ".cr", dir: ORIGINAL_DIR)
    begin
      %script.print <<-EOF
require "../src/rpm"

{% begin %}
{% i = 0 %}
{% for a in args %}
{% if a.is_a?(Var) %}
{{a.id}} = ARGV[{{i}}]
{% end %}
{% i = i + 1 %}
{% end %}
{% end %}

{{yield}}
EOF
      %script.flush
      %args = {"run", %script.path, "--", {{args.splat}} }
      {% if opts[:error].is_a?(NilLiteral) %}
        {% opts[:error] = "Process::Redirect::Inherit".id %}
      {% end %}
      {% opts[:input] = "Process::Redirect::Close".id %}
      Process.run("crystal", %args, {{opts.double_splat}} )
    ensure
      %script.delete
    end
  end
end

# # Spec of helper
describe "helper" do
  describe "#rpm" do
    it "runs rpm" do
      rpm("--version")
    end

    it "raises RPMCLIExceptionFailed on failure" do
      expect_raises(RPMCLIExectionFailed) do
        rpm("-i", ".", output: Process::Redirect::Close, error: Process::Redirect::Close)
      end
    end

    it "sets $? (without block)" do
      rpm("--version")
      $?.exit_code.should eq(0)
    end

    it "sets $? (with block)" do
      # Wrong argument is intentional.
      rpm("--vers", raise_on_failure: false, error: Process::Redirect::Pipe) do |x|
        x.error.gets_to_end.should match(/unknown option/)
      end
      $?.success?.should be_false
    end
  end

  describe "#is_chroot_possible?" do
    it "should return true (unless some tests will be skipped)" do
      is_chroot_possible?.should be_true
    end
  end

  describe "#install_simple" do
    it "installs simple" do
      Dir.mktmpdir do |root|
        install_simple(root: root)
      end
    end

    it "installs simple_with_deps (implicit --nodeps)" do
      Dir.mktmpdir do |root|
        install_simple(package: "simple_with_deps-1.0-0.i586.rpm", root: root)
      end
    end

    it "fails when attempted to install to \"/\"" do
      expect_raises(Exception) do
        install_simple(root: "/")
      end
    end
  end

  describe "#run_in_subproc" do
    it "runs simple program" do
      r, w = IO.pipe
      stat = run_in_subproc(output: w) do
        puts "Hello, World"
      end
      w.close
      output = r.gets_to_end
      r.close
      stat.exit_code.should eq(0)
      output.should eq("Hello, World\n")
    end

    it "runs program uses RPM" do
      r, w = IO.pipe
      stat = run_in_subproc(output: w) do
        puts RPM.class
      end
      w.close
      output = r.gets_to_end
      r.close
      stat.exit_code.should eq(0)
      output.should eq(RPM.class.to_s + "\n")
    end

    it "runs program uses ARGV" do
      stat = run_in_subproc("a", "b", "c") do
        exit ((ARGV == %w[a b c]) ? 0 : 1)
      end
      stat.exit_code.should eq(0)
    end

    it "runs program uses ARGV (via Var)" do
      a = "a"
      b = "b"
      d = "d"
      stat = run_in_subproc(a, b, "c", d) do
        exit ((a == "a" && b == "b" && ARGV[2] == "c" && d == "d") ? 0 : 1)
      end
      stat.exit_code.should eq(0)
    end

    it "rejects input" do
      test = File.tempfile
      begin
        test.print "Yay!"
        test.flush
        test.pos = 0
        stat = run_in_subproc(input: test, output: Process::Redirect::Inherit) do
          ret = STDIN.gets
          exit (ret.nil? ? 0 : 1)
        end
        test.gets.should eq("Yay!")
        stat.exit_code.should eq(0)
      ensure
        test.delete
      end
    end

    it "can not access to Spec" do
      r, w = IO.pipe
      stat = run_in_subproc(error: w) do
        puts Spec.class
      end
      w.close
      err = r.gets_to_end
      r.close
      err.should match(/undefined constant Spec/)
      stat.should_not eq(0)
    end
  end
end
