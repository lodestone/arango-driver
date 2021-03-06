module Arango
  module Requests
    module Document
      class Replace < Arango::Request
        request_method :put

        uri_template '{/dbcontext}/_api/document/{collection}/{key}'

        header 'If-Match'

        param :ignore_revs
        param :return_new
        param :return_old
        param :silent
        param :wait_for_sync

        body_any

        code 201, :success
        code 202, :success
        code 400, "The JSON representation is malformed!"
        code 404, "Document or collection not found!"
        code 412, "If-Match header was given but the found document has a different version!"
      end
    end
  end
end
