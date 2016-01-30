module LinkFields
  extend ActiveSupport::Concern

  included do
    field :url, type: String
    field :status, type: Integer
    field :data, type: Hash, default: {}
    field :application, type: String
    field :priority, type: Integer
  end
end
