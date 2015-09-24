require 'watchbot_memory'

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
    cmd = 'cd ' + Rails.root.to_s + ' && RAILS_ENV=production bin/delayed_job stop && RAILS_ENV=production bin/delayed_job start'
    memory = Watchbot::Memory.value
    limit = ENV['WATCHBOT_DELAYED_JOB_MEMORY_LIMIT'] || 1000000000
    if Rails.env === 'production' && memory >= limit.to_i
      Delayed::Worker.logger.warn("Reached #{memory} bytes of memory, restarting...")
      Kernel.system(cmd)
    end
  end
end
