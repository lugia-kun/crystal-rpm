module RPM
  class TagData
    module ReturnTypeModule
      def initialize(@ptr)
      end

      def initialize(other : ReturnTypeBase)
        @ptr = other.@ptr
      end

      def size
        raise NilAssertionError.new if @ptr.null?
        LibRPM.rpmtdCount(@ptr)
      end
    end

    abstract struct ReturnTypeBase
      @ptr : LibRPM::TagData = Pointer(Void).null.as(LibRPM::TagData)

      def detach
        self.class.new(LibRPM.rpmtdFree(@ptr))
      end

      def tag
        Tag.from_value(LibRPM.rpmtdTag(@ptr))
      end

      def type
        LibRPM.rpmtdType(@ptr)
      end

      def detach
        @ptr = LibRPM.rpmtdFree(@ptr)
      end

      # Sets tag value.
      #
      # NOTE: RPM allows to change tag value only to same type.
      #       If not, this method raises `TypeCastError`.
      def tag=(tag : Tag | TagValue)
        if LibRPM.rpmtdSetTag(@ptr, tag) == 0
          raise TypeCastError.new("Incompatible tag value #{tag} for #{self.class}")
        end
        tag
      end

      private def pos=(idx)
        raise NilAssertionError.new if @ptr.null?
        LibRPM.rpmtdSetIndex(@ptr, idx)
      end

      def format1(fmt : TagDataFormat)
        s = LibRPM.rpmtdFormat(@ptr, fmt, nil)
        if s.null?
          raise NilAssertionError.new("rpmtdFormat returned NULL")
        end
        begin
          String.new(s)
        ensure
          LibC.free(s)
        end
      end

      def format(io : IO, fmt : TagDataFormat)
        count = self.size
        if count < 1
          io << "(Empty RPM::TagData)"
        elsif count > 1
          self.pos = 0
          zero = format1(fmt)
          if zero == "(not a blob)"
            io << zero
          else
            io << "[" << zero
            (1...count).each do |i|
              self.pos = i
              io << ", " << format1(fmt)
            end
            io << "]"
          end
        else
          self.pos = 0
          io << format1(fmt)
        end
      end
    end

    abstract struct ReturnType(T) < ReturnTypeBase
      abstract def fetch_ptr : Pointer(T)

      def bytes : Slice(T)
        self.pos = 0
        ptr = fetch_ptr
        if ptr.null?
          raise NilAssertionError.new
        else
          Slice(T).new(ptr, size, read_only: true)
        end
      end

      def to_a : Array(T)
        b = bytes
        Array(T).build(b.size) do |buffer|
          b.copy_to(buffer, b.size)
          b.size
        end
      end

      def unsafe_fetch(idx)
        self.pos = idx
        fetch_ptr.value
      end
    end

    struct ReturnTypeInt8 < ReturnTypeBase
      include Indexable(UInt8)
      include ReturnTypeModule

      def unsafe_fetch(idx)
        self.pos = idx
        LibRPM.rpmtdGetNumber(@ptr).to_u8
      end

      def bytes
        raise TypeCastError.new("Cannot take byte array of UInt8.")
      end

      def fetch_ptr
        raise TypeCastError.new("Cannot fetch pointer of UInt8.")
      end
    end

    struct ReturnTypeInt16 < ReturnType(UInt16)
      include Indexable(UInt16)
      include ReturnTypeModule

      def fetch_ptr
        LibRPM.rpmtdGetUint16(@ptr)
      end

      def bytes
        super
      end
    end

    struct ReturnTypeInt32 < ReturnType(UInt32)
      include Indexable(UInt32)
      include ReturnTypeModule

      def fetch_ptr
        LibRPM.rpmtdGetUint32(@ptr)
      end

      def bytes
        super
      end
    end

    struct ReturnTypeInt64 < ReturnType(UInt64)
      include Indexable(UInt64)
      include ReturnTypeModule

      def fetch_ptr
        LibRPM.rpmtdGetUint64(@ptr)
      end

      def bytes
        super
      end
    end

    struct ReturnTypeString < ReturnTypeBase
      include Indexable(String)
      include ReturnTypeModule

      def unsafe_fetch(idx)
        self.pos = idx
        String.new(LibRPM.rpmtdGetString(@ptr))
      end

      def bytes
        raise TypeCastError.new("Cannot take byte array of string(s).")
      end

      def fetch_ptr
        raise TypeCastError.new("Cannot fetch pointer of string type.")
      end

      # Use `Indexable(String)#to_a` for `#to_a`.
    end

    struct ReturnTypeChar < ReturnTypeBase
      include Indexable(Char)
      include ReturnTypeModule

      def unsafe_fetch(idx)
        self.pos = idx
        LibRPM.rpmtdGetChar(@ptr).value.chr
      end

      def bytes : Slice(UInt8)
        self.pos = 0
        ptr = fetch_ptr
        if ptr.null?
          raise NilAssertionError.new
        else
          Slice(UInt8).new(ptr, size, read_only: true)
        end
      end

      def fetch_ptr
        LibRPM.rpmtdGetChar(@ptr)
      end
    end

    struct ReturnTypeBin < ReturnTypeBase
      include Indexable(Bytes)
      include ReturnTypeModule

      def unsafe_fetch(idx)
        bytes
      end

      private def hex2bin(hex)
        {% begin %}
          case hex
              {% for dec in (0..9) %}
              when '{{dec}}'.ord
                {{dec}}_u8
              {% end %}
              {% for hex, i in ["a", "b", "c", "d", "e", "f"] %}
              when '{{hex.id}}'.ord, '{{hex.upcase.id}}'.ord
                {{i + 10}}_u8
              {% end %}
          else
            raise TypeCastError.new("Invalid codepoint for hexadecimal char: #{hex}")
          end
        {% end %}
      end

      def bytes
        f = format1(TagDataFormat::STRING)
        fsz = f.size // 2
        Bytes.new(fsz) do |i|
          i2 = i * 2
          c1 = f.byte_at(i2)
          c2 = f.byte_at(i2 + 1)
          (hex2bin(c1) << 4) | hex2bin(c2)
        end
      end

      def fetch_ptr
        raise TypeCastError.new("Cannot fetch pointer of binary type.")
      end
    end

    @ptr : ReturnTypeBase

    private def self.for(ptr : LibRPM::TagData)
      type = LibRPM.rpmtdType(ptr)
      r = case type
          when TagType::CHAR
            ReturnTypeChar.new(ptr)
          when TagType::BIN
            ReturnTypeBin.new(ptr)
          when TagType::INT8
            ReturnTypeInt8.new(ptr)
          when TagType::INT16
            ReturnTypeInt16.new(ptr)
          when TagType::INT32
            ReturnTypeInt32.new(ptr)
          when TagType::INT64
            ReturnTypeInt64.new(ptr)
          when TagType::STRING, TagType::STRING_ARRAY
            ReturnTypeString.new(ptr)
          else
            raise NotImplementedError.new("Not supported type")
          end
      new(r)
    end

    def initialize(@ptr)
    end

    private def self.new_ptr
      ptr = LibRPM.rpmtdNew
      if ptr.null?
        raise AllocationError.new("rpmtdNew")
      end
      ptr
    end

    def self.create(&block)
      ptr = new_ptr
      begin
        if yield(ptr) == 0
          raise TypeCastError.new("Failed to set tag data")
        end
      rescue ex : Exception
        LibRPM.rpmtdFree(ptr)
        raise ex
      end
      for(ptr)
    end

    def self.create?(&block)
      ptr = new_ptr
      if yield(ptr) == 0
        LibRPM.rpmtdFree(ptr)
        nil
      else
        for(ptr)
      end
    end

    def self.create(str : String, tag : Tag | TagValue)
      create do |ptr|
        LibRPM.rpmtdFromString(ptr, tag, str)
      end
    end

    def self.create(stra : Array(String), tag : Tag | TagValue)
      data = Array(Pointer(UInt8)).new(stra.size)
      stra.each do |str|
        data << str.to_unsafe
      end
      create do |ptr|
        LibRPM.rpmtdFromStringArray(ptr, tag, data, stra.size)
      end
    end

    def self.create(u8 : UInt8, tag : Tag | TagValue)
      create do |ptr|
        LibRPM.rpmtdFromUint8(ptr, tag, pointerof(u8), 1)
      end
    end

    def self.create(u16 : UInt16, tag : Tag | TagValue)
      create do |ptr|
        LibRPM.rpmtdFromUint16(ptr, tag, pointerof(u16), 1)
      end
    end

    def self.create(u32 : UInt32, tag : Tag | TagValue)
      create do |ptr|
        LibRPM.rpmtdFromUint32(ptr, tag, pointerof(u32), 1)
      end
    end

    def self.create(u64 : UInt64, tag : Tag | TagValue)
      create do |ptr|
        LibRPM.rpmtdFromUint64(ptr, tag, pointerof(u64), 1)
      end
    end

    def self.create(u8a : Array(UInt8) | Bytes, tag : Tag | TagValue)
      create do |ptr|
        LibRPM.rpmtdFromUint8(ptr, tag, u8a, u8a.size)
      end
    end

    def self.create(u16a : Array(UInt16) | Slice(UInt16), tag : Tag | TagValue)
      create do |ptr|
        LibRPM.rpmtdFromUint16(ptr, tag, u16a, u16a.size)
      end
    end

    def self.create(u32a : Array(UInt32) | Slice(UInt32), tag : Tag | TagValue)
      create do |ptr|
        LibRPM.rpmtdFromUint32(ptr, tag, u32a, u32a.size)
      end
    end

    def self.create(u64a : Array(UInt64) | Slice(UInt64), tag : Tag | TagValue)
      create do |ptr|
        LibRPM.rpmtdFromUint64(ptr, tag, u64a, u64a.size)
      end
    end

    # Get tag value
    def tag
      @ptr.tag
    end

    # Sets tag value
    #
    # NOTE: RPM allows to change tag value only to same type.
    #       If not, this method raises `TypeCastError`.
    def tag=(val)
      @ptr.tag = val
    end

    # Returns the type of tag data
    def type
      @ptr.type
    end

    # Returns the return type of tag data
    def return_type
      RPM.tag_get_return_type(tag)
    end

    # Returns the number of elements in tag data
    def size
      @ptr.size
    end

    private def is_array?(type : TagType, count : Int,
                          ret_type : TagReturnType)
      count > 1 || ret_type == TagReturnType::ARRAY ||
        type == TagType::STRING_ARRAY
    end

    # Returns true if tag data is array
    #
    # Returns true if number of elements is greater than 1, the return
    # type is `TagReturnType::ARRAY` or the type is
    # `TagType::STRING_ARRAY`.
    def is_array?
      type = self.type
      count = self.size
      ret_type = self.return_type

      is_array?(type, count, ret_type)
    end

    # Returns the single value of tag data
    #
    # If tag data contains array, raises `TypeCastError`.
    def value_no_array
      type = self.type
      count = self.size
      ret_type = self.return_type

      if count < 1
        raise TypeCastError.new("Empry TagData")
      end

      # BIN is stored in array of UInt8. Treating specially
      if @ptr.is_a?(ReturnTypeBin)
        return @ptr.bytes
      end

      if is_array?(type, count, ret_type)
        raise TypeCastError.new("RPM::TagData is stored in array (has #{count} values)")
      end

      @ptr[0]
    end

    # Returns the single value of tag data
    #
    # If tag data contains array, returns nil.
    def value_no_array?
      value_no_array
    rescue TypeCastError
      nil
    end

    # Returns the value in array.
    #
    # It raises `TypeCastError` if the tag data stores single value
    # only.
    def value_array
      type = self.type
      count = self.size
      ret_type = self.return_type

      if count < 1
        return TypeCastError.new("Empty TagData")
      end

      # BIN is stored in array of UInt8. Treating specially
      if @ptr.is_a?(ReturnTypeBin)
        return @ptr.bytes
      end

      if !is_array?(type, count, ret_type)
        raise TypeCastError.new("RPM::TagData is stored in plain data")
      end

      @ptr.to_a
    end

    # Returns the value in array.
    #
    # It returns nil if the tag data stores single value only.
    def value_array?
      value_array
    rescue TypeCastError
      nil
    end

    # Returns the value.
    def value
      if is_array?
        value_array
      else
        value_no_array
      end
    end

    # Returns the value.
    def value?
      value
    rescue TypeCastError
      nil
    end

    def finalize
      @ptr.detach
    end

    # Returns the value of given array index.
    def [](idx)
      @ptr[idx]
    end

    # Returns the BASE64 representation of tag data.
    #
    # Equivalent to `#format(TagDataFormat::BASE64)`.
    def base64
      format(TagDataFormat::BASE64)
    end

    def to_s(io)
      format(io, TagDataFormat::STRING)
    end

    def to_s
      format(TagDataFormat::STRING)
    end

    # Format a single value of tag data in given tag data format, and
    # return it.
    def format1(fmt : TagDataFormat)
      @ptr.format1(fmt)
    end

    # Format tag data in given tag data format, and send to given `io`
    def format(io : IO, fmt : TagDataFormat) : Void
      @ptr.format(io, fmt)
    end

    # Format tag data in given tag data format, and returns it.
    def format(fmt : TagDataFormat) : String
      String.build do |str|
        @ptr.format(str, fmt)
      end
    end

    # Forces return type to given return type.
    #
    # Returns old ReturnType class.
    #
    # CHAR (`ReturnTypeChar`), INT8 (`ReturnTypeUInt8`) are
    # interoperable. Otherwise, it may cause unexpected behavior.
    def force_return_type!(type : ReturnTypeBase.class)
      cls = @ptr.class
      @ptr = type.new(@ptr)
      cls
    end
  end
end
