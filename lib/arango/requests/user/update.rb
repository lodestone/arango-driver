module Arango
  module Requests
    module User
      class Update < Arango::Request
        request_method :patch

        uri_template '{/dbcontext}/_api/user/{user}'

        body :passwd
        body :active
        body :extra

        code 200, :success
        code 400, "JSON malformed or mandatory data is missing!"
        code 401, "No database access to the _system database!"
        code 403, "No server access!"
        code 404, "User does not exist!"
      end
    end
  end
end
