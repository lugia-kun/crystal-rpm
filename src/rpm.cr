require "./rpm/**"

module RPM
  # Version of crystal binding
  VERSION = "1.0.0"

  # Runtime Version of RPM Library (cf. `RPM::PKGVERSION` is
  # compile-time version)
  RPMVERSION = String.new(LibRPM.rpmversion)

  # Calculate version code.
  @[Deprecated("Use `RPMVERSION`")]
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

  # Write macro
  def self.[]=(name : String, value : String?)
    if value.nil?
      RPM.pop_macro(nil, name)
    else
      RPM.push_macro(nil, name, "", value, LibRPM::RMIL_DEFAULT)
    end
    value
  end

  # Read macro
  #
  # Raises KeyError when specified name is not defined
  def self.[](name : String)
    input = "%{#{name}}"
    expnd = LibRPM.rpmExpand(input, nil)
    if expnd.null?
      raise KeyError.new("RPM Macro #{name} not defined or error")
    else
      str = String.new(expnd)
      if str == input
        raise KeyError.new("RPM Macro #{name} not defined or error")
      end
      str
    end
  ensure
    LibC.free(expnd) if expnd && !expnd.null?
  end

  # Read macro
  #
  # Return nil if specified name is not defined.
  def self.[]?(name : String)
    input = "%{#{name}}"
    expnd = LibRPM.rpmExpand(input, nil)
    if expnd.null?
      nil
    else
      str = String.new(expnd)
      if str == input
        nil
      else
        str
      end
    end
  ensure
    LibC.free(expnd) if expnd && !expnd.null?
  end

  # Allocation Error occured within librpm API
  class AllocationError < Exception
    def initialize(message)
      super(message + ": Allocation failed")
    end
  end
end
