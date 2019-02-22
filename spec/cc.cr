puts [Process.find_executable("cc"), File.tempname(".o")].join(":")
exit 0
