class WatchJob < Struct.new(:link)
  def perform
    link.check unless link.nil?
  end

  def queue_name
    'watch_job'
  end

  def calculate_cron(job)
    link.calculate_cron unless link.nil?
  end

  def after
    GC.start
  end
end
