require 'watch_job'

class Link
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :url, type: String

  validates_presence_of :url
  validates_url :url, url: { no_local: true }

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
    true
  end

  private

  def start_watching
    self.delayed_job = Delayed::Job.enqueue(WatchJob.new(self), cron: :calculate_cron)
    self.save!
  end
end
