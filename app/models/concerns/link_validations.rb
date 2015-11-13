module LinkValidations
  extend ActiveSupport::Concern

  included do
    validates_presence_of :url
    validates :url, uniqueness: { scope: :application, allow_blank: false }
    validates_url :url, url: { no_local: true }
    validates :status, numericality: { only_integer: true }, allow_nil: true
    validates :application, presence: true, inclusion: { in: WATCHBOT_CONFIG.keys }
  end
end
