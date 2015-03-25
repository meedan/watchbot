class WatchJob < Struct.new(:link)
  def perform
    link.check
  end

  def queue_name
    'watch_job'
  end

  def calculate_cron(job)
    link.calculate_cron
  end
end
