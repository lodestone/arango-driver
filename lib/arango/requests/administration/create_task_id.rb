module Arango
  module Requests
    module Administration
      class CreateTaskId < Arango::Request
        request_method :put

        uri_template "/_api/tasks/{id}"

        body :command, :required
        body :name, :required
        body :offset, :required
        body :params
        body :period, :required

        code 200, :success
        code 400, "Task already exists or Body incorrect!"
      end
    end
  end
end
