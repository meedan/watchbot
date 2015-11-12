require 'watchbot_memory'

class WatchJob
  include Sidekiq::Worker

  def perform(*args)
    link = self.get_link(args.first)
    unless link.nil?
      link.check
      cron = link.calculate_cron
      if cron.nil?
        link.stop_watching
      elsif !link.job.nil? && (cron != link.job.cron || link.prioritized)
        link.restart_watching
      end
    end
    self.after
  end

  def get_link(id)
    Link.where(id: id).last
  end

  def after
    pid = Process.pid
    cmd = "kill -USR1 #{pid} && kill -TERM #{pid} && kill -9 #{pid} && cd #{Rails.root} && RAILS_ENV=production bundle exec sidekiq -d"
    memory = Watchbot::Memory.value
    limit = ENV['WATCHBOT_BG_JOB_MEMORY_LIMIT'] || 5000000
    if Rails.env === 'production' && memory >= limit.to_i
      puts "Reached #{memory} bytes of memory, restarting..."
      Kernel.system(cmd)
    end
  end
end
