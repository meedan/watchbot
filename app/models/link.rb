class Link
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :url, type: String

  validates_presence_of :url
end
