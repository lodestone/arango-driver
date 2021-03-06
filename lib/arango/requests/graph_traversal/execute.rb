module Arango
  module Requests
    module GraphTraversal
      class Execute < Arango::Request
        request_method :post

        uri_template '{/dbcontext}/_api/traversal'

        body :direction
        body :edge_collection
        body :expander
        body :filter
        body :graph_name
        body :item_order
        body :init
        body :max_depth
        body :max_iterations
        body :order
        body :sort
        body :start_vertex
        body :strategy
        body :uniqueness
        body :visitor

        code 200, :success
        code 400, "Traversal specification missing or malformed!"
        code 404, "Edge collection or start vertex unknown!"
        code 500, "Error within traversal or more than max_iterations performed!"
      end
    end
  end
end
