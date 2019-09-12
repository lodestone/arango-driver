# === GRAPH ===

module Arango
  class Graph
    include Arango::Helper::Satisfaction
    include Arango::Helper::Return
    include Arango::Helper::DatabaseAssignment

    def self.new(*args)
      hash = args[0]
      super unless hash.is_a?(Hash)
      database = hash[:database]
      if database.is_a?(Arango::Database) && database.server.active_cache
        cache_name = "#{database.name}/#{hash[:name]}"
        cached = database.server.cache.cache.dig(:graph, cache_name)
        if cached.nil?
          hash[:cache_name] = cache_name
          return super
        else
          body = hash[:body] || {}
          %i[isSmart edgeDefinitions orphanDollections numberOfShards replicationFactor smartGraphAttribute].each{|k| body[k] ||= hash[k]}
          cached.assign_attributes(body)
          return cached
        end
      end
      super
    end

    def initialize(name:, database:, body: {}, cache_name: nil, edge_definitions: [], is_smart: nil, number_of_shards: nil, orphan_collections: [],
                   replication_factor: nil, smart_graph_attribute: nil)
      assign_database(database)
      unless cache_name.nil?
        @cache_name = cache_name
        @server.cache.save(:graph, cache_name, self)
      end
      body[:_key]    ||= name
      body[:_id]     ||= "_graphs/#{name}"
      body[:edgeDefinitions]     ||= edge_definitions
      body[:isSmart]             ||= is_smart
      body[:numberOfShards]      ||= number_of_shards
      body[:orphanCollections]   ||= orphan_collections
      body[:replicationFactor]   ||= replication_factor
      body[:smartGraphAttribute] ||= smart_graph_attribute
      assign_attributes(body)
    end

# === DEFINE ===

    attr_reader :body, :cache_name, :database, :id, :is_smart, :name, :rev, :server
    attr_accessor :number_of_shards, :replication_factor, :smart_graph_attribute
    alias key name

    def body=(result)
      @body = result
      assign_edge_definitions(result[:edgeDefinitions] || @edge_definitions)
      assign_orphan_collections(result[:orphanCollections] || @orphan_collections)
      @name    = result[:_key]    || @name
      @id      = result[:_id]     || @id
      @id      = "_graphs/#{@name}" if @id.nil? && !@name.nil?
      @rev     = result[:_rev]    || @rev
      @is_smart = result[:isSmart] || @is_smart
      @number_of_shards = result[:numberOfShards] || @number_of_shards
      @replication_factor = result[:replicationFactor] || @replication_factor
      @smart_graph_attribute = result[:smartGraphAttribute] || @smart_graph_attribute
      if @server.active_cache && @cache_name.nil?
        @cache_name = "#{@database.name}/#{@name}"
        @server.cache.save(:graph, @cache_name, self)
      end
    end
    alias assign_attributes body=

    def name=(name)
      @name = name
      @id = "_graphs/#{@name}"
    end

    def return_collection(collection, type=nil)
      satisfy_class?(collection, [Arango::Collection, String])
      case collection
      when Arango::Collection
        return collection
      when String
        return Arango::Collection.new(name: collection,
          database: @database, type: type, graph: self)
      end
    end

    def edge_definitions_raw
      @edge_definitions ||= []
      @edge_definitions.map do |edgedef|
        {
          collection: edgedef[:collection].name,
          from: edgedef[:from].map{|t| t.name},
          to: edgedef[:to].map{|t| t.name}
        }
      end
    end
    private :edge_definitions_raw

    def edge_definitions(raw=false)
      return edge_definitions_raw if raw
      return @edge_definitions
    end

    def edge_definitions=(edge_definitions)
      @edge_definitions = []
      edge_definitions ||= []
      edge_definitions = [edge_definitions] unless edge_definitions.is_a?(Array)
      edge_definitions.each do |edge_definition|
        hash = {}
        hash[:collection] = return_collection(edge_definition[:collection], :edge)
        edge_definition[:from] ||= []
        edge_definition[:to]   ||= []
        hash[:from] = edge_definition[:from].map{|t| return_collection(t)}
        hash[:to]   = edge_definition[:to].map{|t| return_collection(t)}
        setup_orphan_collection_after_adding_edge_definitions(hash)
        @edge_definitions << hash
      end
    end
    alias assign_edge_definitions edge_definitions=

    def orphan_collections=(orphan_collections)
      orphan_collections ||= []
      orphan_collections = [orphan_collections] unless orphan_collections.is_a?(Array)
      @orphan_collections = orphan_collections.map{|oc| add_orphan_collection(oc)}
    end
    alias assign_orphan_collections orphan_collections=

    def orphan_collections_raw
      @orphan_collections ||= []
      @orphan_collections.map{|oc| oc.name}
    end
    private :orphan_collections_raw

    def orphan_collections(raw=false)
      return orphan_collections_raw if raw
      return @orphan_collections
    end

