module Arango
  module Requests
    module Backup
      class Delete < Arango::Request
        request_method :post

        uri_template "/_admin/backup/delete"

        body :id, :required

        code 200, :success
        code 400, "Bad paramaters or another error, see result!"
        code 404, "Backup with given identifier could not be found!"
      end
    end
  end
end
