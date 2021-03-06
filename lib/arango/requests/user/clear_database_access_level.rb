module Arango
  module Requests
    module User
      class ClearDatabaseAccessLevel < Arango::Request
        request_method :delete

        uri_template '{/dbcontext}/_api/user/{user}/database/{database}'

        code 202, :success
        code 400, "JSON representation is malformed!"
      end
    end
  end
end
