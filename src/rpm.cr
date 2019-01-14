require "./rpm/**"

module RPM
  # Runtime Version of RPM Library (RPM::PKGVERSION is compile-time version)
  VERSION = String.new(LibRPM.rpmversion)
end
