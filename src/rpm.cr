require "./rpm/**"

module RPM
  # Version of crystal binding
  VERSION = "0.1.0"

  # Runtime Version of RPM Library (RPM::PKGVERSION is compile-time version)
  RPMVERSION = String.new(LibRPM.rpmversion)

  def self.rpm_version_code : UInt32
    maj, min, pat = RPMVERSION.split(".", 3)
    (maj.to_u32 << 16) + (min.to_u32 << 8) + (pat.to_u32)
  end

  # Macro files
  MACROFILES = String.new(LibRPM.macrofiles)
end
