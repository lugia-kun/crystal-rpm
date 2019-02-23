puts [Process.find_executable("cc"), File.join(File.dirname(__FILE__), "c-check.o")].join(":")
exit 0
