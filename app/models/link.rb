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
        applies = send(condition['condition'])
        self.destroy! if applies && condition['removeIfApplies']
      end
    end
  end

  private

  def start_watching
    self.delayed_job = Delayed::Job.enqueue(WatchJob.new(self), cron: :calculate_cron)
    self.save!
  end
end