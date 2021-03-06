module Arango
  module Requests
    module Administration
      class Endpoints < Arango::Request
        request_method :get

        uri_template "/_api/endpoint"

        code 200, :success
        code 400, "The action is not carried out in the system database!"
        code 405, "An unsupported HTTP method!"

      end
    end
  end
end
