module Arango
  module Requests
    module User
      class Delete < Arango::Request
        request_method :delete

        uri_template '{/dbcontext}/_api/user/{user}'

        code 201, :success
        code 401, "No database access to the _system database!"
        code 403, "No server access!"
      end
    end
  end
end
