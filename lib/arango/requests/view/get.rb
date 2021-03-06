module Arango
  module Requests
    module View
      class Get < Arango::Request
        request_method :get

        uri_template '{/dbcontext}/_api/view/{name}'

        code 200, :success
        code 404, "View unknown!"
      end
    end
  end
end
