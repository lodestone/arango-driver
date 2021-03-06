module Arango
  module Requests
    module Administration
      class Echo < Arango::Request
        request_method :post

        uri_template "/_admin/echo"

        body_any

        code 200, :success
      end
    end
  end
end
