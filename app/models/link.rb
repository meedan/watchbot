require 'watch_job'

class Link
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :url, type: String

  validates_presence_of :url, :delayed_job_id
  validates_url :url, url: { no_local: true }

  before_validation :start_watching, on: :create

  belongs_to :delayed_job, autosave: true, validate: true, dependent: :destroy, class_name: 'Delayed::Job'

  private

  def start_watching
    self.delayed_job = Delayed::Job.enqueue(WatchJob.new, cron: :calculate_cron)
  end
end