# === HANDLE ORPHAN COLLECTION ===

    def add_orphan_collection(orphanCollection)
      orphanCollection = return_collection(orphanCollection)
      if @edge_definitions.any? do |ed|
          names = []
          names |= ed[:from].map{|f| f&.name}
          names |= ed[:to].map{|t| t&.name}
          names.include?(orphanCollection.name)
        end
        raise Arango::Error.new err: :orphan_collection_used_by_edge_definition, data: {collection: orphanCollection.name}
      end
      return orphanCollection
    end
    private :add_orphan_collection

    def setup_orphan_collection_after_adding_edge_definitions(edge_definition)
      collection = []
      collection |= edge_definition[:from]
      collection |= edge_definition[:to]
      @orphan_collections.delete_if{|c| collection.include?(c.name)}
    end
    private :setup_orphan_collection_after_adding_edge_definitions

    def setup_orphan_collection_after_removing_edge_definitions(edge_definition)
      edgeCollection = edge_definition[:collection].name
      collections |= []
      collections |= edge_definition[:from]
      collections |= edge_definition[:to]
      collections.each do |collection|
        unless @edge_definitions.any? do |ed|
            if ed[:collection].name != edgeCollection
              names = []
              names |= ed[:from].map{|f| f&.name}
              names |= ed[:to].map{|t| t&.name}
              names.include?(collection.name)
            else
              false
            end
          end
          unless @orphan_collections.map{|oc| oc.name}.include?(collection.name)
            @orphan_collections << collection
          end
        end
      end
    end
    private :setup_orphan_collection_after_removing_edge_definitions

# === REQUEST ===

    def request(action, url, body: {}, headers: {}, query: {}, key: nil, return_direct_result: false, skip_to_json: false)
      url = "_api/gharial/#{@name}/#{url}"
      @database.request(action, url, body: body, headers: headers,
        query: query, key: key, return_direct_result: return_direct_result,
        skip_to_json: skip_to_json)
    end

# === TO HASH ===

    def to_h
      {
        name: @name,
        id: @id,
        rev: @rev,
        isSmart: @is_smart,
        numberOfShards: @number_of_shards,
        replicationFactor: @replication_factor,
        smartGraphAttribute: @smart_graph_attribute,
        edgeDefinitions: edge_definitions_raw,
        orphanCollections: orphan_collections_raw,
        cache_name: @cache_name,
        database: @database.name
      }.delete_if{|k,v| v.nil?}
    end

# === GET ===

    def retrieve
      result = @database.request("GET", "_api/gharial/#{@name}", key: :graph)
      return_element(result)
    end

# === POST ===

    def create(is_smart: @is_smart, smart_graph_attribute: @smart_graph_attribute,
      number_of_shards: @number_of_shards)
      body = {
        name: @name,
        edgeDefinitions:   edge_definitions_raw,
        orphanCollections: orphan_collections_raw,
        isSmart: is_smart,
        options: {
          smartGraphAttribute: smart_graph_attribute,
          numberOfShards: number_of_shards
        }
      }
      body[:options].delete_if{|k,v| v.nil?}
      body.delete(:options) if body[:options].empty?
      result = @database.request("POST", "_api/gharial", body: body, key: :graph)
      return_element(result)
    end

# === DELETE ===

    def destroy(dropCollections: nil)
      query = { dropCollections: dropCollections }
      result = @database.request("DELETE", "_api/gharial/#{@name}", query: query,
        key: :removed)
      return_delete(result)
    end

# === VERTEX COLLECTION  ===

    def get_vertex_collections
      result = request("GET", "vertex", key: :collections)
      return result if return_directly?(result)
      result.map do |x|
        Arango::Collection.new(name: x, database: @database, graph: self)
      end
    end
    alias vertex_collections get_vertex_collections

    def add_vertex_collection(collection:)
      satisfy_class?(collection, [String, Arango::Collection])
      collection = collection.is_a?(String) ? collection : collection.name
      body = { collection: collection }
      result = request("POST", "vertex", body: body, key: :graph)
      return_element(result)
    end

    def remove_vertex_collection(collection:, dropCollection: nil)
      query = {dropCollection: dropCollection}
      satisfy_class?(collection, [String, Arango::Collection])
      collection = collection.is_a?(String) ? collection : collection.name
      result = request("DELETE", "vertex/#{collection}", query: query, key: :graph)
      return_element(result)
    end

  # === EDGE COLLECTION ===

    def get_edge_collections
      result = request("GET", "edge", key: :collections)
      return result if @database.server.async != false
      return result if return_directly?(result)
      result.map{|r| Arango::Collection.new(database: @database, name: r, type: :edge)}
    end

    def add_edge_definition(collection:, from:, to:)
      satisfy_class?(collection, [String, Arango::Collection])
      satisfy_class?(from, [String, Arango::Collection], true)
      satisfy_class?(to, [String, Arango::Collection], true)
      from = [from] unless from.is_a?(Array)
      to = [to] unless to.is_a?(Array)
      body = {}
      body[:collection] = collection.is_a?(String) ? collection : collection.name
      body[:from] = from.map{|f| f.is_a?(String) ? f : f.name }
      body[:to] = to.map{|t| t.is_a?(String) ? t : t.name }
      result = request("POST", "edge", body: body, key: :graph)
      return_element(result)
    end

    def replace_edge_definition(collection:, from:, to:)
      satisfy_class?(collection, [String, Arango::Collection])
      satisfy_class?(from, [String, Arango::Collection], true)
      satisfy_class?(to, [String, Arango::Collection], true)
      from = [from] unless from.is_a?(Array)
      to = [to] unless to.is_a?(Array)
      body = {}
      body[:collection] = collection.is_a?(String) ? collection : collection.name
      body[:from] = from.map{|f| f.is_a?(String) ? f : f.name }
      body[:to] = to.map{|t| t.is_a?(String) ? t : t.name }
      result = request("PUT", "edge/#{body[:collection]}", body: body, key: :graph)
      return_element(result)
    end

    def remove_edge_definition(collection:, dropCollection: nil)
      satisfy_class?(collection, [String, Arango::Collection])
      query = {dropCollection: dropCollection}
      collection = collection.is_a?(String) ? collection : collection.name
      result = request("DELETE", "edge/#{collection}", query: query, key: :graph)
      return_element(result)
    end
  end
end