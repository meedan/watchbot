require 'watch_job'
require 'link_checkers'

class Link
  include Mongoid::Document
  include Mongoid::Timestamps
  include LinkCheckers
  
  field :url, type: String
  field :status, type: Integer

  validates_presence_of :url
  validates_uniqueness_of :url
  validates_url :url, url: { no_local: true }
  validates :status, numericality: { only_integer: true }, allow_nil: true

  after_create :start_watching

  belongs_to :delayed_job, autosave: true, validate: true, dependent: :destroy, class_name: 'Delayed::Job'

  def calculate_cron
    cron = nil
    diff = (Time.now - self.created_at).to_i
    WATCHBOT_CONFIG['schedule'].each do |schedule|
      cron = schedule['interval'] if cron.nil? && (schedule['to'].blank? || diff < schedule['to'])
    end
    cron
  end

  def check
    WATCHBOT_CONFIG['conditions'].each do |condition|
      if !self.deleted? && self.url =~ Regexp.new(condition['linkRegex'])
        if send(condition['condition'])
          notify(condition['condition'])
          self.destroy! if condition['removeIfApplies']
        end
      end
    end
  end

  def notification_signature(payload)
    'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), WATCHBOT_CONFIG['webhook']['secret_token'], payload)
  end

  def notify(condition)
    payload = { link: self.url, condition: condition, timestamp: Time.now.to_i }.to_json
    uri = URI(WATCHBOT_CONFIG['webhook']['callback_url'])
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    request = Net::HTTP::Post.new(uri.path)
    request.body = payload
    request['X-Watchbot-Signature'] = notification_signature(payload)
    http.request(request)
  end

  private

  def start_watching
    self.delayed_job = Delayed::Job.enqueue(WatchJob.new(self), cron: :calculate_cron)
    self.save!
  end
end
