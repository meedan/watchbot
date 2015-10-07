# :nocov:
module LinksDoc
  extend ActiveSupport::Concern
 
  included do
    swagger_controller :links, 'Links'

    swagger_api :create do
      summary 'Create a new link to be watched'
      notes 'This method can be called from clients in order to create links in Watchbot database, that will be checked periodically. Links need to be unique inside the same application.'
      param :query, :url, :string, :required, 'URL to be watched'
      response :ok, 'Link created successfully'
      response 400, 'Parameters missing (URL was not provided)'
      response 400, 'Link exists inside the application related to the API key'
      response 401, 'Access denied'
    end

    swagger_api :destroy do
      summary 'Remove a link from Watchbot'
      notes 'Clients can call this method in order to remove links from Watchbot database'
      param :path, :url, :string, :required, 'URL to be removed'
      response :ok, 'Link was removed successfully'
      response 400, 'Parameters missing (URL was not provided)'
      response 404, 'Link does not exist inside the application related to the API key'
      response 400, 'Unknown error happened when trying to remove link'
      response 401, 'Access denied'
    end
  end
end
# :nocov:
