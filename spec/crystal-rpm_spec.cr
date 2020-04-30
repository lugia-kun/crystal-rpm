require "./spec_helper.cr"
require "./rpm/**"

describe "Files" do
  {% if !flag?("skip_openfile_test") %}
    it "should not be opened" do
      path = "/proc/self/fd"
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
          rescue File::NotFoundError
            next
          end
          if tg.starts_with?(dbpath) || tg.starts_with?(cwd)
            raise "All DB or file should be closed: '#{tg}' is opened."
          end
        end
      end
    rescue File::NotFoundError
      STDERR.puts "/proc filesystem not found or not mounted. Skipping open-files check"
    end
  {% else %}
    pending "should not be opened (`-Dskip_openfile_test` is given)"
  {% end %}
end
