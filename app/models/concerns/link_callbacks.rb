module LinkCallbacks
  extend ActiveSupport::Concern

  included do
    after_initialize do
      (self.created_at = self.updated_at = Time.now) if self.created_at.blank?
    end

    before_validation(on: :create) do
      self.url = self.url.to_s.gsub(/\s/, '')
    end

    after_create :start_watching
    after_destroy :stop_watching
  end
end
