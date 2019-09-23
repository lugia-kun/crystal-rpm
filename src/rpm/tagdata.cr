module RPM
  # Stores one RPM TagData.
  class TagData
    # Handy module to define methods in `ReturnType` classes.
    module ReturnTypeModule
      # :nodoc:
      #
      # `struct`s cannot be inherited without `abstract`.
      # So we provides initialize method for each `struct`.
      def initialize(@ptr)
      end

      # :nodoc:
      #
      # Copy constructor.
      def initialize(other : ReturnTypeBase)
        @ptr = other.@ptr
      end

      # Returns the number of elements in the tagdata.
      #
      # This method is not type-dependent, but `Indexable` module
      # requires that `#size` method must be defined **after** the
      # inclusion of the module.
      def size
        raise NilAssertionError.new if @ptr.null?
        LibRPM.rpmtdCount(@ptr)
      end
    end

    # Base class of `ReturnType` classes.
    abstract struct ReturnTypeBase
      @ptr : LibRPM::TagData = Pointer(Void).null.as(LibRPM::TagData)

      # Returns the tag value.
      def tag
        Tag.from_value(LibRPM.rpmtdTag(@ptr))
      end

      # Returns the type of TagData
      def type
        LibRPM.rpmtdType(@ptr)
      end

      # Deallocates the tagdata.
      #
      # This method modifies `self`.
      def detach
        @ptr = LibRPM.rpmtdFree(@ptr)
      end

      # Sets tag value.
      #
      # NOTE: RPM allows to change tag value only to same type. If
      # not, this method raises `TypeCastError`.
      def tag=(tag : Tag | TagValue)
        if LibRPM.rpmtdSetTag(@ptr, tag) == 0
          type = LibRPM.rpmtdType(@ptr)
          raise TypeCastError.new("Incompatible tag value #{tag} for #{type}")
        end
        tag
      end

      # Set current index of TagData.
      private def pos=(idx)
        raise NilAssertionError.new if @ptr.null?
        LibRPM.rpmtdSetIndex(@ptr, idx)
      end

      # Format the TagData at current index in given format.
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

      # Format the TagData to a string also represents array and empty
      # TagData, and send to given IO.
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

    # Generic ReturnType class for integral types.
    abstract struct ReturnType(T) < ReturnTypeBase
      # We needs a method to get pointer data.
      abstract def fetch_ptr : Pointer(T)

      # Returns binary raw array of expecting type.
      #
      # Raises `NilAssertionError` if `#fetch_ptr` returns `NULL`.
      def bytes : Slice(T)
        bytes?.not_nil!
      end

      # Returns binary raw array of expecting type.
      #
      # Returns `nil` if `#fetch_ptr` returns `NULL`.
      def bytes? : Slice(T)?
        self.pos = 0
        ptr = fetch_ptr
        if ptr.null?
          nil
        else
          Slice(T).new(ptr, size, read_only: true)
        end
      end

      # Returns the array of values using `#bytes`
      #
      # This may be faster than `Indexable#to_a` (via
      # `Enumerable#to_a`).
      def to_a_from_bytes : Array(T)
        b = bytes?
        if b
          Array(T).build(b.size) do |buffer|
            b.copy_to(buffer, b.size)
            b.size
          end
        else
          [] of T
        end
      end

      # :nodoc:
      def unsafe_fetch(idx)
        self.pos = idx
        fetch_ptr.value
      end
    end

    # UInt8 type for TagData
    #
    # RPM does not support obtaining the pointer of UInt8 array.
    # (`rpmtdGetChar` returns pointer only for `CHAR` typed tags.
    #  Note that this property won't change even if you use
    #  `TagData#force_return_type!`)
    struct ReturnTypeInt8 < ReturnTypeBase
      include Indexable(UInt8)
      include ReturnTypeModule

      # :nodoc:
      def unsafe_fetch(idx)
        self.pos = idx
        LibRPM.rpmtdGetNumber(@ptr).to_u8
      end

      # :nodoc:
      def bytes
        raise TypeCastError.new("Cannot take byte array of UInt8")
      end
    end

    # UInt16 type for TagData
    struct ReturnTypeInt16 < ReturnType(UInt16)
      include Indexable(UInt16)
      include ReturnTypeModule

      # :nodoc:
      def fetch_ptr : Pointer(UInt16)
        LibRPM.rpmtdGetUint16(@ptr)
      end

      # :nodoc:
      def bytes
        super
      end

      # :nodoc:
      def to_a
        to_a_from_bytes
      end
    end

    # UInt32 type for TagData
    struct ReturnTypeInt32 < ReturnType(UInt32)
      include Indexable(UInt32)
      include ReturnTypeModule

      # :nodoc:
      def fetch_ptr : Pointer(UInt32)
        LibRPM.rpmtdGetUint32(@ptr)
      end

      # :nodoc:
      def bytes
        super
      end

      # :nodoc:
      def to_a
        to_a_from_bytes
      end
    end

    # UInt64 type for TagData
    struct ReturnTypeInt64 < ReturnType(UInt64)
      include Indexable(UInt64)
      include ReturnTypeModule

      # :nodoc:
      def fetch_ptr : Pointer(UInt64)
        LibRPM.rpmtdGetUint64(@ptr)
      end

      # :nodoc:
      def bytes
        super
      end

      # :nodoc:
      def to_a
        to_a_from_bytes
      end
    end

    # String and array of String type for TagData
    struct ReturnTypeString < ReturnTypeBase
      include Indexable(String)
      include ReturnTypeModule

      # :nodoc:
      def unsafe_fetch(idx)
        self.pos = idx
        str = LibRPM.rpmtdGetString(@ptr)
        if str.null?
          raise NilAssertionError.new("rpmtdGetString returned NULL (type mismatch?)")
        else
          String.new(str)
        end
      end

      # :nodoc:
      def bytes
        raise TypeCastError.new("Cannot take byte array of string(s)")
      end
    end

    # Char type for TagData
    #
    # NOTE: Some RPM tags use this type for enum types (integral
    # type). Because this class converts values to `Char`, If you want
    # integral type, you may want to read them like `UInt8` using
    # `TagData#force_return_type!`
    struct ReturnTypeChar < ReturnTypeBase
      include Indexable(Char)
      include ReturnTypeModule

      # :nodoc:
      def unsafe_fetch(idx)
        self.pos = idx
        LibRPM.rpmtdGetChar(@ptr).value.chr
      end

      # :nodoc:
      def bytes : Slice(UInt8)
        self.pos = 0
        ptr = fetch_ptr
        if ptr.null?
          raise NilAssertionError.new
        else
          Slice(UInt8).new(ptr, size, read_only: true)
        end
      end

      # :nodoc:
      def fetch_ptr : Pointer(UInt8)
        LibRPM.rpmtdGetChar(@ptr)
      end
    end

    # Binary type for TagData
    #
    # NOTE: The raw representation of binary data a same to array of
    # UInt8, but same reason to UInt8, we cannot obtain it directly.
    struct ReturnTypeBin < ReturnTypeBase
      include Indexable(Bytes)
      include ReturnTypeModule

      # :nodoc:
      def unsafe_fetch(idx)
        bytes
      end

      # Converts hexadecimal character to integral value.
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

      # Generates binary data from hexadecimal string representation.
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
    end

    @ptr : ReturnTypeBase

    # Sets `ReturnType` class to work with associated tag, and new
    # wrapped `TagData` class, for given pointer.
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

    # :nodoc:
    #
    # Use `.create` methods.
    def initialize(@ptr)
    end

    # Creates a new TagData pointer.
    #
    # Raises `RPM::AllocationError` if upstream API returns `NULL`.
    private def self.new_ptr
      ptr = LibRPM.rpmtdNew
      if ptr.null?
        raise AllocationError.new("rpmtdNew")
      end
      ptr
    end

    # Create a new tagdata with initializing it with given block.
    #
    # This method is primitive method. Passed argument is raw value of
    # `rpmtd` (actually a pointer).
    #
    # If given block returns `0`, it will be treated as failure to set
    # tagdata, and raises `TypeCastError`. You can raise another class
    # of `Exception` in the block if you want to do so.
    def self.create(&block)
      ptr = new_ptr
      begin
        if yield(ptr) == 0
          raise TypeCastError.new("Failed to set TagData")
        end
      rescue ex : Exception
        LibRPM.rpmtdFree(ptr)
        raise ex
      end
      for(ptr)
    end

    # Create a new tagdata with initializing it with given block.
    #
    # This method is primitive method. Passed argument is raw value of
    # `rpmtd` (actually a pointer).
    #
    # If given block returns `0`, it will be treated as failure to set
    # tagdata, and returns `nil`. You can **NOT** raise an exception in
    # the block, or make sure to rescue them.
    def self.create?(&block)
      ptr = new_ptr
      if yield(ptr) == 0
        LibRPM.rpmtdFree(ptr)
        nil
      else
        for(ptr)
      end
    end

    # Creates a new tagdata which stores given string.
    def self.create(str : String, tag : Tag | TagValue)
      create do |ptr|
        LibRPM.rpmtdFromString(ptr, tag, str)
      end
    end

    # Creates a new tagdata which stores given array of strings.
    def self.create(stra : Array(String), tag : Tag | TagValue)
      data = Array(Pointer(UInt8)).new(stra.size) do |i|
        stra[i].to_unsafe
      end
      create do |ptr|
        LibRPM.rpmtdFromStringArray(ptr, tag, data, stra.size)
      end
    end

    # Creates a new tagdata which stores given UInt8 value.
    def self.create(u8 : UInt8, tag : Tag | TagValue)
      create do |ptr|
        LibRPM.rpmtdFromUint8(ptr, tag, pointerof(u8), 1)
      end
    end

    # Creates a new tagdata which stores given UInt16 value.
    def self.create(u16 : UInt16, tag : Tag | TagValue)
      create do |ptr|
        LibRPM.rpmtdFromUint16(ptr, tag, pointerof(u16), 1)
      end
    end

    # Creates a new tagdata which stores given UInt32 value.
    def self.create(u32 : UInt32, tag : Tag | TagValue)
      create do |ptr|
        LibRPM.rpmtdFromUint32(ptr, tag, pointerof(u32), 1)
      end
    end

    # Creates a new tagdata which stores given UInt64 value.
    def self.create(u64 : UInt64, tag : Tag | TagValue)
      create do |ptr|
        LibRPM.rpmtdFromUint64(ptr, tag, pointerof(u64), 1)
      end
    end

    # Creates a new tagdata which stores given array of UInt8 values.
    def self.create(u8a : Array(UInt8) | Bytes, tag : Tag | TagValue)
      create do |ptr|
        LibRPM.rpmtdFromUint8(ptr, tag, u8a, u8a.size)
      end
    end

    # Creates a new tagdata which stores given array of UInt16 values.
    def self.create(u16a : Array(UInt16) | Slice(UInt16), tag : Tag | TagValue)
      create do |ptr|
        LibRPM.rpmtdFromUint16(ptr, tag, u16a, u16a.size)
      end
    end

    # Creates a new tagdata which stores given array of UInt32 values.
    def self.create(u32a : Array(UInt32) | Slice(UInt32), tag : Tag | TagValue)
      create do |ptr|
        LibRPM.rpmtdFromUint32(ptr, tag, u32a, u32a.size)
      end
    end

    # Creates a new tagdata which stores given array of UInt64 values.
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
    # NOTE: RPM allows to change tag value only to same type. If not,
    # this method raises `TypeCastError`.
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
    # type is `TagReturnType::ARRAY`, or the type is
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
    # If tag data is not set, raises `IndexError` (because this
    # methods just get the value at index 0).
    def value_no_array
      # BIN is stored in array of UInt8. Treating specially
      if @ptr.is_a?(ReturnTypeBin)
        return @ptr.bytes
      end

      if is_array?
        raise TypeCastError.new("RPM::TagData is stored in array")
      end

      @ptr[0]
    end

    # Returns the single value of tag data
    #
    # If tag data contains array or not set, returns nil.
    def value_no_array?
      # BIN is stored in array of UInt8. Treating specially
      if @ptr.is_a?(ReturnTypeBin)
        return @ptr.bytes
      end

      if is_array?
        return nil
      end

      @ptr[0]?
    end

    # Returns the value in array.
    #
    # It raises `TypeCastError` if the tag data stores single value
    # only.
    def value_array
      # BIN is stored in array of UInt8. Treating specially
      if @ptr.is_a?(ReturnTypeBin)
        return @ptr.bytes
      end

      if !is_array?
        raise TypeCastError.new("RPM::TagData stores non-array data")
      end

      @ptr.to_a
    end

    # Returns the value in array.
    #
    # It returns nil if the tag data stores single value only.
    def value_array?
      if @ptr.is_a?(ReturnTypeBin)
        return @ptr.bytes
      end

      if !is_array?
        return nil
      end

      @ptr.to_a
    end

    # Returns the value.
    def value
      if @ptr.is_a?(ReturnTypeBin)
        return @ptr.bytes
      end

      if is_array?
        @ptr.to_a
      else
        @ptr[0]
      end
    end

    # Returns the value.
    def value?
      if @ptr.is_a?(ReturnTypeBin)
        return @ptr.bytes
      end

      if is_array?
        @ptr.to_a
      else
        @ptr[0]?
      end
    end

    def finalize
      @ptr.detach
    end

    # Returns the value of given array index.
    #
    # Raises IndexError if `idx` is out-of-range.
    def [](idx)
      @ptr[idx]
    end

    # Returns the value of given array index.
    #
    # Returns `nil` if `idx` is out-of-range.
    def []?(idx)
      @ptr[idx]?
    end

    # Returns the BASE64 representation of tag data.
    #
    # Equivalent to `#format(TagDataFormat::BASE64)`.
    def base64
      format(TagDataFormat::BASE64)
    end

    # Returns raw binary data of TagData
    #
    # Some types do not suitable for getting binary data. If so, this
    # method raises `TypeCastError`.
    def bytes
      @ptr.bytes
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
    # interoperable (except for `#bytes`). Otherwise, it may cause
    # unexpected behavior.
    def force_return_type!(type : ReturnTypeBase.class)
      cls = @ptr.class
      @ptr = type.new(@ptr)
      cls
    end

    # Returns pointer to `rpmtd` to deal with librpm C API directly.
    def to_unsafe
      @ptr.to_unsafe
    end
  end
end
