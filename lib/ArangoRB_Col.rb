# === COLLECTION ===

class ArangoC < ArangoS
  def initialize(collection: @@collection, database: @@database, body: {}, type: nil)
    if collection.is_a?(String)
      @collection = collection
    else
      raise "collection should be a String, not a #{collection.class}"
    end

    if database.is_a?(String)
      @database = database
    else
      raise "database should be a String, not a #{database.class}"
    end

    if body.is_a?(Hash)
      @body = body
    else
      raise "body should be a String, not a #{body.class}"
    end

    if !@type.nil? && @type != "Document" && @type != "Edge"
      raise "type should be \"Document\" or \"Edge\""
    else
      @type = type
      if @type == "Document"
        @body["type"] = 2
      elsif @type == "Edge"
        @body["type"] = 3
      end
    end
  end

  attr_reader :database, :collection, :body, :type

  # === GET ===

  def retrieve
    result = self.class.get("/_db/#{@database}/_api/collection/#{@collection}").parsed_response
    self.return_result(result, true)
  end

  def properties
    result = self.class.get("/_db/#{@database}/_api/collection/#{@collection}/properties").parsed_response
    @@verbose ? result : result["error"] ? result["errorMessage"] : result
  end

  def count
    result = self.class.get("/_db/#{@database}/_api/collection/#{@collection}/count").parsed_response
    @@verbose ? result : result["error"] ? result["errorMessage"] : result["count"]
  end

  def stats
    result = self.class.get("/_db/#{@database}/_api/collection/#{@collection}/figures").parsed_response
    @@verbose ? result : result["error"] ? result["errorMessage"] : result["figures"]
  end

  # def revisions
  #   self.class.get("/_db/#{@database}/_api/collection/#{@collection}/revisions").parsed_response
  # end

  def checksum(withRevisions: nil, withData: nil)
    query = {
      "withRevisions": withRevisions,
      "withData": withData
    }.delete_if{|k,v| v.nil?}
    new_Document = { :query => query }
    result = self.class.get("/_db/#{@database}/_api/collection/#{@collection}/checksum", new_Document).parsed_response
    @@verbose ? result : result["error"] ? result["errorMessage"] : result["checksum"]
  end

  # === POST ===

  def create(type: nil, journalSize: nil, keyOptions: nil, waitForSync: nil, doCompact: nil, isVolatile: nil, shardKeys: nil, numberOfShards: nil, isSystem: nil, indexBuckets: nil)
    body = {
      "name" => collection,
      "type" => type,
      "journalSize" => journalSize,
      "keyOptions" => keyOptions,
      "waitForSync" => waitForSync,
      "doCompact" => doCompact,
      "isVolatile" => isVolatile,
      "shardKeys" => shardKeys,
      "numberOfShards" => numberOfShards,
      "isSystem" => isSystem,
      "indexBuckets" => indexBuckets
    }
    body = body.delete_if{|k,v| v.nil?}.to_json
    new_Collection = { :body => body }
    result = self.class.post("/_db/#{@database}/_api/collection", new_Collection).parsed_response
    self.return_result(result, true)
  end
  alias create_collection create
  alias create_document_collection create
  alias create_vertex_collection create

  def create_edge_collection(journalSize: nil, keyOptions: nil, waitForSync: nil, doCompact: nil, isVolatile: nil, shardKeys: nil, numberOfShards: nil, isSystem: nil, indexBuckets: nil)
    self.create type: 3, journalSize: journalSize, keyOptions: keyOptions, waitForSync: waitForSync, doCompact: doCompact, isVolatile: isVolatile, shardKeys: shardKeys, numberOfShards: numberOfShards, isSystem: isSystem, indexBuckets: indexBuckets
  end

  def create_document(document: {}, waitForSync: nil, returnNew: nil)
    if document.is_a? Hash
      body = document
    elsif document.is_a? ArangoDoc
      body = document.body
    elsif document.is_a? Array
      body = document.map{|x| x.is_a?(Hash) ? x : x.is_a?(ArangoDoc) ? x.body : nil}
    else
      raise "document should be Hash, an ArangoDoc instance or an Array of Hashes or ArangoDoc instances"
    end
    ArangoDoc.create(body: body, waitForSync: waitForSync, returnNew: returnNew, database: @database, collection: @collection)
  end
  alias create_vertex create_document

  def create_edge(document: {}, from:, to:, waitForSync: nil, returnNew: nil)
    if document.is_a? Hash
      body = document
    elsif document.is_a? ArangoDoc
      body = document.body
    elsif document.is_a? Array
      body = document.map{|x| x.is_a?(Hash) ? x : x.is_a?(ArangoDoc) ? x.body : nil}
    else
      raise "document should be Hash, an ArangoDoc instance or an Array of Hashes or ArangoDoc instances"
    end
    ArangoDoc.create_edge(body: body, from: from, to: to, waitForSync: waitForSync, returnNew: returnNew, database: @database, collection: @collection)
  end

  # === DELETE ===

  def destroy
    result = self.class.delete("/_db/#{@database}/_api/collection/#{@collection}").parsed_response
    @@verbose ? result : result["error"] ? result["errorMessage"] : true
  end

  def truncate
    result = self.class.put("/_db/#{@database}/_api/collection/#{@collection}/truncate").parsed_response
    self.return_result(result)
  end

  # === MODIFY ===

  def load
    result = self.class.put("/_db/#{@database}/_api/collection/#{@collection}/load").parsed_response
    self.return_result(result)
  end

  def unload
    result = self.class.put("/_db/#{@database}/_api/collection/#{@collection}/unload").parsed_response
    self.return_result(result)
  end

  def change(waitForSync: nil, journalSize: nil)
    body = {
      "journalSize" => journalSize,
      "waitForSync" => waitForSync
    }
    body = body.delete_if{|k,v| k.nil?}.to_json
    new_Collection = { :body => body }
    result = self.class.put("/_db/#{@database}/_api/collection/#{@collection}/properties", new_Collection).parsed_response
    self.return_result(result)
  end

  def rename(newName)
    body = { "name" => newName }
    new_Collection = { :body => body.to_json }
    result = self.class.put("/_db/#{@database}/_api/collection/#{@collection}/rename", new_Collection).parsed_response
    @collection = newName unless result["error"]
    self.return_result(result)
  end

  # === SIMPLE FUNCTIONS ===

  def documents(type: nil) # "path", "id", "key"
    body = {
      "collection" => @collection,
      "type" => type
    }.delete_if{|k,v| v.nil?}.to_json
    collection_to_look = { :body => body }
    result = self.class.put("/_db/#{@database}/_api/simple/all-keys", collection_to_look).parsed_response
    if type.nil?
      if @@verbose
        result
      else
        if result["error"]
          result["errorMessage"]
        else
          result["result"].map{|x| value = self.class.get(x).parsed_response; ArangoDoc.new(key: value["_key"], collection: @collection, body: value)}
        end
      end
    else
      @@verbose ? result : result["error"] ? result["errorMessage"] : result["result"]
    end
  end

  def allDocuments(skip: nil, limit: nil, batchSize: nil)
    body = {
      "collection" => @collection,
      "skip" => skip,
      "limit" => limit,
      "batchSize" => batchSize
    }.delete_if{|k,v| v.nil?}.to_json
    collection_to_look = { :body => body }
    result = self.class.put("/_db/#{@database}/_api/simple/all", collection_to_look).parsed_response
    if @@verbose
      result
    else
      if result["error"]
        result["errorMessage"]
      else
        result["result"].map{|x| ArangoDoc.new(key: x["_key"], collection: @collection, body: x)}
      end
    end
  end

  def documentsMatch(match:, skip: nil, limit: nil, batchSize: nil)
    body = {
      "collection" => @collection,
      "example" => match,
      "skip" => skip,
      "limit" => limit,
      "batchSize" => batchSize
    }.delete_if{|k,v| v.nil?}.to_json
    collection_to_look = { :body => body }
    result = self.class.put("/_db/#{@database}/_api/simple/by-example", collection_to_look).parsed_response
    if @@verbose
      result
    else
      if result["error"]
        result["errorMessage"]
      else
        result["result"].map{|x| ArangoDoc.new(key: x["_key"], collection: @collection, body: x)}
      end
    end
  end

  def documentMatch(match:)
    body = {
      "collection" => @collection,
      "example" => match
    }.delete_if{|k,v| v.nil?}.to_json
    collection_to_look = { :body => body }
    result = self.class.put("/_db/#{@database}/_api/simple/first-example", collection_to_look).parsed_response
    if @@verbose
      result
    else
      if result["error"]
        result["errorMessage"]
      else
        ArangoDoc.new(key: result["document"]["_key"], collection: @collection, body: result["document"])
      end
    end
  end

  def documentByKeys(keys:)
    keys = keys.map{|x| x.is_a?(String) ? x : x.is_a?(ArangoDoc) ? x.key : nil} if keys.is_a? Array
    keys = [keys] if keys.is_a? String
    body = { "collection" => @collection, "keys" => keys }
    collection_to_look = { :body => body.to_json }
    result = self.class.put("/_db/#{@database}/_api/simple/lookup-by-keys", collection_to_look).parsed_response
    if @@verbose
      result
    else
      if result["error"]
        result["errorMessage"]
      else
        result["documents"].map{|x| ArangoDoc.new(key: x["_key"], collection: @collection, body: x)}
      end
    end
  end

  def random
    body = { "collection" => @collection }
    collection_to_look = { :body => body.to_json }
    result = self.class.put("/_db/#{@database}/_api/simple/any", collection_to_look)
    if @@verbose
      result
    else
      if result["error"]
        result["errorMessage"]
      else
        ArangoDoc.new(key: result["document"]["_key"], collection: @collection, body: result["document"])
      end
    end
  end

  def removeByKeys(keys:, options: nil)
    keys = keys.map{|x| x.is_a?(String) ? x : x.is_a?(ArangoDoc) ? x.key : nil}
    body = { "collection" => @collection, "keys" => keys, "options" => options }.delete_if{|k,v| v.nil?}
    collection_to_look = { :body => body.to_json }
    self.class.put("/_db/#{@database}/_api/simple/remove-by-keys", collection_to_look).parsed_response
  end

  def removeMatch(match:, options: nil)
    body = {
      "collection" => @collection,
      "example" => match,
      "options" => option
    }.delete_if{|k,v| v.nil?}.to_json
    collection_to_look = { :body => body }
    self.class.put("/_db/#{@database}/_api/simple/remove-by-example", collection_to_look).parsed_response
  end

  def replaceMatch(match:, newValue:, options: nil)
    body = {
      "collection" => @collection,
      "example" => match,
      "options" => option,
      "newValue" => newValue
    }.delete_if{|k,v| v.nil?}.to_json
    collection_to_look = { :body => body }
    self.class.put("/_db/#{@database}/_api/simple/replace-by-example", collection_to_look).parsed_response
  end

  def updateMatch(match:, newValue:, options: nil)
    body = {
      "collection" => @collection,
      "example" => match,
      "options" => option,
      "newValue" => newValue
    }.delete_if{|k,v| v.nil?}.to_json
    collection_to_look = { :body => body }
    self.class.put("/_db/#{@database}/_api/simple/update-by-example", collection_to_look).parsed_response
  end

