module RPM
  class SourceBase
    property fullname : String
    property number : Int32
    property? no

    def initialize(@fullname, @number, @no = false)
    end

    def to_s
      @fullname
    end

    def filename
      ::File.basename(@fullname)
    end
  end

  class Source < SourceBase
  end

  class Patch < SourceBase
  end

  class Icon < SourceBase
  end
end
