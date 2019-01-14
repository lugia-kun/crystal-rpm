require "rpm/librpm"

require "rpm/db"
require "rpm/file"

module RPM
  # Runtime Version of RPM Library (RPM::PKGVERSION is compile-time version)
  VERSION = String.new(LibRPM.rpmversion)
end
