module Arango
  module Requests
    module Administration
      class CreateTask < Arango::Request
        request_method :post

        uri_template "/_api/tasks"

        body :command, :required
        body :name, :required
        body :offset, :required
        body :params
        body :period, :required

        code 200, :success
        code 400, "Body incorrect!"
      end
    end
  end
end
