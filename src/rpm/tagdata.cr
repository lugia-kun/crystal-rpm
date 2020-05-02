module RPM
  # Stores one RPM TagData.
  #
  # There are multiple similar methods available for getting value(s).
  #
  # * `#value` returns a value for non-array tag, an array for array tag,
  #   and a slice for binary tag.
  # * `#value_no_array` returns a value for non-array tag and a slice
  #   for binary tags, but raises an exception for array tag.
  # * `#value_array` returns an array for array tag and a slice for
  #   binary tags, but raises an exception for non-array tag.
  # * `#to_a` returns an array for both non-array and array tags, and
  #   an array of single slice for binary tag.
  # * `#[]` can be used for getting value at specific index for array tag,
  #   but `td[0]` is also available for non-array and binary tag.
  # * `#value?` `#value_no_array?` `#value_array?` `#[]?` returns
  #   `nil` instead of raising an exception.
  class TagData
    # Handy module to define methods in `ReturnType` classes.
    module ReturnTypeModule
      # :nodoc:
      #
      # `struct`s cannot be inherited without `abstract`.
      # So we provides initialize method for each `struct`.
      def initialize(@ptr, @deleter)
      end

      # :nodoc:
      #
      # Copy constructor.
      def initialize(other : ReturnTypeBase)
        @ptr = other.@ptr
        @deleter = other.@deleter
      end
    end

    # Base class of `ReturnType` classes.
    abstract struct ReturnTypeBase
      @ptr : LibRPM::TagData = Pointer(Void).null.as(LibRPM::TagData)
      @deleter : Proc(Void)? = nil

      # Respond to `Indexable#unsafe_fetch`
      abstract def unsafe_fetch(index : Int)

      # Respond to `Indexable#size`
      abstract def size

      # Respond to `Indexable#to_a`
      abstract def to_a

      # Returns the tag value.
      def tag
        Tag.from_value(LibRPM.rpmtdTag(@ptr))
      end

      # Returns the type of TagData
      def type
        RPM.rpmtd_type(@ptr)
      end

      # Returns the return type pf TagData
      def return_type
        RPM.tag_get_return_type(LibRPM.rpmtdTag(@ptr))
      end

      # Deallocates the tagdata.
      #
      # This method modifies `self`.
      def detach
        # We cannot create a `rpmtd` whose data is going to be freed
        # by librpm side. This is why we added `@deleter`. If `@ptr`
        # is created by `rpmtdDup` (or maybe some other methods),
        # `rpmtdFreeData` deallocates allocated data by them.
        unless @ptr.null?
          LibRPM.rpmtdFreeData(@ptr)
        end
        @ptr = LibRPM.rpmtdFree(@ptr)
        if (deleter = @deleter)
          deleter.call
        end
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
      #
      # Raises IndexError for invalid index
      private def pos=(idx)
        raise NilAssertionError.new if @ptr.null?
        ret = LibRPM.rpmtdSetIndex(@ptr, idx)
        if ret < 0
          raise IndexError.new
        end
        idx
      end

      # Format the TagData at current index in given format.
      def format(index : Int, fmt : TagDataFormat)
        self.pos = index
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

      # `#format` and write to IO
      def format(io : IO, index : Int, fmt : TagDataFormat)
        io << format(index, fmt)
      end

      # Format the TagData to a string also represents array and empty
      # TagData, and send to given IO.
      def format(io : IO, fmt : TagDataFormat)
        count = self.size
        if count < 1
          io << "(Empty RPM::TagData)"
        elsif count > 1
          zero = format(0, fmt)
          if zero == "(not a blob)"
            io << zero
          else
            io << "[" << zero
            (1...count).each do |i|
              io << ", "
              format(io, i, fmt)
            end
            io << "]"
          end
        else
          format(io, 0, fmt)
        end
      end

      def to_unsafe
        @ptr
      end

      # Returns the number of elements in the tagdata.
      def size
        raise NilAssertionError.new if @ptr.null?
        LibRPM.rpmtdCount(@ptr)
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
        if self.size < 1
          nil
        else
          self.pos = 0
          ptr = fetch_ptr
          if ptr.null?
            nil
          else
            Slice(T).new(ptr, size, read_only: true)
          end
        end
      end

      # Returns the array of values using `#bytes`
      #
      # This may be faster than `Indexable#to_a`
      def to_a : Array(T)
        if (b = bytes?)
          Array(T).build(b.size) do |buffer|
            b.copy_to(buffer, b.size)
            b.size
          end
        else
          [] of T
        end
      end

      # :nodoc:
      def unsafe_fetch(index : Int) : T
        self.pos = index
        fetch_ptr.value
      end
    end

    # UInt8 type for TagData
    struct ReturnTypeInt8 < ReturnTypeBase
      include ReturnTypeModule

      # :nodoc:
      def unsafe_fetch(index : Int)
        self.pos = index
        LibRPM.rpmtdGetNumber(@ptr).to_u8
      end

      # :nodoc:
      def bytes
        Bytes.new(size.to_i32) do |idx|
          unsafe_fetch(idx)
        end
      end

      def to_a
        Array(UInt8).new(size) do |idx|
          unsafe_fetch(idx)
        end
      end
    end

    # UInt16 type for TagData
    struct ReturnTypeInt16 < ReturnType(UInt16)
      include ReturnTypeModule

      # :nodoc:
      def fetch_ptr : Pointer(UInt16)
        LibRPM.rpmtdGetUint16(@ptr)
      end

      def unsafe_fetch(index : Int)
        super
      end

      def to_a
        super
      end

      def bytes?
        super
      end

      def bytes
        super
      end
    end

    # UInt32 type for TagData
    struct ReturnTypeInt32 < ReturnType(UInt32)
      include ReturnTypeModule

      # :nodoc:
      def fetch_ptr : Pointer(UInt32)
        LibRPM.rpmtdGetUint32(@ptr)
      end

      def unsafe_fetch(index : Int)
        super
      end

      def to_a
        super
      end

      def bytes?
        super
      end

      def bytes
        super
      end
    end

    # UInt64 type for TagData
    struct ReturnTypeInt64 < ReturnType(UInt64)
      include ReturnTypeModule

      # :nodoc:
      def fetch_ptr : Pointer(UInt64)
        LibRPM.rpmtdGetUint64(@ptr)
      end

      def unsafe_fetch(index : Int)
        super
      end

      def to_a
        super
      end

      def bytes?
        super
      end

      def bytes
        super
      end
    end

    # String and array of String type for TagData
    struct ReturnTypeString < ReturnTypeBase
      include ReturnTypeModule

      # :nodoc:
      def unsafe_fetch(index : Int)
        self.pos = index
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

      def to_a : Array(String)
        Array.new(size) do |idx|
          unsafe_fetch(idx)
        end
      end
    end

    # Char type for TagData
    #
    # NOTE: Some RPM tags use this type for enum types (integral
    # type). Because this class converts values to `Char`, If you want
    # integral type, you may want to read them like `UInt8` using
    # `TagData#force_return_type!`
    struct ReturnTypeChar < ReturnTypeBase
      include ReturnTypeModule

      # :nodoc:
      def unsafe_fetch(index : Int)
        self.pos = index
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
        self.pos = 0
        LibRPM.rpmtdGetChar(@ptr)
      end

      def to_a
        bytes.to_a
      end
    end

    # Binary type for TagData
    #
    # NOTE: The raw representation of binary data is same to array of
    # UInt8. RPM does not provide a way to obtain the pointer directly,
    # and we need to convert back from string representation.
    struct ReturnTypeBin < ReturnTypeBase
      include ReturnTypeModule

      # :nodoc:
      def unsafe_fetch(index : Int)
        if (b = bytes?)
          b
        else
          raise IndexError.new("Could not obtain BIN data")
        end
      end

      # `rpmtdCount` should always returns 1 too.
      def size
        1
      end

      private def hexch2bin(ch) : UInt32?
        case ch
        when '0'
          0x0_u32
        when '1'
          0x1_u32
        when '2'
          0x2_u32
        when '3'
          0x3_u32
        when '4'
          0x4_u32
        when '5'
          0x5_u32
        when '6'
          0x6_u32
        when '7'
          0x7_u32
        when '8'
          0x8_u32
        when '9'
          0x9_u32
        when 'a', 'A'
          0xA_u32
        when 'b', 'B'
          0xB_u32
        when 'c', 'C'
          0xC_u32
        when 'd', 'D'
          0xD_u32
        when 'e', 'E'
          0xE_u32
        when 'f', 'F'
          0xF_u32
        else
          nil
        end
      end

      # Generates binary data from hexadecimal string representation.
      #
      # Returns `nil` if the string representation is not valid.
      #
      # NOTE: The type will be ignored. So if a string data consists
      #       of hexadecimal characters (ex: `aa`), it will convert to
      #       binary (here `Bytes[0xaa]` will be returned).
      #
      # NOTE: This method is intended to use for `TagType::BIN` data.
      #       So `0x` or `0X` prefix is prohibited, which never be
      #       appeared for `TagType::BIN` data.
      def bytes? : Bytes?
        bytes { nil }
      end

      # Generates binary data from hexadecimal string representation.
      #
      # Yield block if the string representations contains error.
      #
      # * First block argument is always converted string.
      # * If the string length reported by upstream API is odd,
      #   both Char arguments are nil.
      # * Otherwise two `Char`s will be each slice of the string,
      #   but second Char can be nil if it is '\0'.
      #
      # Returns the result of block if error.
      #
      # NOTE: The type will be ignored. So if a string data consists
      #       of hexadecimal characters (ex: `aa`), it will convert to
      #       binary (here `Bytes[0xaa]` will be returned).
      #
      # NOTE: This method is intended to use for `TagType::BIN` data.
      #       So `0x` or `0X` prefix is prohibited, which never be
      #       appeared for `TagType::BIN` data.
      def bytes(&block : (String, Char?, Char?) -> _)
        f = format(0, TagDataFormat::STRING)
        if (fsz = f.size) % 2 != 0
          return yield(f, nil, nil)
        end
        fsz //= 2
        reader = Char::Reader.new(f)
        b = Bytes.new(fsz)
        i = 0
        ch1 = reader.current_char
        if ch1 != '\0'
          while true
            v1 = hexch2bin(ch1)
            ch2 = reader.next_char
            if ch2 == '\0'
              return yield(f, ch1, nil)
            end
            v2 = hexch2bin(ch2)
            if v1 && v2
              b[i] = ((v1 << 4) | v2).to_u8
              i += 1
            else
              return yield(f, ch1, ch2)
            end
            ch1 = reader.next_char
            break if ch1 == '\0'
          end
        end
        b
      end

      # Generates binary data from hexadecimal string representation.
      #
      # Raises `IndexError` if the length of the string is an odd
      # number.
      #
      # Raises `TypeCastError` if the string contains non-hexadecimal
      # character
      #
      # NOTE: The type will be ignored. So if a string data consists
      #       of hexadecimal characters (ex: `aa`), it will convert to
      #       binary (here `Bytes[0xaa]` will be returned).
      #
      # NOTE: This method is intended to use for `TagType::BIN` data.
      #       So `0x` or `0X` prefix is prohibited, which never be
      #       appeared for `TagType::BIN` data.
      def bytes
        bytes do |str, a, b|
          if b
            raise TypeCastError.new("Invalid hexadecimal character found in string representation of RPM::TagData #{str.inspect}")
          else
            raise IndexError.new("Length of the string representation of RPM::tagData is odd #{str.inspect} (#{str.size})")
          end
        end
      end

      def to_a : Array(Bytes)
        if b = bytes?
          [b]
        else
          [] of Bytes
        end
      end
    end

    # Union of ReturnTypes
    alias ReturnTypeUnion = UInt8 | UInt16 | UInt32 | UInt64 | String | Char | Bytes

    include Indexable(ReturnTypeUnion)

    @ptr : ReturnTypeBase

    # Sets `ReturnType` class to work with associated tag, and new
    # wrapped `TagData` class, for given pointer.
    private def self.for(ptr : LibRPM::TagData, deleter)
      r = case RPM.rpmtd_type(ptr)
          when TagType::CHAR
            ReturnTypeChar.new(ptr, deleter)
          when TagType::BIN
            ReturnTypeBin.new(ptr, deleter)
          when TagType::INT8
            ReturnTypeInt8.new(ptr, deleter)
          when TagType::INT16
            ReturnTypeInt16.new(ptr, deleter)
          when TagType::INT32
            ReturnTypeInt32.new(ptr, deleter)
          when TagType::INT64
            ReturnTypeInt64.new(ptr, deleter)
          when TagType::STRING, TagType::STRING_ARRAY
            ReturnTypeString.new(ptr, deleter)
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
    def self.create(deleter = nil, &block)
      ptr = new_ptr
      begin
        if yield(ptr) == 0
          raise TypeCastError.new("Failed to set TagData")
        end
      rescue ex : Exception
        LibRPM.rpmtdFree(ptr)
        raise ex
      end
      for(ptr, deleter)
    end

    # Create a new tagdata with initializing it with given block.
    #
    # This method is primitive method. Passed argument is raw value of
    # `rpmtd` (actually a pointer).
    #
    # If given block returns `0`, it will be treated as failure to set
    # tagdata, and returns `nil`. You can **NOT** raise an exception in
    # the block, or make sure to rescue them.
    def self.create?(deleter = nil, &block)
      ptr = new_ptr
      if yield(ptr) == 0
        LibRPM.rpmtdFree(ptr)
        nil
      else
        for(ptr, deleter)
      end
    end

    # Creates a new tagdata which stores given string.
    def self.create(str : String, tag : Tag | TagValue)
      type = RPM.tag_type(tag)
      if type == TagType::STRING_ARRAY
        # `rpmtdFromString` takes the address of given pointer for
        # STRING_ARRAY type. The region of it would be stack for the
        # following (non-STRING_ARRAY) code, and it may be overwritten.
        self.create([str], tag)
      else
        bsz = str.bytesize
        strptr = Pointer(UInt8).malloc(bsz + 1)
        strptr.copy_from(str.to_unsafe, bsz + 1)
        create(->{ strptr = Pointer(UInt8).null }) do |ptr|
          LibRPM.rpmtdFromString(ptr, tag, strptr)
        end
      end
    end

    # Creates a new tagdata which stores given array of strings.
    def self.create(stra : Array(String), tag : Tag | TagValue)
      if stra.empty?
        create do |ptr|
          # Document in RPM does not document this method well, but
          # according to the source code (of rpm 4.15.1), creating
          # 0 sized TagData will always fail.
          LibRPM.rpmtdFromStringArray(ptr, tag, Pointer(Pointer(UInt8)).null, 0)
        end
      else
        bszs = Array(UInt64).new(stra.size) do |i|
          stra[i].bytesize.to_u64 + 1
        end
        bsz = bszs.reduce { |a, b| a + b }
        buf = Pointer(UInt8).malloc(bsz)
        io = IO::Memory.new(Slice.new(buf, bsz))
        ptra = Pointer(Pointer(UInt8)).malloc(stra.size)
        i = 0
        stra.each do |str|
          ptra[i] = buf + io.pos
          io.print(str)
          io.print('\0')
          io.flush
          i += 1
        end
        create(->{ buf = Pointer(UInt8).null; ptra = Pointer(Pointer(UInt8)).null }) do |ptr|
          LibRPM.rpmtdFromStringArray(ptr, tag, ptra, stra.size)
        end
      end
    end

    # Creates a new tagdata which stores given UInt8 value.
    def self.create(u8 : UInt8, tag : Tag | TagValue)
      u8p = Pointer(UInt8).malloc(1)
      u8p[0] = u8
      create(->{ u8p = Pointer(UInt8).null }) do |ptr|
        LibRPM.rpmtdFromUint8(ptr, tag, u8p, 1)
      end
    end

    # Creates a new tagdata which stores given UInt16 value.
    def self.create(u16 : UInt16, tag : Tag | TagValue)
      u16p = Pointer(UInt16).malloc(1)
      u16p[0] = u16
      create(->{ u16p = Pointer(UInt16).null }) do |ptr|
        LibRPM.rpmtdFromUint16(ptr, tag, u16p, 1)
      end
    end

    # Creates a new tagdata which stores given UInt32 value.
    def self.create(u32 : UInt32, tag : Tag | TagValue)
      u32p = Pointer(UInt32).malloc(1)
      u32p[0] = u32
      create(->{ u32p }) do |ptr|
        LibRPM.rpmtdFromUint32(ptr, tag, u32p, 1)
      end
    end

    # Creates a new tagdata which stores given UInt64 value.
    def self.create(u64 : UInt64, tag : Tag | TagValue)
      u64p = Pointer(UInt64).malloc(1)
      u64p[0] = u64
      create(->{ u64p }) do |ptr|
        LibRPM.rpmtdFromUint64(ptr, tag, u64p, 1)
      end
    end

    # Creates a new tagdata which stores given array of UInt8 values.
    #
    # If `copy` is `false`, the content of `u8a` will become a part of
    # TagData. Though `u8a` will be kept until the `TagData` is
    # garbage-collected, modifying it will also modifies the content
    # of `TagData`.
    def self.create(u8a : Array(UInt8) | Bytes, tag : Tag | TagValue, copy : Bool = true)
      if copy
        u8p = Pointer(UInt8).malloc(u8a.size)
        if u8a.is_a?(Bytes)
          u8a.copy_to(u8p, u8a.size)
        else
          u8a.each_with_index do |u8, i|
            u8p[i] = u8
          end
        end
        create(->{ u8p = Pointer(UInt8).null }) do |ptr|
          LibRPM.rpmtdFromUint8(ptr, tag, u8p, u8a.size)
        end
      else
        create(->{ u8a }) do |ptr|
          LibRPM.rpmtdFromUint8(ptr, tag, u8a, u8a.size)
        end
      end
    end

    # Creates a new tagdata which stores given array of UInt16 values.
    #
    # If `copy` is `false`, the content of `u8a` will become a part of
    # TagData. Though `u8a` will be kept until the `TagData` is
    # garbage-collected, modifying it will also modifies the content
    # of `TagData`.
    def self.create(u16a : Array(UInt16) | Slice(UInt16), tag : Tag | TagValue, copy : Bool = true)
      if copy
        u16p = Pointer(UInt16).malloc(u16a.size)
        if u16a.is_a?(Slice(UInt16))
          u16a.copy_to(u16p, u16a.size)
        else
          u16a.each_with_index do |u16, i|
            u16p[i] = u16
          end
        end
        create(->{ u16p = Pointer(UInt16).null }) do |ptr|
          LibRPM.rpmtdFromUint16(ptr, tag, u16p, u16a.size)
        end
      else
        create(->{ u16a }) do |ptr|
          LibRPM.rpmtdFromUint16(ptr, tag, u16a, u16a.size)
        end
      end
    end

    # Creates a new tagdata which stores given array of UInt32 values.
    #
    # If `copy` is `false`, the content of `u8a` will become a part of
    # TagData. Though `u8a` will be kept until the `TagData` is
    # garbage-collected, modifying it will also modifies the content
    # of `TagData`.
    def self.create(u32a : Array(UInt32) | Slice(UInt32), tag : Tag | TagValue, copy : Bool = true)
      if copy
        u32p = Pointer(UInt32).malloc(u32a.size)
        if u32a.is_a?(Slice(UInt32))
          u32a.copy_to(u32p, u32a.size)
        else
          u32a.each_with_index do |u32, i|
            u32p[i] = u32
          end
        end
        create(->{ u32p = Pointer(UInt32).null }) do |ptr|
          LibRPM.rpmtdFromUint32(ptr, tag, u32p, u32a.size)
        end
      else
        create(->{ u32a }) do |ptr|
          LibRPM.rpmtdFromUint32(ptr, tag, u32a, u32a.size)
        end
      end
    end

    # Creates a new tagdata which stores given array of UInt64 values.
    #
    # If `copy` is `false`, the content of `u8a` will become a part of
    # TagData. Though `u8a` will be kept until the `TagData` is
    # garbage-collected, modifying it will also modifies the content
    # of `TagData`.
    def self.create(u64a : Array(UInt64) | Slice(UInt64), tag : Tag | TagValue, copy : Bool = true)
      if copy
        u64p = Pointer(UInt64).malloc(u64a.size)
        if u64a.is_a?(Slice(UInt64))
          u64a.copy_to(u64p, u64a.size)
        else
          u64a.each_with_index do |u64, i|
            u64p[i] = u64
          end
        end
        create(->{ u64p = Pointer(UInt64).null }) do |ptr|
          LibRPM.rpmtdFromUint64(ptr, tag, u64p, u64a.size)
        end
      else
        create(->{ u64a }) do |ptr|
          LibRPM.rpmtdFromUint64(ptr, tag, u64a, u64a.size)
        end
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
      @ptr.return_type
    end

    def unsafe_fetch(index : Int)
      @ptr.unsafe_fetch(index)
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
      if (ptr = @ptr).is_a?(ReturnTypeBin)
        return ptr.bytes
      end

      if is_array?
        raise TypeCastError.new("RPM::TagData is stored in array")
      end

      self[0]
    end

    # Returns the single value of tag data
    #
    # If tag data contains array or not set, returns nil.
    def value_no_array?
      # BIN is stored in array of UInt8. Treating specially
      if (ptr = @ptr).is_a?(ReturnTypeBin)
        return ptr.bytes
      end

      if is_array?
        return nil
      end

      self[0]?
    end

    # Returns the value in array.
    #
    # It raises `TypeCastError` if the tag data stores single value
    # only.
    def value_array
      # BIN is stored in array of UInt8. Treating specially
      if (ptr = @ptr).is_a?(ReturnTypeBin)
        return ptr.bytes
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
      if (ptr = @ptr).is_a?(ReturnTypeBin)
        return ptr.bytes
      end

      if !is_array?
        return nil
      end

      @ptr.to_a
    end

    # Returns the value.
    def value
      if (ptr = @ptr).is_a?(ReturnTypeBin)
        return ptr.bytes
      end

      if is_array?
        @ptr.to_a
      else
        self[0]
      end
    end

    # Returns the value.
    def value?
      if (ptr = @ptr).is_a?(ReturnTypeBin)
        return ptr.bytes
      end

      if is_array?
        @ptr.to_a
      else
        self[0]?
      end
    end

    def to_a
      @ptr.to_a
    end

    def finalize
      @ptr.detach
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

    # Format a single value at specified index of tag data in given
    # tag data format, and return it.
    def format(io : IO, index : Int, fmt : TagDataFormat) : Void
      @ptr.format(io, index, fmt)
    end

    # Format a single value at specified index of tag data in given
    # tag data format, and return it.
    def format(index : Int, fmt : TagDataFormat) : String
      @ptr.format(index, fmt)
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
