require 'watch_job'
require 'link_checkers'

class Link
  include Mongoid::Document
  include Mongoid::Timestamps
  include LinkCheckers
  
  field :url, type: String
  field :status, type: Integer
  field :data, type: Hash, default: {}
  field :application, type: String
  field :priority, type: Integer

  before_validation(on: :create) do
    self.url = self.url.to_s.gsub(/\s/, '')
  end

  validates_presence_of :url
  validates :url, uniqueness: { scope: :application, allow_blank: false }
  validates_url :url, url: { no_local: true }
  validates :status, numericality: { only_integer: true }, allow_nil: true
  validates :application, presence: true, inclusion: { in: WATCHBOT_CONFIG.keys }

  after_create :start_watching
  after_destroy :stop_watching

  attr_accessor :prioritized

  def calculate_cron
    cron = nil
    diff = (Time.now - self.created_at).to_i
    get_config('schedule').each do |schedule|
      cron = schedule['interval'] if cron.nil? && (schedule['to'].blank? || diff < schedule['to'])
    end
    cron
  end

  def check
    get_config('conditions').each do |condition|
      if !self.destroyed? && self.match_condition(condition)
        name = condition['condition']
        output = send(name)
        if output 
          notify(name, output)
          self.destroy if condition['removeIfApplies']
        end
      end
    end
    self.save unless self.destroyed?
  end

  def match_condition(condition)
    self.url =~ Regexp.new(condition['linkRegex'])
  end

  def notification_signature(payload)
    'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), get_config('webhook')['secret_token'], payload)
  end

  def notify(condition, data = {})
    payload = { link: Rack::Utils.escape(self.url), condition: condition, timestamp: Time.now.to_i, data: data }.to_json
    uri = URI(get_config('webhook')['callback_url'])
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    request = Net::HTTP::Post.new(uri.path)
    request.body = payload
    request['X-Signature'] = notification_signature(payload)
    request['Content-Type'] = 'application/json'
    http.request(request)
  end
    
  def job_name
    "link-#{self.id.to_s}-job"
  end

  def job
    Sidekiq::Cron::Job.find name: self.job_name
  end

  def start_watching
    Sidekiq::Cron::Job.create(name: self.job_name, cron: self.calculate_cron, klass: 'WatchJob', args: [self.id.to_s], queue: self.get_queue)
  end

  def restart_watching
    self.stop_watching
    self.start_watching
  end

  def stop_watching
    Sidekiq::Cron::Job.destroy self.job_name
  end

  def prioritized?
    current_priority, previous_priority = self.priority.to_i, self.priority_was.to_i
    (current_priority.to_s.size > previous_priority.to_s.size && previous_priority < 100) ||
    (current_priority > 0 && previous_priority == 0)
  end

  def get_queue
    # FIXME: Improve this
    priority = self.priority.to_i
    if priority < 1
      'lowest'
    elsif priority < 10
      'low'
    elsif priority < 100
      'average'
    else
      'high'
    end
  end

  def self.jobs_per_queue
    Rails.cache.fetch(Time.now.strftime("%Y%d%m%H")) do
      counts = {}
      Sidekiq::Cron::Job.all.collect do |j|
        queue = j.instance_variable_get(:@queue).to_s
        counts[queue] ||= 0
        counts[queue] += 1
      end
      counts.delete('default')
      counts
    end
  end
  
  private

  def get_config(key)
    raise "Application '#{self.application}' not found" unless WATCHBOT_CONFIG.has_key?(self.application)
    raise "Configuration key '#{key}' not found" unless WATCHBOT_CONFIG[self.application].has_key?(key)
    WATCHBOT_CONFIG[self.application][key]
  end
end
