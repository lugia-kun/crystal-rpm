require "./librpm"

struct RPM::Transaction::Element
  # Returns type of element
  def type : ElementType
    LibRPM.rpmteType(@ptr)
  end

  # Returns package name to install, update or remove
  def name : String
    String.new(LibRPM.rpmteN(@ptr))
  end

  # Returns package epoch to install, update or remove
  #
  # NOTE: Upstream API returns a string for this function.
  # So, this method returns a String.
  #
  # If the package has no epoch, this method returns `nil`.
  def epoch : String?
    e = LibRPM.rpmteE(@ptr)
    if e.null?
      nil
    else
      String.new(e)
    end
  end

  # Returns package version to install, update or remove
  def version : String
    String.new(LibRPM.rpmteV(@ptr))
  end

  # Returns package release to install, update or remove
  def release : String
    String.new(LibRPM.rpmteR(@ptr))
  end

  # Returns package architecture to install, update or remove
  def arch : String
    String.new(LibRPM.rpmteA(@ptr))
  end

  # Returns package key to install, update or remove
  #
  # NOTE: This method returns a string, because crystal-rpm passes
  # a string to 'key', and some RPM features needs that it must be
  # a string. Since the type of key is actually `void*`, so you can
  # set non-string object elsewhere crystal-rpm.
  def key : String?
    ptr = LibRPM.rpmteKey(@ptr)
    if ptr.null?
      nil
    else
      String.new(ptr.as(Pointer(UInt8)))
    end
  end

  # Returns true if source package
  def is_source? : Bool
    LibRPM.rpmteIsSource(@ptr) != 0
  end

  # Returns file size of package
  def package_file_size : LibRPM::Loff
    LibRPM.rpmtePkgFileSize(@ptr)
  end

  # Returns parent element
  def parent : Element?
    ptr = LibRPM.rpmteParent(@ptr)
    if ptr.null?
      nil
    else
      Element.new(ptr)
    end
  end

  # Sets parent element
  def parent=(e : Element)
    LibRPM.rpmteSetParent(e.ptr)
    e
  end

  # Returns problems belongs to this element
  #
  # NOTE: RPM 4.8 does not support this method.
  def problems : ProblemSet?
    ptr = LibRPM.rpmteProblems(@ptr)
    if ptr.null?
      nil
    else
      ProblemSet.new(ptr)
    end
  end

  # Clear problems in the element
  #
  # NOTE: RPM 4.8 does not support this method.
  def clean_problems
    LibRPM.rpmteCleanProblems(@ptr)
  end

  # Clear dependency in the element
  def clean_dependency_set
    LibRPM.rpmteCleanDS(@ptr)
  end

  # Set depends on (only meaningful for removing)
  def depends_on=(e : Element)
    LibRPM.rpmteSetDependsOn(@ptr, e.ptr)
    e
  end

  # Get depends on
  def depends_on
    ptr = LibRPM.rpmteDependsOn(@ptr)
    if ptr.null?
      nil
    else
      Element.new(ptr)
    end
  end

  # Returns the value DB Offset
  def db_offset
    LibRPM.rpmteDBOffset(@ptr)
  end

  # Returns EVR string
  def to_EVR
    String.new(LibRPM.rpmteEVR(@ptr))
  end

  # Returns NEVR string
  def to_NEVR
    String.new(LibRPM.rpmteNEVR(@ptr))
  end

  # Returns NEVRA String
  def to_NEVRA
    String.new(LibRPM.rpmteNEVRA(@ptr))
  end

  # Returns failed status
  def failed? : Bool
    LibRPM.rpmteFailed(@ptr) != 0
  end

  private def ptr
    @ptr
  end
end