# === IMPORT ===

  def import(attributes:, values:, from: nil, to: nil, overwrite: nil, waitForSync: nil, onDuplicate: nil, complete: nil, details: nil)
    query = {
      "collection": @collection,
      "fromPrefix": from,
      "toPrefix": to,
      "overwrite": overwrite,
      "waitForSync": waitForSync,
      "onDuplicate": onDuplicate,
      "complete": complete,
      "details": details
    }.delete_if{|k,v| v.nil?}
    body = []
    body << attributes
    body << values
    new_Document = { :body => body.to_json, :query => query }
    result = self.class.post("/_db/#{@database}/_api/import", new_Document).parsed_response
    if @@verbose
      unless result["errorMessage"]
        result.delete("error")
        result.delete("code")
      end
      result
    else
      if result["error"]
        result["errorMessage"]
      else
        result.delete("error")
        result.delete("code")
        result
      end
    end
  end

  def importJSON(body:, type: "auto", from: nil, to: nil, overwrite: nil, waitForSync: nil, onDuplicate: nil, complete: nil, details: nil)
    query = {
      "collection": @collection,
      "type": type,
      "fromPrefix": from,
      "toPrefix": to,
      "overwrite": overwrite,
      "waitForSync": waitForSync,
      "onDuplicate": onDuplicate,
      "complete": complete,
      "details": details
    }.delete_if{|k,v| v.nil?}
    new_Document = { :body => body.to_json, :query => query }
    result = self.class.post("/_db/#{@database}/_api/import", new_Document).parsed_response
    if @@verbose
      result
    else
      if result["error"]
        result["errorMessage"]
      else
        result.delete("error")
        result.delete("code")
        result
      end
    end
  end

