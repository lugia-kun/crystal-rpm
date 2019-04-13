module RPM
  class TagData
    getter ptr : LibRPM::TagData

    alias ElementUnion = (UInt8 | UInt16 | UInt32 | UInt64 | String)
    include Indexable(ElementUnion)

    class Iterator(T)
      @data : TagData
      @getter : Proc(TagData, T)
      @cursor : Int32 = -1

      include ::Iterator(T)

      def initialize(@data, @getter)
      end

      def initialize(@data, &block : TagData -> T)
        @getter = block
      end

      def next
        c = @cursor + 1
        @cursor = c
        if c >= @data.size
          stop
        else
          @data.pos = c
          @getter.call(@data)
        end
      end

      def rewind
        @cursor = -1
      end
    end

    def initialize(@ptr)
      LibRPM.rpmtdInit(@ptr)
    end

    private def self.new_ptr
      ptr = LibRPM.rpmtdNew
      raise Exception.new("Allocation failed") if ptr.null?
      ptr
    end

    def self.for(hdr : LibRPM::Header, tag : Tag | TagValue,
                 flg : LibRPM::HeaderGetFlags = LibRPM::HeaderGetFlags::MINMEM)
      ptr = new_ptr
      if LibRPM.headerGet(hdr, tag, ptr, flg) == 0
        LibRPM.rpmtdFree(ptr)
        raise KeyError.new("Tag #{tag} is not defined")
      end
      new(ptr)
    end

    def self.for(pkg : Package, tag : Tag | TagValue,
                 flg : LibRPM::HeaderGetFlags = LibRPM::HeaderGetFlags::MINMEM)
      self.for(pkg.hdr, tag, flg)
    end

    private def self.create_base(&block)
      ptr = new_ptr
      if yield(ptr) == 0
        LibRPM.rpmtdFree(ptr)
        raise TypeCastError.new("Failed to set tag data")
      end
      new(ptr)
    end

    def self.create(str : String, tag : Tag | TagValue)
      create_base do |ptr|
        LibRPM.rpmtdFromString(ptr, tag, str)
      end
    end

    def self.create(stra : Array(String), tag : Tag | TagValue)
      data = Array(Pointer(UInt8)).new(stra.size)
      stra.each do |str|
        data << str.to_unsafe
      end
      create_base do |ptr|
        LibRPM.rpmtdFromStringArray(ptr, tag, data, stra.size)
      end
    end

    def self.create(u8 : UInt8, tag : Tag | TagValue)
      create_base do |ptr|
        LibRPM.rpmtdFromUint8(ptr, tag, pointerof(u8), 1)
      end
    end

    def self.create(u16 : UInt16, tag : Tag | TagValue)
      create_base do |ptr|
        LibRPM.rpmtdFromUint8(ptr, tag, pointerof(u16), 1)
      end
    end

    def self.create(u32 : UInt32, tag : Tag | TagValue)
      create_base do |ptr|
        LibRPM.rpmtdFromUint8(ptr, tag, pointerof(u32), 1)
      end
    end

    def self.create(u64 : UInt64, tag : Tag | TagValue)
      create_base do |ptr|
        LibRPM.rpmtdFromUint8(ptr, tag, pointerof(u64), 1)
      end
    end

    def self.create(u8a : Array(UInt8) | Bytes, tag : Tag | TagValue)
      create_base do |ptr|
        LibRPM.rpmtdFromUint8(ptr, tag, u8a, u8a.size)
      end
    end

    def self.create(u16a : Array(UInt16) | Slice(UInt16), tag : Tag | TagValue)
      create_base do |ptr|
        LibRPM.rpmtdFromUint8(ptr, tag, u16a, u16a.size)
      end
    end

    def self.create(u32a : Array(UInt32) | Slice(UInt32), tag : Tag | TagValue)
      create_base do |ptr|
        LibRPM.rpmtdFromUint32(ptr, tag, u32a, u32a.size)
      end
    end

    def self.create(u64a : Array(UInt64) | Slice(UInt64), tag : Tag | TagValue)
      create_base do |ptr|
        LibRPM.rpmtdFromUint32(ptr, tag, u64a, u64a.size)
      end
    end

    def tag
      v = LibRPM.rpmtdTag(@ptr)
      Tag.from_value(v)
    end

    def type
      LibRPM.rpmtdType(@ptr)
    end

    def return_type
      RPM.tag_get_return_type(tag)
    end

    def size
      LibRPM.rpmtdCount(@ptr)
    end

    private def value_at_current_index : ElementUnion
      case type
      when TagType::CHAR, TagType::INT8, TagType::BIN
        LibRPM.rpmtdGetChar(@ptr).value
      when TagType::INT16
        LibRPM.rpmtdGetUint16(@ptr).value
      when TagType::INT32
        LibRPM.rpmtdGetUint32(@ptr).value
      when TagType::INT64
        LibRPM.rpmtdGetUint64(@ptr).value
      when TagType::STRING, TagType::STRING_ARRAY
        String.new(LibRPM.rpmtdGetString(@ptr))
      else
        raise NotImplementedError.new("Unsupported type: #{type}")
      end
    end

    def each
      type = self.type
      case type
      when TagType::BIN, TagType::CHAR, TagType::UINT8
        Iterator(UInt8).new(self) do |data|
          LibRPM.rpmtdGetChar(data.ptr).value
        end
      when TagType::INT16
        Iterator(UInt16).new(self) do |data|
          LibRPM.rpmtdGetUint16(data.ptr).value
        end
      when TagType::INT32
        Iterator(UInt32).new(self) do |data|
          LibRPM.rpmtdGetUint32(data.ptr).value
        end
      when TagType::STRING, TagType::STRING_ARRAY
        Iterator(String).new(self) do |data|
          String.new(LibRPM.rpmtdGetString(data.ptr))
        end
      else
        raise TypeCastError.new("Unsupported type for TagData#each: #{type}")
      end
    end

    private def is_array?(type : TagType, count : Int,
                          ret_type : TagReturnType)
      count > 1 || ret_type == TagReturnType::ARRAY ||
        type == TagType::STRING_ARRAY
    end

    def is_array?
      type = self.type
      count = self.size
      ret_type = self.return_type

      is_array?(type, count, ret_type)
    end

    private def get_binary(count)
      s = LibRPM.rpmtdFormat(@ptr, LibRPM::TagDataFormat::BASE64, nil)
      str = String.new(s)
      LibC.free(s)
      Base64.decode(str)
    end

    def value_no_array
      type = self.type
      count = self.size
      ret_type = self.return_type

      if count < 1
        raise TypeCastError.new("Empry TagData")
      end

      # BIN is stored in array of UInt8. Treating specially
      if type == TagType::BIN
        return get_binary(count)
      end

      if is_array?(type, count, ret_type)
        raise TypeCastError.new("RPM::TagData is stored in array (has #{count} values)")
      end

      LibRPM.rpmtdSetIndex(@ptr, 0)
      value_at_current_index
    end

    def value_no_array?
      value_no_array
    rescue TypeCastError
      nil
    end

    def value_array
      type = self.type
      count = self.size
      ret_type = self.return_type

      if count < 1
        return TypeCastError.new("Empty TagData")
      end

      # BIN is stored in array of UInt8. Treating specially
      if type == TagType::BIN
        return get_binary(count)
      end

      if !is_array?(type, count, ret_type)
        raise TypeCastError.new("RPM::TagData is stored in plain data")
      end

      LibRPM.rpmtdSetIndex(@ptr, 0)
      case type
      when TagType::CHAR, TagType::INT8
        Slice.new(LibRPM.rpmtdGetChar(@ptr), count, read_only: true)
      when TagType::INT16
        Slice.new(LibRPM.rpmtdGetUint16(@ptr), count, read_only: true)
      when TagType::INT32
        Slice.new(LibRPM.rpmtdGetUint32(@ptr), count, read_only: true)
      when TagType::INT64
        Slice.new(LibRPM.rpmtdGetUint64(@ptr), count, read_only: true)
      when TagType::STRING, TagType::STRING_ARRAY
        iter = Iterator(String).new(self) do |data|
          String.new(LibRPM.rpmtdGetString(data.ptr))
        end
        iter.to_a
      else
        raise NotImplementedError.new("Unsupported Type: #{type}")
      end
    end

    def value_array?
      value_array
    rescue TypeCastError
      nil
    end

    def value
      if is_array?
        value_array
      else
        value_no_array
      end
    end

    def value?
      value
    rescue TypeCastError
      nil
    end

    # Sets current index of TagData.
    #
    # This is for internal use.
    #
    # `#value_no_array` and `#value_array` ignores this property, they
    # always return the value (of non-array data) or the array of the
    # all values.
    #
    # Getting position is not supported, because it will be random if you
    # use multiple Iterators at once.
    def pos=(idx : Int)
      LibRPM.rpmtdSetIndex(@ptr, idx)
    end

    def unsafe_fetch(idx : Int) : ElementUnion
      self.pos = idx
      value_at_current_index
    end

    def finalize
      @ptr = LibRPM.rpmtdFree(@ptr)
    end
  end
end
