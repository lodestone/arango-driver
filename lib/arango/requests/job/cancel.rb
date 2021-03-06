module Arango
  module Requests
    module Job
      class Cancel < Arango::Request
        request_method :put

        uri_template '{/dbcontext}/_api/job/{id}/cancel'

        code 200, :success
        code 400, "No type given or type invalid!"
        code 404, "Job unknown!"
      end
    end
  end
end
