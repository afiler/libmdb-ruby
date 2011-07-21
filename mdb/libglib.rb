require 'nice-ffi'

module GLib
  class GArray < NiceFFI::Struct
    layout :pdata, :pointer, :len, :uint
  end
  
  class GPtrArray < NiceFFI::Struct
    layout :pdata, :pointer, :len, :uint
  end
  
  def self.PtrArrayOf(cls)
    c = Array.dup
    c.instance_variable_set :@cls, cls

    def c.new(ptr)
      @cls = eval(@cls.to_s) unless @cls.is_a? Class
      ptr_array = GLib::GPtrArray.new ptr
      return unless ptr_array and ptr_array.pdata and ptr_array.len > 0
      ptr_array.pdata.read_array_of_type(:pointer, :read_pointer, ptr_array.len).map do |ptr|
        @cls.new ptr
      end
    end

    return NiceFFI::TypedPointer(c)
  end
end