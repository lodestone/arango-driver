module Arango
  module Requests
    module User
      class List < Arango::Request
        request_method :get

        uri_template '{/dbcontext}/_api/user/'

        code 201, :success
        code 401, "No database access to the _system database!"
        code 403, "No server access!"
      end
    end
  end
end
