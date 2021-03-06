module Arango
  module Requests
    module Collection
      class Checksum < Arango::Request
        request_method :get

        uri_template "/_api/collection/{name}/checksum"

        param :with_data
        param :with_revisions

        code 200, :success
        code 400, "Collection name is missing!"
        code 404, "Collection is unknown!"
      end
    end
  end
end
