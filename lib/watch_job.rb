class WatchJob < Struct.new(:link)
  def perform
    
  end

  def queue_name
    'watch_job'
  end

  def calculate_cron(job)
    '* * * * *'
  end
end
