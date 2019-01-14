require "rpm/librpm"
require "rpm/match_iterator"
require "rpm/dependency"
require "rpm/package"

module RPM
  class DB
  end

  class Transaction
    getter ptr : LibRPM::Transaction

    def initialize(**opts)
      @key = Set(String).new

      root = opts[:root]?
      root ||= "/"

      @ptr = LibRPM.rpmtsCreate
      if @ptr.null?
        raise Exception.new("Can't create Transaction")
      end

      LibRPM.rpmtsSetRootDir(@ptr, root)
    end

    def finalize
      LibRPM.rpmtsFree(@ptr)
    end

    def init_iterator(tag : DbiTag | DbiTagValue, val : String)
      it_ptr = LibRPM.rpmtsInitIterator(@ptr, tag, val, 0)
      if it_ptr.null?
        raise Exception.new("Can't init iterator for [#{tag}] -> '#{val}'")
      end

      MatchIterator.new(it_ptr)
    end

    def each_match(key, val, &block)
      itr = init_iterator(key, val)

      return itr unless block_given?

      itr.each(&block)
    end

    def each(&block)
      each_match(0, nil, &block)
    end

    def install(pkg : Package, key : String)
      install_element(pkg, key, upgrade: false)
    end

    def upgrade(pkg : Package, key : String)
      install_element(pkg, key, upgrade: true)
    end

    def delete_by_iterator(iter : MatchIterator)
      iter.each do |header|
        ret = RPM.rpmtsAddEraseElement(@ptr, header.ptr, iterator.offset)
        raise Exception.new("Error while adding erase to transaction") if ret != 0
      end
    end

    def delete(pkg : Package)
      iter = if pkg[DbiTag::SigMD5]
               each_match(DbiTag::SigMD5, pkg[DbiTag::SigMD5])
             else
               each_match(DbiTag::Label, pkg[DbiTag::Label])
             end

      delete_by_iterator(iter)
    end

    def delete(pkg : String)
      iter = each_match(DbiTag::Label, pkg)
      delete_by_iterator(iter)
    end

    def delete(pkg : Dependency)
      iter = each_match(DbiTag::Label, pkg.name).set_iterator_version(pkg.version)
      delete_by_iterator(iter)
    end

    def root_dir=(dir : String | UInt8*)
      LibRPM.rpmtsSetRootDir(@ptr, dir)
    end

    def root_dir
      String.new(LibRPM.rpmtsRootDir(@ptr))
    end

    def db
      DB.new(self)
    end

    def install_element(pkg : Package, key : String, **opts)
      raise Exception.new("#{self}: key #{key} must be unique") if @key.includes?(key)
      @keys << key

      upgrade = opts[:upgrade]?
      upgrade ||= 0

      ret = LibRPM.rpmtsAddInstallElement(@otr, pkg.ptr, key, upgrade, nil)
      raise Exception.new("Failed add install element") if ret != 0
      nil
    end
  end

  def self.transaction(root = "/", &block)
    ts = Transaction.new
    ts.root_dir = root
    yield ts
  ensure
    unless ts.nil?
      ts.as(Transaction).finalize
    end
  end
end
