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
    cmd = 'cd ' + Rails.root + ' && RAILS_ENV=production bin/delayed_job -n5 stop && RAILS_ENV=production bin/delayed_job -n5 start'
    system(cmd) if Rails.env.production? && Watchbot::Memory.value.size >= 10
  end
end
