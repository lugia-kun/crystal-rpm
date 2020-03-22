require "../spec_helper"
require "tempdir"

describe RPM::TagData do
  describe "#bytes" do
    # No tag uses UInt8 type in default (as of RPM 4.8 through 4.14).
    it "raises TypeCastError for UInt8 Array" do
      data = RPM::TagData.create([0_u8, 1_u8], RPM::Tag::FileStates)
      data.force_return_type!(RPM::TagData::ReturnTypeInt8)
      data.bytes.should eq(Slice[0_u8, 1_u8])
    end

    it "can take binary array of Char Array" do
      data = RPM::TagData.create([0_u8, 1_u8], RPM::Tag::FileStates)
      data.bytes.should eq(Slice[0_u8, 1_u8])
    end

    it "can take binary array of UInt16 array" do
      data = RPM::TagData.create([0x1234_u16, 0x5678_u16], RPM::Tag::FileModes)
      data.bytes.should eq(Slice[0x1234_u16, 0x5678_u16])
    end

    it "can take binary array of UInt32 array" do
      data = RPM::TagData.create([0x12345678_u32, 0x56789abc_u32], RPM::Tag::FileSizes)
      data.bytes.should eq(Slice[0x12345678_u32, 0x56789abc_u32])
    end

    it "can take binary array of UInt64 array" do
      data = RPM::TagData.create([0x1234_5678_9abc_def0_u64, 0x5678_9abc_def0_1234_u64], RPM::Tag::LongFileSizes)
      data.bytes.should eq(Slice[0x1234_5678_9abc_def0_u64, 0x5678_9abc_def0_1234_u64])
    end

    it "raises TypeCastError for String Array" do
      data = RPM::TagData.create(["a", "b"], RPM::Tag::BaseNames)
      expect_raises(TypeCastError, "Cannot take byte array of string(s)") do
        data.bytes.should eq(Slice[1, 2])
      end
    end

    it "can take binary array of Binary" do
      data = RPM::TagData.create([1_u8, 2_u8], RPM::Tag::SigMD5)
      data.bytes.should eq(Slice[1_u8, 2_u8])
    end
  end

  describe "#[]" do
    describe "String" do
      it "returns a value" do
        data = RPM::TagData.create("name", RPM::Tag::Name)
        data[0].should eq("name")
      end

      it "raises exception IndexError for 1 and greater index" do
        data = RPM::TagData.create("name", RPM::Tag::Name)
        expect_raises(IndexError) do
          data[1].should eq("name")
        end
        expect_raises(IndexError) do
          data[2].should eq("name")
        end
        expect_raises(IndexError) do
          data[3].should eq("name")
        end
        expect_raises(IndexError) do
          data[-2].should eq("name")
        end
      end
    end

    describe "Array(String)" do
      it "returns a value" do
        data = RPM::TagData.create(["foo", "bar", "baz"], RPM::Tag::BaseNames)
        data[0].should eq("foo")
        data[1].should eq("bar")
        data[2].should eq("baz")
        data[-1].should eq("baz")
      end

      it "raises exception IndexError for out-of-range" do
        data = RPM::TagData.create(["foo", "bar", "baz"], RPM::Tag::BaseNames)
        expect_raises(IndexError) do
          data[3].should eq("name")
        end
        expect_raises(IndexError) do
          data[4].should eq("name")
        end
        expect_raises(IndexError) do
          data[5].should eq("name")
        end
        expect_raises(IndexError) do
          data[-4].should eq("name")
        end
      end
    end

    # No Tag stores a single Char.
    describe "Char" do
    end

    describe "Array(Char)" do
      it "returns a value" do
        data = RPM::TagData.create(['a'.ord.to_u8, 'b'.ord.to_u8, 'c'.ord.to_u8], RPM::Tag::FileStates)
        data[0].should eq('a')
        data[1].should eq('b')
        data[2].should eq('c')
        data[-1].should eq('c')
      end

      it "raises exception IndexError for out-of-range" do
        data = RPM::TagData.create(['a'.ord.to_u8, 'b'.ord.to_u8, 'c'.ord.to_u8], RPM::Tag::FileStates)
        expect_raises(IndexError) do
          data[3].should eq('a')
        end
        expect_raises(IndexError) do
          data[4].should eq('a')
        end
        expect_raises(IndexError) do
          data[5].should eq('a')
        end
        expect_raises(IndexError) do
          data[-4].should eq('a')
        end
      end
    end

    # No Tag stores a single UInt8 (even for Char).
    describe "UInt8" do
    end

    # No Tag stores array of UInt8, but it should be interoperable with Char.
    describe "Array(UInt8)" do
      it "returns a value" do
        data = RPM::TagData.create([5_u8, 11_u8, 12_u8], RPM::Tag::FileStates)
        data.force_return_type!(RPM::TagData::ReturnTypeInt8)
        data[0].should eq(5_u8)
        data[1].should eq(11_u8)
        data[2].should eq(12_u8)
        data[-1].should eq(12_u8)
      end

      it "raises exception IndexError for out-of-range" do
        data = RPM::TagData.create([5_u8, 11_u8, 12_u8], RPM::Tag::FileStates)
        data.force_return_type!(RPM::TagData::ReturnTypeInt8)
        expect_raises(IndexError) do
          data[3].should eq(5_u8)
        end
        expect_raises(IndexError) do
          data[4].should eq(11_u8)
        end
        expect_raises(IndexError) do
          data[5].should eq(12_u8)
        end
        expect_raises(IndexError) do
          data[-4].should eq(5_u8)
        end
      end
    end

    # No Tag data stores a single UInt16 value.
    describe "UInt16" do
    end

    describe "Array(UInt16)" do
      it "returns a value" do
        data = RPM::TagData.create([5_u16, 11_u16, 12_u16], RPM::Tag::FileModes)
        data[0].should eq(5_u16)
        data[1].should eq(11_u16)
        data[2].should eq(12_u16)
        data[-1].should eq(12_u16)
      end

      it "raises exception IndexError for out-of-range" do
        data = RPM::TagData.create([5_u16, 11_u16, 12_u16], RPM::Tag::FileModes)
        expect_raises(IndexError) do
          data[3].should eq(5_u16)
        end
        expect_raises(IndexError) do
          data[4].should eq(11_u16)
        end
        expect_raises(IndexError) do
          data[5].should eq(12_u16)
        end
        expect_raises(IndexError) do
          data[-4].should eq(5_u16)
        end
      end
    end

    describe "UInt32" do
      it "returns a value" do
        data = RPM::TagData.create(5_u32, RPM::Tag::Epoch)
        data[0].should eq(5_u32)
      end

      it "raises exception IndexError for 1 and greater index" do
        data = RPM::TagData.create(5_u32, RPM::Tag::Epoch)
        expect_raises(IndexError) do
          data[1].should eq(5_u32)
        end
        expect_raises(IndexError) do
          data[2].should eq(5_u32)
        end
        expect_raises(IndexError) do
          data[3].should eq(5_u32)
        end
        expect_raises(IndexError) do
          data[-2].should eq(5_u32)
        end
      end
    end

    describe "Array(UInt32)" do
      it "returns a value" do
        data = RPM::TagData.create([5_u32, 11_u32, 12_u32], RPM::Tag::FileSizes)
        data[0].should eq(5_u32)
        data[1].should eq(11_u32)
        data[2].should eq(12_u32)
        data[-1].should eq(12_u32)
      end

      it "raises exception IndexError for out-of-range" do
        data = RPM::TagData.create([5_u32, 11_u32, 12_u32], RPM::Tag::FileSizes)
        expect_raises(IndexError) do
          data[3].should eq(5_u16)
        end
        expect_raises(IndexError) do
          data[4].should eq(11_u16)
        end
        expect_raises(IndexError) do
          data[5].should eq(12_u16)
        end
        expect_raises(IndexError) do
          data[-4].should eq(5_u16)
        end
      end
    end

    # No Tag data stores a single UInt64 value.
    describe "UInt64" do
    end

    describe "Array(UInt64)" do
      it "returns a value" do
        data = RPM::TagData.create([5_u64, 11_u64, 12_u64], RPM::Tag::LongFileSizes)
        data[0].should eq(5_u64)
        data[1].should eq(11_u64)
        data[2].should eq(12_u64)
        data[-1].should eq(12_u64)
      end

      it "raises exception IndexError for out-of-range" do
        data = RPM::TagData.create([5_u64, 11_u64, 12_u64], RPM::Tag::LongFileSizes)
        expect_raises(IndexError) do
          data[3].should eq(5_u64)
        end
        expect_raises(IndexError) do
          data[4].should eq(11_u64)
        end
        expect_raises(IndexError) do
          data[5].should eq(12_u64)
        end
        expect_raises(IndexError) do
          data[-4].should eq(5_u64)
        end
      end
    end

    describe "Binary" do
      it "returns a value" do
        data = RPM::TagData.create([5_u8, 3_u8], RPM::Tag::SigMD5)
        data[0].should eq(Bytes[5, 3])
      end

      it "raises exception IndexError for 1 and greater index" do
        data = RPM::TagData.create([5_u8, 3_u8], RPM::Tag::SigMD5)
        expect_raises(IndexError) do
          data[1].should eq(5_u32)
        end
        expect_raises(IndexError) do
          data[2].should eq(5_u32)
        end
        expect_raises(IndexError) do
          data[3].should eq(5_u32)
        end
        expect_raises(IndexError) do
          data[-2].should eq(5_u32)
        end
      end
    end
  end

  describe "#[]?" do
    describe "String" do
      it "returns a value" do
        data = RPM::TagData.create("name", RPM::Tag::Name)
        data[0]?.should eq("name")
      end

      it "returns nil for 1 and greater index" do
        data = RPM::TagData.create("name", RPM::Tag::Name)
        data[1]?.should be_nil
        data[2]?.should be_nil
        data[3]?.should be_nil
        data[-2]?.should be_nil
      end
    end

    describe "Array(String)" do
      it "returns a value" do
        data = RPM::TagData.create(["foo", "bar", "baz"], RPM::Tag::BaseNames)
        data[0]?.should eq("foo")
        data[1]?.should eq("bar")
        data[2]?.should eq("baz")
        data[-1]?.should eq("baz")
      end

      it "returns nil for out-of-range" do
        data = RPM::TagData.create(["foo", "bar", "baz"], RPM::Tag::BaseNames)
        data[3]?.should be_nil
        data[4]?.should be_nil
        data[5]?.should be_nil
        data[-4]?.should be_nil
      end
    end

    # No Tag stores a single Char.
    describe "Char" do
    end

    describe "Array(Char)" do
      it "returns a value" do
        data = RPM::TagData.create(['a'.ord.to_u8, 'b'.ord.to_u8, 'c'.ord.to_u8], RPM::Tag::FileStates)
        data[0]?.should eq('a')
        data[1]?.should eq('b')
        data[2]?.should eq('c')
        data[-1]?.should eq('c')
      end

      it "returns nil for out-of-range" do
        data = RPM::TagData.create(['a'.ord.to_u8, 'b'.ord.to_u8, 'c'.ord.to_u8], RPM::Tag::FileStates)
        data[3]?.should be_nil
        data[4]?.should be_nil
        data[5]?.should be_nil
        data[-4]?.should be_nil
      end
    end

    # No Tag stores a single UInt8 (even for Char).
    describe "UInt8" do
    end

    # No Tag stores array of UInt8, but it should be interoperable with Char.
    describe "Array(UInt8)" do
      it "returns a value" do
        data = RPM::TagData.create([5_u8, 11_u8, 12_u8], RPM::Tag::FileStates)
        data.force_return_type!(RPM::TagData::ReturnTypeInt8)
        data[0]?.should eq(5_u8)
        data[1]?.should eq(11_u8)
        data[2]?.should eq(12_u8)
        data[-1]?.should eq(12_u8)
      end

      it "returns nil for out-of-range" do
        data = RPM::TagData.create([5_u8, 11_u8, 12_u8], RPM::Tag::FileStates)
        data.force_return_type!(RPM::TagData::ReturnTypeInt8)
        data[3]?.should be_nil
        data[4]?.should be_nil
        data[5]?.should be_nil
        data[-4]?.should be_nil
      end
    end

    # No Tag data stores a single UInt16 value.
    describe "UInt16" do
    end

    describe "Array(UInt16)" do
      it "returns a value" do
        data = RPM::TagData.create([5_u16, 11_u16, 12_u16], RPM::Tag::FileModes)
        data[0]?.should eq(5_u16)
        data[1]?.should eq(11_u16)
        data[2]?.should eq(12_u16)
        data[-1]?.should eq(12_u16)
      end

      it "returns nil for out-of-range" do
        data = RPM::TagData.create([5_u16, 11_u16, 12_u16], RPM::Tag::FileModes)
        data[3]?.should be_nil
        data[4]?.should be_nil
        data[5]?.should be_nil
        data[-4]?.should be_nil
      end
    end

    describe "UInt32" do
      it "returns a value" do
        data = RPM::TagData.create(5_u32, RPM::Tag::Epoch)
        data[0]?.should eq(5_u32)
      end

      it "returns nil for 1 and greater index" do
        data = RPM::TagData.create(5_u32, RPM::Tag::Epoch)
        data[1]?.should be_nil
        data[2]?.should be_nil
        data[3]?.should be_nil
        data[-2]?.should be_nil
      end
    end

    describe "Array(UInt32)" do
      it "returns a value" do
        data = RPM::TagData.create([5_u32, 11_u32, 12_u32], RPM::Tag::FileSizes)
        data[0]?.should eq(5_u32)
        data[1]?.should eq(11_u32)
        data[2]?.should eq(12_u32)
        data[-1]?.should eq(12_u32)
      end

      it "returns nil for out-of-range" do
        data = RPM::TagData.create([5_u32, 11_u32, 12_u32], RPM::Tag::FileSizes)
        data[3]?.should be_nil
        data[4]?.should be_nil
        data[5]?.should be_nil
        data[-4]?.should be_nil
      end
    end

    # No Tag data stores a single UInt64 value.
    describe "UInt64" do
    end

    describe "Array(UInt64)" do
      it "returns a value" do
        data = RPM::TagData.create([5_u64, 11_u64, 12_u64], RPM::Tag::LongFileSizes)
        data[0]?.should eq(5_u64)
        data[1]?.should eq(11_u64)
        data[2]?.should eq(12_u64)
        data[-1]?.should eq(12_u64)
      end

      it "returns nil for out-of-range" do
        data = RPM::TagData.create([5_u64, 11_u64, 12_u64], RPM::Tag::LongFileSizes)
        data[3]?.should be_nil
        data[4]?.should be_nil
        data[5]?.should be_nil
        data[-4]?.should be_nil
      end
    end

    describe "Binary" do
      it "returns a value" do
        data = RPM::TagData.create([5_u8, 3_u8], RPM::Tag::SigMD5)
        data[0]?.should eq(Bytes[5, 3])
      end

      it "returns nil for 1 and greater index" do
        data = RPM::TagData.create([5_u8, 3_u8], RPM::Tag::SigMD5)
        data[1]?.should be_nil
        data[2]?.should be_nil
        data[3]?.should be_nil
        data[-2]?.should be_nil
      end
    end
  end

  describe "#value_no_array" do
    it "raises TypeCastError for empty array tagdata" do
      data = RPM::TagData.create do |ptr|
        RPM::LibRPM.rpmtdSetTag(ptr, RPM::Tag::FileSizes)
      end
      expect_raises(TypeCastError, "RPM::TagData is stored in array") do
        data.value_no_array.should eq([] of UInt32)
      end
    end

    it "raises IndexError for empty non-array tagdata" do
      data = RPM::TagData.create do |ptr|
        RPM::LibRPM.rpmtdSetTag(ptr, RPM::Tag::Name)
      end
      expect_raises(IndexError) do
        data.value_no_array.should eq("")
      end
    end

    it "raises TypeCastError if tagdata stores an array" do
      data = RPM::TagData.create([5_u32, 3_u32], RPM::Tag::FileSizes)
      expect_raises(TypeCastError, "RPM::TagData is stored in array") do
        data.value_no_array.should eq([5_u32, 3_u32])
      end
    end

    it "returns value for non-array data" do
      data = RPM::TagData.create("name", RPM::Tag::Name)
      data.value_no_array.should eq("name")
    end

    it "returns byte array for binary" do
      data = RPM::TagData.create(Bytes[1, 2], RPM::Tag::SigMD5)
      data.value_no_array.should eq(Bytes[1, 2])
    end
  end

  describe "#value_no_array?" do
    it "returns nil for empty array tagdata" do
      data = RPM::TagData.create do |ptr|
        RPM::LibRPM.rpmtdSetTag(ptr, RPM::Tag::FileSizes)
      end
      data.value_no_array?.should be_nil
    end

    it "returns nil for empty non-array tagdata" do
      data = RPM::TagData.create do |ptr|
        RPM::LibRPM.rpmtdSetTag(ptr, RPM::Tag::Name)
      end
      data.value_no_array?.should be_nil
    end

    it "returns nil if tagdata stores an array" do
      data = RPM::TagData.create([5_u32, 3_u32], RPM::Tag::FileSizes)
      data.value_no_array?.should be_nil
    end

    it "returns value for non-array data" do
      data = RPM::TagData.create("name", RPM::Tag::Name)
      data.value_no_array?.should eq("name")
    end

    it "returns byte array for binary" do
      data = RPM::TagData.create(Bytes[1, 2], RPM::Tag::SigMD5)
      data.value_no_array?.should eq(Bytes[1, 2])
    end
  end

  describe "#value_array" do
    it "returns empty Array for empty array tagdata" do
      data = RPM::TagData.create do |ptr|
        RPM::LibRPM.rpmtdSetTag(ptr, RPM::Tag::FileSizes)
      end
      data.value_array.should eq([] of UInt32)
    end

    it "raises TypeCastError for empty non-array tagdata" do
      data = RPM::TagData.create do |ptr|
        RPM::LibRPM.rpmtdSetTag(ptr, RPM::Tag::Name)
      end
      expect_raises(TypeCastError, "RPM::TagData stores non-array data") do
        data.value_array.should eq("")
      end
    end

    it "returns array if tagdata stores an array" do
      data = RPM::TagData.create([5_u32, 3_u32], RPM::Tag::FileSizes)
      data.value_array.should eq([5_u32, 3_u32])
    end

    it "raises TypeCastError for non-array data" do
      data = RPM::TagData.create("name", RPM::Tag::Name)
      expect_raises(TypeCastError, "RPM::TagData stores non-array data") do
        data.value_array.should eq("name")
      end
    end

    it "returns byte array for binary" do
      data = RPM::TagData.create(Bytes[1, 2], RPM::Tag::SigMD5)
      data.value_array.should eq(Bytes[1, 2])
    end
  end

  describe "#value_array?" do
    it "returns empty array for empty array tagdata" do
      data = RPM::TagData.create do |ptr|
        RPM::LibRPM.rpmtdSetTag(ptr, RPM::Tag::FileSizes)
      end
      data.value_array?.should eq([] of UInt32)
    end

    it "returns nil for empty non-array tagdata" do
      data = RPM::TagData.create do |ptr|
        RPM::LibRPM.rpmtdSetTag(ptr, RPM::Tag::Name)
      end
      data.value_array?.should be_nil
    end

    it "returns array if tagdata stores an array" do
      data = RPM::TagData.create([5_u32, 3_u32], RPM::Tag::FileSizes)
      data.value_array?.should eq([5_u32, 3_u32])
    end

    it "returns nil for non-array data" do
      data = RPM::TagData.create("name", RPM::Tag::Name)
      data.value_array?.should be_nil
    end

    it "returns byte array for binary" do
      data = RPM::TagData.create(Bytes[1, 2], RPM::Tag::SigMD5)
      data.value_array?.should eq(Bytes[1, 2])
    end
  end

  describe "#value" do
    it "return empty array for empty array tagdata" do
      data = RPM::TagData.create do |ptr|
        RPM::LibRPM.rpmtdSetTag(ptr, RPM::Tag::FileSizes)
      end
      data.value.should eq([] of UInt32)
    end

    it "raises TypeCastError for empty non-array tagdata" do
      data = RPM::TagData.create do |ptr|
        RPM::LibRPM.rpmtdSetTag(ptr, RPM::Tag::Name)
      end
      expect_raises(IndexError) do
        data.value.should eq("")
      end
    end

    it "returns array if tagdata stores an array" do
      data = RPM::TagData.create([5_u32, 3_u32], RPM::Tag::FileSizes)
      data.value.should eq([5_u32, 3_u32])
    end

    it "returns value for non-array data" do
      data = RPM::TagData.create("name", RPM::Tag::Name)
      data.value.should eq("name")
    end

    it "returns byte array for binary" do
      data = RPM::TagData.create(Bytes[1, 2], RPM::Tag::SigMD5)
      data.value.should eq(Bytes[1, 2])
    end
  end

  describe "#value?" do
    it "returns empty array for empty array tagdata" do
      data = RPM::TagData.create do |ptr|
        RPM::LibRPM.rpmtdSetTag(ptr, RPM::Tag::FileSizes)
      end
      data.value_array?.should eq([] of UInt32)
    end

    it "returns nil for empty non-array tagdata" do
      data = RPM::TagData.create do |ptr|
        RPM::LibRPM.rpmtdSetTag(ptr, RPM::Tag::Name)
      end
      data.value_array?.should be_nil
    end

    it "returns array if tagdata stores an array" do
      data = RPM::TagData.create([5_u32, 3_u32], RPM::Tag::FileSizes)
      data.value?.should eq([5_u32, 3_u32])
    end

    it "returns value for non-array data" do
      data = RPM::TagData.create("name", RPM::Tag::Name)
      data.value?.should eq("name")
    end

    it "returns byte array for binary" do
      data = RPM::TagData.create(Bytes[1, 2], RPM::Tag::SigMD5)
      data.value?.should eq(Bytes[1, 2])
    end
  end

  describe "#force_return_type!" do
    it "supports changing return type" do
      data = RPM::TagData.create(['a', 'b'].map { |x| x.ord.to_u8 }, RPM::Tag::FileStates)
      data[0].should eq('a')
      data.force_return_type!(RPM::TagData::ReturnTypeInt8)
      data[0].should eq('a'.ord.to_u8)
      data.force_return_type!(RPM::TagData::ReturnTypeChar)
      data[0].should eq('a')

      # Setting to binary is unexpected behavior, but the result is
      # determinable, because `#bytes` uses `#format1`, which is always
      # succeeds. The value 151 is the result of interpreting the decimal
      # codepoint of `a` (i.e., 97) as hexadecimal value.
      data.force_return_type!(RPM::TagData::ReturnTypeBin)
      data[0].should eq(Bytes['a'.ord.to_u8.to_s.to_u8(16)])
    end
  end

  describe "#tag=" do
    it "can accept another tag of same type" do
      data = RPM::TagData.create(["foo", "bar"], RPM::Tag::BaseNames)
      data.tag = RPM::Tag::FileUserName
      data.tag.should eq(RPM::Tag::FileUserName)
    end

    it "raises TypeCastError if different type" do
      data = RPM::TagData.create(["foo", "bar"], RPM::Tag::BaseNames)
      expect_raises(TypeCastError, "Incompatible tag value LongFileSizes for STRING") do
        data.tag = RPM::Tag::LongFileSizes
      end
      # unchanged.
      data.tag.should eq(RPM::Tag::BaseNames)
    end
  end

  describe ".create" do
    describe "&block" do
      it "raises TypeCastError if block returns 0" do
        expect_raises(TypeCastError, "Failed to set TagData") do
          data = RPM::TagData.create do
            0
          end
          data[0].should eq(1_u8)
        end
      end

      it "raises itself block raises an exception" do
        expect_raises(Exception, "Test Message") do
          data = RPM::TagData.create do
            raise Exception.new("Test Message")
          end
          data[0].should eq(1_u8)
        end
      end
    end

    describe "UInt8" do
      it "raises TypeCastError for incompatible data types" do
        expect_raises(TypeCastError, "Failed to set TagData") do
          data = RPM::TagData.create(1_u8, RPM::Tag::FileSizes)
          data[0].should eq(1_u8)
        end
      end

      it "can be used for creating Array of Char data" do
        data = RPM::TagData.create('a'.ord.to_u8, RPM::Tag::FileStates)
        data[0].should eq('a')
      end

      it "can be used for creating Binary data" do
        data = RPM::TagData.create(1_u8, RPM::Tag::SigMD5)
        data[0].should eq(Bytes[1])
      end
    end

    describe "Array(UInt8)" do
      it "raises TypeCastError for incompatible data types" do
        expect_raises(TypeCastError, "Failed to set TagData") do
          data = RPM::TagData.create([1_u8], RPM::Tag::FileSizes)
          data[0].should eq(1_u8)
        end
      end

      it "can be used for creating Array of Char data" do
        bytes = ['a'].map { |x| x.ord.to_u8 }
        bytes.is_a?(Array(UInt8)).should be_true
        data = RPM::TagData.create(bytes, RPM::Tag::FileStates)
        data[0].should eq('a')
      end

      it "can be used for creating Binary data" do
        data = RPM::TagData.create(Slice[1_u8, 2_u8], RPM::Tag::SigMD5)
        data[0].should eq(Bytes[1, 2])
      end

      it "can be used without copying, but it would be shared" do
        ary = Slice[1_u8, 2_u8]
        data = RPM::TagData.create(ary, RPM::Tag::SigMD5, copy: false)
        data[0].should eq(Bytes[1, 2])
        ary[1] = 3_u8
        data[0].should eq(Bytes[1, 3])
        ary[0] = 1_u8 # to avoid garbage collection
      end
    end

    describe "UInt16" do
      it "raises TypeCastError for incompatible data types" do
        expect_raises(TypeCastError, "Failed to set TagData") do
          data = RPM::TagData.create(1_u16, RPM::Tag::FileSizes)
          data[0].should eq(1_u8)
        end
      end

      it "can be used for creating Array of UInt16 data" do
        data = RPM::TagData.create(1_u16, RPM::Tag::FileModes)
        data[0].should eq(1_u16)
      end
    end

    describe "Array(UInt16)" do
      it "raises TypeCastError for incompatible data types" do
        expect_raises(TypeCastError, "Failed to set TagData") do
          data = RPM::TagData.create([1_u16], RPM::Tag::FileSizes)
          data[0].should eq(1_u16)
        end
      end

      it "can be used for creating Array of UInt16 data" do
        data = RPM::TagData.create([1_u16], RPM::Tag::FileModes)
        data[0].should eq(1_u16)
      end

      it "can be used without copying, but it would be shared" do
        ary = Slice[1_u16, 2_u16]
        data = RPM::TagData.create(ary, RPM::Tag::FileModes, copy: false)
        data[1].should eq(2_u16)
        ary[1] = 3_u16
        data[1].should eq(3_u16)
        ary[1] = 1_u16 # to avoid garbage collection
      end
    end

    describe "UInt32" do
      it "raises TypeCastError for incompatible data types" do
        expect_raises(TypeCastError, "Failed to set TagData") do
          data = RPM::TagData.create(1_u32, RPM::Tag::FileStates)
          data[0].should eq(1_u32)
        end
      end

      it "can be used for creating UInt32 data" do
        data = RPM::TagData.create(1_u32, RPM::Tag::Epoch)
        data[0].should eq(1_u32)
      end

      it "can be used for creating Array of UInt32 data" do
        data = RPM::TagData.create(1_u32, RPM::Tag::FileSizes)
        data[0].should eq(1_u32)
      end
    end

    describe "Array(UInt32)" do
      it "raises TypeCastError for incompatible data types" do
        expect_raises(TypeCastError, "Failed to set TagData") do
          data = RPM::TagData.create([1_u32], RPM::Tag::FileStates)
          data[0].should eq(1_u32)
        end
      end

      it "can be used for creating Array of UInt32 data" do
        data = RPM::TagData.create([1_u32], RPM::Tag::FileSizes)
        data[0].should eq(1_u32)
      end

      it "can be used without copying, but it would be shared" do
        ary = Slice[1_u32, 2_u32]
        data = RPM::TagData.create(ary, RPM::Tag::FileSizes, copy: false)
        data[1].should eq(2_u32)
        ary[1] = 3_u32
        data[1].should eq(3_u32)
        ary[1] = 1_u32 # to avoid garbage collection
      end
    end

    describe "UInt64" do
      it "raises TypeCastError for incompatible data types" do
        expect_raises(TypeCastError, "Failed to set TagData") do
          data = RPM::TagData.create(1_u64, RPM::Tag::FileSizes)
          data[0].should eq(1_u64)
        end
      end

      it "can be used for creating Array of UInt64 data" do
        data = RPM::TagData.create(1_u64, RPM::Tag::LongFileSizes)
        data[0].should eq(1_u64)
      end
    end

    describe "Array(UInt64)" do
      it "raises TypeCastError for incompatible data types" do
        expect_raises(TypeCastError, "Failed to set TagData") do
          data = RPM::TagData.create([1_u64], RPM::Tag::FileSizes)
          data[0].should eq(1_u64)
        end
      end

      it "can be used for creating Array of UInt64 data" do
        data = RPM::TagData.create([1_u64], RPM::Tag::LongFileSizes)
        data[0].should eq(1_u64)
      end

      it "can be used without copying, but it would be shared" do
        ary = Slice[1_u64, 2_u64]
        data = RPM::TagData.create(ary, RPM::Tag::LongFileSizes, copy: false)
        data[1].should eq(2_u64)
        ary[1] = 3_u64
        data[1].should eq(3_u64)
        ary[1] = 1_u64 # to avoid garbage collection
      end
    end

    describe "String" do
      it "raises TypeCastError for incompatible data types" do
        expect_raises(TypeCastError, "Failed to set TagData") do
          data = RPM::TagData.create("name", RPM::Tag::FileSizes)
          data[0].should eq("name")
        end
      end

      it "can be used for creating String data" do
        data = RPM::TagData.create("name", RPM::Tag::Name)
        data[0].should eq("name")
      end

      it "can be used for creating Array of String data" do
        data = RPM::TagData.create("name", RPM::Tag::BaseNames)
        data[0].should eq("name")
      end
    end

    describe "Array(String)" do
      it "raises TypeCastError for incompatible data types" do
        expect_raises(TypeCastError, "Failed to set TagData") do
          data = RPM::TagData.create(["name"], RPM::Tag::FileSizes)
          data[0].should eq("name")
        end
      end

      it "can be used for creating Array of String data" do
        data = RPM::TagData.create(["name"], RPM::Tag::BaseNames)
        data[0].should eq("name")
      end
    end
  end

  describe "#to_unsafe" do
    it "returns rpmtd pointer" do
      data = RPM::TagData.create(1_u32, RPM::Tag::Epoch)
      data.to_unsafe.is_a?(RPM::LibRPM::RPMTd).should be_true
    end
  end
end
