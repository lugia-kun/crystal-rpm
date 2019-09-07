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
        epoch = Int32.new(version[0..(idx - 1)])
        version = version[(idx + 1)..-1]
      end

      {epoch, version, release}
    end

    getter e : Int32?
    getter v : String
    getter r : String?

    def initialize(str : String)
      @e, @v, @r = Version.parse_evr(str)
    end

    def initialize(str : String, epoch : Int)
      e, @v, @r = Version.parse_evr(str)
      @e = epoch.to_i32
    end

    def initialize(@v : String, @r : String, epoch : Int? = nil)
      if epoch
        @e = epoch.to_i32
      else
        @e = nil
      end
    end

    def <=>(other : Version)
      LibRPM.rpmvercmp(to_vre_epoch_zero, other.to_vre_epoch_zero)
    end

    def newer?(other : Version)
      self > other
    end

    def older?(other : Version)
      self < other
    end

    def to_vr
      @r.nil? ? @v.dup : "#{@v}-#{@r}"
    end

    def to_s
      to_vr
    end

    def to_vre
      vr = to_vr
      @e.nil? ? vr : "#{@e}:#{vr}"
    end

    def to_vre_epoch_zero
      vr = to_vr
      @e.nil? ? "0:#{vr}" : "#{@e}:#{vr}"
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