# === INDEXES ===

  def retrieveIndex(id:)
    result = self.class.get("/_db/#{@database}/_api/index/#{@collection}/#{id}").parsed_response
    if @@verbose
      result
    else
      if result["error"]
        result["errorMessage"]
      else
        result.delete("error")
        result.delete("code")
        result
      end
    end
  end

  def indexes
    query = { "collection": @collection }
    new_Document = { :query => query }
    result = self.class.get("/_db/#{@database}/_api/index", new_Document).parsed_response
    if @@verbose
      result
    else
      if result["error"]
        result["errorMessage"]
      else
        result.delete("error")
        result.delete("code")
        result
      end
    end
  end

  def createIndex(body: nil)
    query = { "collection": @collection }
    new_Document = { :body => body.to_json, :query => query }
    result = self.class.post("/_db/#{@database}/_api/index", new_Document).parsed_response
    if @@verbose
      result
    else
      if result["error"]
        result["errorMessage"]
      else
        result.delete("error")
        result.delete("code")
        result
      end
    end
  end

  def deleteIndex(id:)
    result = self.class.delete("/_db/#{@database}/_api/index/#{@collection}/#{id}").parsed_response
    @@verbose ? result : result["error"] ? result["errorMessage"] : true
  end

# === REPLICATION ===

  def inventory(from: nil, to: nil, chunkSize: nil, includeSystem: false, failOnUnknown: nil, ticks: nil, flush: nil)
    query = {
      "collection": @collection,
      "from": from,
      "to": to,
      "chunkSize": chunkSize,
      "includeSystem": includeSystem,
      "failOnUnknown": failOnUnknown,
      "ticks": ticks,
      "flush": flush
    }.delete_if{|k,v| v.nil?}
    new_Document = { :query => query }
    self.class.get("/_db/#{@database}/_api/replication/inventory", new_Document).parsed_response
  end

# === UTILITY ===

  def return_result(result, checkType=false)
    if @@verbose
      resultTemp = result
      unless result["errorMessage"]
        result.delete("error")
        result.delete("code")
        @body = result
        @type = result["type"] == 2 ? "Document" : "Edge" if(checkType)
      end
      resultTemp
    else
      if result["error"]
        result["errorMessage"]
      else
        result.delete("error")
        result.delete("code")
        @body = result
        @type = result["type"] == 2 ? "Document" : "Edge" if(checkType)
        self
      end
    end
  end
end
