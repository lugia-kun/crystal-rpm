require "./spec_helper.cr"
require "./rpm/**"

describe "Files" do
  {% if !flag?("skip_openfile_test") %}
    it "should not be opened" do
      pid = Process.pid
      path = "/proc/#{pid}/fd"
      dbpath = RPM["_dbpath"]
      cwd = File.dirname(__FILE__)
      # system("ls", ["-l", path])
      Dir.open(path) do |dir|
        dir.each do |x|
          fp = File.join(path, x)
          begin
            info = File.info(fp, follow_symlinks: false)
            next unless info.symlink?
            tg = File.real_path(fp)
          rescue e : RuntimeError
            if e.os_error != Errno::ENOENT
              raise e
            end
            next
          end
          if tg.starts_with?(dbpath) || tg.starts_with?(cwd)
            raise "All DB or file should be closed: '#{tg}' is opened."
          end
        end
      end
    rescue e : RuntimeError
      if e.os_error != Errno::ENOENT
        raise e
      else
        STDERR.puts "/proc filesystem not found or not mounted. Skipping open-files check"
      end
    end
  {% else %}
    pending "should not be opened (`-Dskip_openfile_test` is given)"
  {% end %}
end
