require "rpm/librpm"
require "rpm/transaction"

module RPM
  class DB
    include Enumerable(DB)

    property ts : Transaction

    def initialize(@ts : Transaction, **opts)
      LibRPM.rpmtsOpenDB(@ts.ptr, opts[:writable] ? (LibC::O_RDWR | LibC::O_CREAT) : LibC::O_RDONLY)
    end

    def init_iterator
    end
  end
end
