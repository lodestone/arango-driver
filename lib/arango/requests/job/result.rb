module Arango
  module Requests
    module Job
      class Result < Arango::Request
        request_method :put

        uri_template '{/dbcontext}/_api/job/{id}'

        code 204, :success
        code 400, "No job id given!"
        code 404, "Job unknown!"
      end
    end
  end
end
