module Arango
  module Requests
    module Document
      class Head < Arango::Request
        request_method :head

        uri_template '{/dbcontext}/_api/document/{collection}/{key}'

        header 'If-None-Match'
        header 'If-Match'

        code 200, :success
        code 304, :success
        code 404, "Document or collection not found!"
        code 412, "If-Match header was given but the found document has a different version!"
      end
    end
  end
end
