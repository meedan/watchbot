class ApiKey
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :access_token, type: String
  field :expire_at, type: DateTime
  field :application, type: String

  validates_presence_of :access_token, :expire_at
  validates_uniqueness_of :access_token
  validates :application, presence: true, inclusion: { in: WATCHBOT_CONFIG.keys }

  before_validation :generate_access_token, on: :create
  before_validation :calculate_expiration_date, on: :create

  private

  def generate_access_token
    begin
      self.access_token = SecureRandom.hex
    end while ApiKey.where(access_token: access_token).exists?
  end

  def calculate_expiration_date
    self.expire_at = Time.now.since(30.days)
  end
end
