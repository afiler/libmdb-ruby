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
    
    def column_names
      @column_names ||= columns.map { |c| c.name.to_s }
    end
  
    def column_indexes
      @column_indexes ||= Hash[column_names.each_with_index.map { |val, index| [val, index] }]
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
        yield Row.new(row, self)
      end
      rewind
    end
    
    def find(hash)
      return self.to_enum(:find, hash) unless block_given?
      rows.each do |row|
        yield row if row.match? hash
      end
    end
  end
  
  class Row < Array
    def initialize(row, table)
      @table = table
      replace row
    end
    
    def [](key)
      key = @table.column_indexes[key] unless key.is_a? Fixnum
      super key
    end
    
    def match?(hash)
      hash.each do |k, v|
        return false unless self[k] == v
      end
      true
    end
  end
end

