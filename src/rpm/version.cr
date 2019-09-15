module RPM
  class Version
    include Comparable(Version)

    def self.parse_evr(evr : String)
      version = evr
      epoch = nil
      release = nil

      # Based on YUM's EVR parser.
      idx = version.rindex('-')
      if idx
        release = version[(idx + 1)..-1]
        version = version[0..(idx - 1)]
      end

      idx = version.index(":")
      if idx
        epoch = UInt32.new(version[0..(idx - 1)])
        version = version[(idx + 1)..-1]
      end

      {epoch, version, release}
    end

    getter e : UInt32?
    getter v : String
    getter r : String?

    def initialize(str : String)
      @e, @v, @r = Version.parse_evr(str)
    end

    def initialize(str : String, epoch : Int)
      e, @v, @r = Version.parse_evr(str)
      @e = epoch.to_u32
    end

    def initialize(@v, @r, epoch : Int? = nil)
      if epoch
        @e = epoch.to_u32
      else
        @e = nil
      end
    end

    # Compare to other versions.
    #
    # If `self` is newer, returns 1. If `other` is newer, returns -1.
    # If two versions are equal, returns 0.
    #
    # If one's epoch is `nil`, it will be evaluated as 0 for
    # comparison. If one's release is `nil`, it will be evaluated as
    # empty string.
    #
    # NOTE: Using the semantic of RPM's `rpmVersionCompare` function,
    #       except for the process for nil-releases.
    def <=>(other : Version) : Int32
      self_e = self.e || 0_u32
      other_e = other.e || 0_u32
      if self_e < other_e
        return -1
      elsif self_e > other_e
        return 1
      end

      rc = LibRPM.rpmvercmp(self.v, other.v)
      if rc != 0
        return rc
      end

      # According to the source of `rpmvercmp`, the arguments must not
      # be NULL. So, Nil (NULL) release seems to be unexpected in
      # RPM. Generated versions by `.parse_evr` may return nil as
      # release for strings which don't contain `-`.
      if (self_r = self.r)
        if (other_r = other.r)
          LibRPM.rpmvercmp(self_r, other_r)
        else
          # LibRPM.rpmvercmp(self_r, "")
          if self_r == ""
            0
          else
            1
          end
        end
      else
        if (other_r = other.r)
          # LibRPM.rpmvercmp("", other_r)
          if other_r == ""
            0
          else
            -1
          end
        else
          # LibRPM.rpmvercmp("", "")
          0
        end
      end
    end

    def newer?(other : Version)
      self > other
    end

    def older?(other : Version)
      self < other
    end

    # Returns the string represents the version and release.
    def to_vr
      String.build do |str|
        to_vr(str)
      end
    end

    # Send the string represents the version and release, to given IO.
    def to_vr(io)
      io << @v
      if (r = @r)
        io << "-" << r
      end
    end

    # Equivalent to `#to_vre`
    def to_s
      to_vre
    end

    # Equivalent to `#to_vre(io)`
    def to_s(io)
      to_vre(io)
    end

    # Returns the string represents the version, release and epoch if
    # set.
    def to_vre
      String.build do |str|
        to_vre(str)
      end
    end

    # Send the string represents the version, release and epoch if
    # set, to given IO.
    def to_vre(io)
      if (e = @e)
        io << e << ":"
      end
      to_vr(io)
    end

    # Returns the string represents the version, release and epoch
    # where epoch is filled with 0.
    #
    # This method makes a string comparable by single call of
    # `rpmvercomp` function, but it seems to be used for comparing
    # version and release separately, according to usage in RPM
    # itself.
    def to_vre_epoch_zero
      String.build do |str|
        to_vre_epoch_zero(str)
      end
    end

    # Send the string represents the version, release and epoch where
    # epoch is filled with 0, to given IO.
    #
    # This method makes a string comparable by single call of
    # `rpmvercomp` function, but it seems to be used for comparing
    # version and release separately, according to usage in RPM
    # itself.
    def to_vre_epoch_zero(io)
      if (e = @e)
        io << e << ":"
      else
        io << "0:"
      end
      to_vr(io)
    end

    def hash
      e = @e
      h = e ? e.to_u64 : 0_u64
      h = (h << 1) ^ @r.hash
      h = (h << 1) ^ @v.hash
      h
    end
  end
end
