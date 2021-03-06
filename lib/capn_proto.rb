require 'capn_proto/capn_proto'
require 'capn_proto/version'

module CapnProto
  ListNestedNodeReader.class_eval do
    include Enumerable
    def each
      return to_enum(:each) unless block_given?
      (0...size).each do |n|
        yield self[n]
      end
    end
  end

  DynamicListReader.class_eval do
    include Enumerable
    def each
      return to_enum(:each) unless block_given?
      (0...size).each do |n|
        yield self[n]
      end
    end
  end

  DynamicListBuilder.class_eval do
    include Enumerable
    def each
      return to_enum(:each) unless block_given?
      (0...size).each do |n|
        yield self[n]
      end
    end
  end

  DynamicStructReader.class_eval do
    def method_missing(name, *args, &block)
      name = name.to_s

      if name.end_with?("?")
        which == name[0..-2]
      else
        self[name]
      end
    end
  end

  DynamicStructBuilder.class_eval do
    def method_missing(name, *args, &block)
      name = name.to_s

      if name.start_with?("init") && name.size > 4
        name = name[4..-1]
        name[0] = name[0].downcase
        init(name, *args)
      elsif name.end_with?("=")
        name = name[0..-2]
        self[name] = args[0]
      elsif name.end_with?("?")
        which == name[0..-2]
      else
        self[name]
      end
    end
  end

  module SchemaLoader
    def schema_parser
      @schema_parser
    end

    def load_schema(file_name, imports=[])
      display_name = self.name

      @schema_parser ||= CapnProto::SchemaParser.new

      load_schema_rec = Proc.new do |schema, mod|
        node = schema.get_proto
        nested_nodes = node.nested_nodes

        if node.struct?
          struct_schema = schema.as_struct
          mod.instance_variable_set(:@schema, struct_schema)
          mod.extend(Struct)
        end

        nested_nodes.each do |nested_node|
          const_name = nested_node.name
          const_name[0] = const_name[0].upcase
          nested_mod = mod.const_set(const_name, Module.new)
          nested_schema = schema.get_nested(nested_node.name)
          load_schema_rec.call(nested_schema, nested_mod)
        end
      end

      schema = @schema_parser.parse_disk_file(
        display_name,
        file_name,
        imports);

      load_schema_rec.call(schema, self)
    end

    module Struct
      def schema
        @schema
      end

      def read_from(io)
        reader = StreamFdMessageReader.new(io)
        reader.get_root(self)
      end

      def make_from_bytes(bytes)
        # TODO: support FFI pointers
        reader = FlatArrayMessageReader.new(bytes)
        reader.get_root(self)
      end

      def new_message
        builder = MallocMessageBuilder.new
        builder.init_root(self)
      end

      def read_packed_from(io)
        raise 'not implemented'
      end
    end
  end
end
