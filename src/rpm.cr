require "./rpm/**"

module RPM
  # Version of crystal binding
  VERSION = "0.1.0"

  # Runtime Version of RPM Library (cf. `RPM::PKGVERSION` is
  # compile-time version)
  RPMVERSION = String.new(LibRPM.rpmversion)

  # Calculate version code.
  #
  # Recommend use `RPMVERSION` directly.
  def self.rpm_version_code : UInt32
    maj, min, pat = RPMVERSION.split(".")
    (maj.to_u32 << 16) + (min.to_u32 << 8) + (pat.to_u32)
  end

  # Reads RPM config files
  #
  # If `nil` given for each parameters, read the current system's
  # default value
  def self.read_config_files(file : String? = nil, target : String? = nil)
    LibRPM.rpmReadConfigFiles(file, target)
  end

  RPM.read_config_files

  # Default macro files
  MACROFILES = String.new(LibRPM.macrofiles)
end
