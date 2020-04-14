module Arango
  module Requests
    module Graph
      class Remove
        EdgeDefinition < Arango::Request
        request_method :delete

        uri_template '{/dbcontext}/_api/gharial/{graph}/edge/{definition}#definition'

        body :collection
        body :from
        body :to

        code 201, :success
        code 202, :success
        code 400, "Definition could be added because it is ill-formed or used in another graph with a different signature!"
        code 403, "Permission denied!"
        code 404, "Graph could not be found!"
      end
    end
  end
end
