require 'rubygems'
require 'libmdbtools'

# This extends the basic libmdb mapping defined in module MDB libmdbtools.rb
module MDB
  class DB
    def initialize(filename_or_pointer, flags=:MDB_NOFLAGS)
      return super(filename_or_pointer) if filename_or_pointer.is_a? FFI::Pointer
      LibMDB::init
      super LibMDB::open(filename_or_pointer, flags)
    end

    def self.open(filename)
      new(filename)
    end

    def table(name)
      Table.new name, self
    end
  end
  
  class Table
    def initialize(name, mdb)
      super LibMDB::read_table_by_name(mdb, name, :MDB_TABLE)
      @mdb = mdb
      LibMDB::read_columns self
      self.rewind
      
      @values = (0...self.num_cols).map do |i|
        val = BoundValue.new ""
        len = BoundLength.new [0]
        LibMDB::bind_column self, i+1, val, len
        [val, len]
      end
    end
    
    def rewind
      LibMDB::rewind_table self
    end
    
    def fetch_row
      return if LibMDB::fetch_row(self) == 0
      @values.map do |bound_val, bound_len|
        bound_val.value.to_s[0...bound_len.len]
      end
    end
    
    def rows
      return self.to_enum(:rows) unless block_given?
      rewind
      while row = fetch_row
        yield row
      end
      rewind
    end
  end
end

