class Link
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :url, type: String

  validates_presence_of :url
  validates_url :url, url: { no_local: true }
end
