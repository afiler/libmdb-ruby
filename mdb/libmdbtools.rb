require 'nice-ffi'
require 'libglib'

module MDB
  extend NiceFFI::Library
  
  MDB_MAX_OBJ_NAME = 256
  MDB_PGSIZE = 4096
  
  FileFlag = enum :FileFlag, [:MDB_NOFLAGS, 0, :MDB_WRITABLE, 1]
  ObjType = enum :ObjType, [:MDB_FORM, 0, :MDB_TABLE, :MDB_MACRO, :MDB_SYSTEM_TABLE, :MDB_REPORT, :MDB_QUERY, :MDB_LINKED_TABLE, :MDB_MODULE, :MDB_RELATIONSHIP, :MDB_UNKNOWN_09, :MDB_UNKNOWN_0A, :MDB_DATABASE_PROPERTY, :MDB_ANY, -1]
  Strategy = enum :Strategy, [:MDB_TABLE_SCAN, :MDB_LEAF_SCAN, :MDB_INDEX_SCAN]
  ColType = enum :ColType, [:MDB_BOOL, 0x01, :MDB_BYTE, 0x02, :MDB_INT, 0x03, :MDB_LONGINT, 0x04, :MDB_MONEY, 0x05, :MDB_FLOAT, 0x06, :MDB_DOUBLE, 0x07, :MDB_SDATETIME, 0x08, :MDB_TEXT, 0x0a, :MDB_OLE, 0x0b, :MDB_MEMO, 0x0c, :MDB_REPID, 0x0f, :MDB_NUMERIC, 0x10]
  
  class DB < NiceFFI::Struct
    layout \
      :f, :pointer, # MdbFile
      :cur_pg, :uint32,
      :row_num, :uint16,
      :cur_pos, :uint,
      :pg_buf, [:uchar, MDB_PGSIZE],
      :alt_pg_buf, [:uchar, MDB_PGSIZE],
      :num_catalog, :uint,
      :catalog, GLib::PtrArrayOf('MDB::CatalogEntry'), #:pointer, # GPtrArray
      :default_backend, :pointer,  # MdbBackend
      :backend_name, :string,
      :fmt, :pointer,  # MdbFormatConstants
      :stats, :pointer  # MdbStatistics
      #ifdef HAVE_ICONV
      #:iconv_in, :iconv_t,
      #:iconv_out, :iconv_t
      #endif
  end
  
  class CatalogEntry < NiceFFI::Struct
    layout \
      :mdb, NiceFFI::TypedPointer(DB),
      :object_name, [:char, MDB_MAX_OBJ_NAME+1],
      :object_type, :int,
      :table_pg, :ulong, # misnomer since object may not be a table
      :kkd_pg, :ulong,
      :kkd_rowid, :uint,
      :num_props, :int,
      :props, NiceFFI::TypedPointer(GLib::GArray),
      :columns, GLib::PtrArrayOf('MDB::Column'),
      :flags, :int
  end

    
  class Table < NiceFFI::Struct    
    layout :entry, NiceFFI::TypedPointer(CatalogEntry), #:pointer, # MdbCatalogEntry
      :name, [:char, MDB_MAX_OBJ_NAME+1],
      :num_cols, :uint,
      :columns, GLib::PtrArrayOf('MDB::Column'), #NiceFFI::TypedPointer(GLib::GPtrArray), # :pointer, # GLib::GPtrArray #
      :num_rows, :uint,
      :index_start, :int,
      :num_real_idxs, :uint,
      :num_idxs, :uint,
      :indices, :pointer, # GLib::GPtrArray
      :first_data_pg, :uint32,
      :cur_pg_num, :uint32,
      :cur_phys_pg, :uint32,
      :cur_row, :uint,
      :noskip_del, :int,  # don't skip deleted rows 
      # object allocation map 
      :map_base_pg, :uint32,
      :map_sz, :size_t,
      :usage_map, :pointer,  # unsigned char
      # pages with free space left 
      :freemap_base_pg, :uint32,
      :freemap_sz, :size_t,
      :free_usage_map, :pointer,  # unsigned char
      # query planner 
      :sarg_tree, :pointer,  # MdbSargNode
      :strategy, :Strategy,
      :scan_idx, :pointer,  # MdbIndex
      :mdbidx, :pointer,  # MdbHandle
      :chain, :pointer,  # MdbIndexChain
      :props, :pointer,  # MdbProperties
      :num_var_cols, :uint,  # to know if row has variable columns 
      # temp table 
      :is_temp_table, :uint,
      :temp_table_pages, :pointer #GLib::GPtrArray
  end
  
  class Column < NiceFFI::Struct
    layout \
      :name, [:char, MDB_MAX_OBJ_NAME+1], # :table, :pointer, # struct S_MdbTableDef
      :col_type, :ColType,
      :col_size, :int,
      :bind_ptr, :pointer,  # void
      :len_ptr, :pointer, # int
      :properties, :pointer,  # GHashTable
      :num_sargs, :uint,
      :sargs, :pointer, # GLib::GPtrArray
      :idx_sarg_cache, :pointer, # GLib::GPtrArray
      :is_fixed, :uchar,
      :query_order, :int,
      # col_num is the current column order, 
      # does not include deletes 
      :col_num, :int, 
      :cur_value_start, :int,
      :cur_value_len, :int,
      # MEMO/OLE readers 
      :cur_blob_pg_row, :uint32,
      :chunk_size, :int,
      # numerics only 
      :col_prec, :int,
      :col_scale, :int,
      :is_long_auto, :uchar,
      :is_uuid_auto, :uchar,
      :props, :pointer,  # MdbProperties
      # info needed for handling deleted/added columns 
      :fixed_offset, :int,
      :var_col_num, :uint,
      # row_col_num is the row column number order, 
      # including deleted columns 
      :row_col_num, :int
  end
  
  class BoundValue < NiceFFI::Struct
    layout :value, [:char, 256] # from data.c, in mdb_data_dump
  end
  
  class BoundLength < NiceFFI::Struct
    layout :len, :int
  end
end

module LibMDB
  extend NiceFFI::Library
  load_library 'mdb'

  attach_function :init, :mdb_init, [], :void
  attach_function :open, :mdb_open, [:string, MDB::FileFlag], :pointer
  attach_function :read_table_by_name, :mdb_read_table_by_name, [:pointer, :string, MDB::ObjType], :pointer
  attach_function :read_columns, :mdb_read_columns, [:pointer], :void
  attach_function :rewind_table, :mdb_rewind_table, [:pointer], :void
  attach_function :fetch_row, :mdb_fetch_row, [:pointer], :int
  attach_function :bind_column, :mdb_bind_column, [:pointer, :int, :pointer, :pointer], :void
  attach_function :read_catalog, :mdb_read_catalog, [:pointer, MDB::ObjType], :pointer
end