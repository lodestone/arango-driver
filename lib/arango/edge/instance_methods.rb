module Arango
  module Edge
    module InstanceMethods
      extend Arango::Helper::RequestMethod

      def initialize(key: nil, attributes: {}, from: nil, to: nil, edge_collection:, ignore_revs: false, wait_for_sync: nil)
        @attributes = _attributes_from_arg(attributes)
        @attributes[:_key] = key if key
        @changed_attributes = {}
        @ignore_revs = ignore_revs
        @wait_for_sync = wait_for_sync
        _set_from(from || from_id)
        _set_to(to || to_id)
        send(:edge_collection=, edge_collection)
        send(:graph=, edge_collection.graph) if edge_collection.graph
      end

      def id
        i = @changed_attributes[:_id] || @attributes[:_id]
        return i if i
        "#{edge_collection.name}/#{key}"
      end

      def id=(i)
        @changed_attributes[:_id] = i
      end

      def key
        @changed_attributes[:_key] || @attributes[:_key]
      end

      def key=(k)
        @changed_attributes[:_key] = k
      end

      def revision
        @changed_attributes[:_rev] || @attributes[:_rev]
      end

      def revision=(r)
        @changed_attributes[:_rev] = r
      end

      def to_h
        @attributes.delete_if{ |_,v| v.nil? }
      end

      attr_accessor :ignore_revs, :wait_for_sync
      attr_reader :edge_collection, :graph, :database, :server, :attributes

      def attributes=(doc)
        @changed_attributes = _attributes_from_arg(doc)
      end

      def edge_collection=(edge_collection)
        satisfy_module?(edge_collection, Arango::EdgeCollection::Mixin)
        @edge_collection = edge_collection
        @graph = @edge_collection.graph
        @database = @edge_collection.database
        @arango_server = @database.arango_server
      end

      def graph=(graph)
        satisfy_module?(graph, Arango::Graph::Mixin)
        @graph = graph
        @database = @graph.database
        @arango_server = @graph.arango_server
      end

      def method_missing(name, *args, &block)
        name_s = name.to_s
        set_attr = false
        have_attr = false
        attribute_name_s = name_s.end_with?('=') ? (set_attr = true; name_s.chop) : name_s
        attribute_name_y = attribute_name_s.start_with?('attribute_') ? (have_attr = true; attribute_name_s[9..-1].to_sym) : attribute_name_s.to_sym
        if set_attr
          return @changed_attributes[attribute_name_y] = args[0]
        elsif @changed_attributes.key?(attribute_name_y)
          return @changed_attributes[attribute_name_y]
        elsif @attributes.key?(attribute_name_y)
          return @attributes[attribute_name_y]
        elsif have_attr
          return nil
        end
        super(name, *args, &block)
      end

      request_method :reload do
        headers = nil
        headers = { "If-Match": @attributes[:_rev] } if !@ignore_revs && @attributes.key?(:_rev)
        { get: "_api/document/#{@edge_collection.name}/#{@attributes[:_key]}", headers: headers,
          block: ->(result) do
            @attributes = _attributes_from_arg(result)
            @changed_attributes = {}
            self
          end
        }
      end
      alias refresh reload
      alias retrieve reload
      alias revert reload
      alias batch_refresh batch_reload
      alias batch_retrieve batch_reload
      alias batch_revert batch_reload

      request_method :same_revision? do
        headers = { "If-Match": @attributes[:_rev] }
        { head: "_api/document/#{@edge_collection.name}/#{@attributes[:_key]}", headers: headers, block: ->(result) { result.response_code == 200 }}
      end

      request_method :create do
        query = { returnNew: true }
        query[:waitForSync] = @wait_for_sync unless @wait_for_sync.nil?
        @attributes = @attributes.merge(@changed_attributes)
        @changed_attributes = {}
        { post: "_api/document/#{@edge_collection.name}", body: @attributes, query: query,
          block: ->(result) do
            @attributes.merge!(result[:new])
            self
          end
        }
      end

      request_method :replace do
        query = { returnNew: true, ignoreRevs: @ignore_revs }
        query[:waitForSync] = @wait_for_sync unless @wait_for_sync.nil?
        headers = nil
        attributes = @changed_attributes
        attributes[:_id] = @attributes[:_id]
        attributes[:_key] = @attributes[:_key]
        attributes[:_rev] = @attributes[:_rev]
        attributes[:_from] = from_id
        attributes[:_to] = to_id
        @attributes = attributes
        @changed_attributes = {}
        headers = { "If-Match": @attributes[:_rev] } if !@ignore_revs && @attributes.key?(:_rev)
        { put: "_api/document/#{@edge_collection.name}/#{@attributes[:_key]}", body: @attributes, query: query, headers: headers,
          block: ->(result) do
            @attributes.merge!(result[:new])
            self
          end
        }
      end

      request_method :save do
        query = { returnNew: true, ignoreRevs: @ignore_revs }
        query[:waitForSync] = @wait_for_sync unless @wait_for_sync.nil?
        headers = nil
        headers = { "If-Match": @attributes[:_rev] } if !@ignore_revs && @attributes.key?(:_rev)
        changed_attributes = @changed_attributes
        @changed_attributes = {}
        { patch: "_api/document/#{@edge_collection.name}/#{@attributes[:_key]}", body: changed_attributes, query: query, headers: headers,
          block: ->(result) do
            @attributes.merge!(result[:new])
            self
          end
        }
      end
      alias update save
      alias batch_update batch_save

      request_method :drop do
        query = { waitForSync: @wait_for_sync }
        headers = nil
        headers = { "If-Match": @attributes[:_rev] } if !@ignore_revs && @attributes.key?(:_rev)
        { delete: "_api/document/#{@edge_collection.name}/#{@attributes[:_key]}", query: query, headers: headers, block: ->(_) { nil }}
      end
      alias delete drop
      alias destroy drop
      alias batch_delete batch_drop
      alias batch_destroy batch_drop

      def from
        @from_instance ||= _get_instance(from_id)
      end

      def from_id
        @changed_attributes[:_from] || @attributes[:_from]
      end

      def from=(f)
        _set_from(f)
        from_id
      end

      def to
        @to_instance ||= _get_instance(to_id)
      end

      def to_id
        @changed_attributes[:_to] || @attributes[:_to]
      end

      def to=(t)
        _set_to(t)
        to_id
      end

      private

      def _attributes_from_arg(arg)
        return {} unless arg
        case arg
        when String then { _key: arg }
        when Hash
          arg.transform_keys!(&:to_sym)
          arg[:_id] = arg.delete(:id) if arg.key?(:id) && !arg.key?(:_id)
          arg[:_key] = arg.delete(:key) if arg.key?(:key) && !arg.key?(:_key)
          arg[:_rev] = arg.delete(:rev) if arg.key?(:rev) && !arg.key?(:_rev)
          arg[:_from] = arg.delete(:from) if arg.key?(:from) && !arg.key?(:_from)
          arg[:_to] = arg.delete(:to) if arg.key?(:to) && !arg.key?(:_to)
          arg.delete_if{|_,v| v.nil?}
          arg
        when Arango::Edge::Mixin then arg.to_h
        when Arango::Result then arg.to_h
        else
          raise "Unknown arg type, must be String, Hash, Arango::Result or Arango::Edge::Mixin."
        end
      end

      def _get_instance(id)

      end
      # request_method :_get_instance do |id|
      #   query = { returnNew: true }
      #   query[:waitForSync] = @wait_for_sync unless @wait_for_sync.nil?
      #   @attributes = @attributes.merge(@changed_attributes)
      #   @changed_attributes = {}
      #   { post: "_api/document/#{@edge_collection.name}", body: @attributes, query: query,
      #     block: ->(result) do
      #       @attributes.merge!(result[:new])
      #       self
      #     end
      #   }
      # end

      def _set_from(f)
        raise "from must be given" unless f
        if f.class == String
          @attributes[:_from] = f
          @from_instance = nil
        elsif f.is_a?(Arango::Document::Mixin)
          @attributes[:_from] = f.id
          @from_instance = f
        else
          raise "from is not valid"
        end
      end

      def _set_to(t)
        raise "to must be given" unless t
        if t.class == String
          @attributes[:_to] = t
          @to_instance = nil
        elsif t.is_a?(Arango::Document::Mixin)
          @attributes[:_to] = t.id
          @to_instance = t
        else
          raise "to is not valid"
        end
      end
    end
  end
end
