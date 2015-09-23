module Watchbot
  class Memory
    def self.value
      output = `ps -eo rss,pid | grep #{Process.pid} | grep -v grep | awk '{ print $1; }'`
      output.chomp.to_i
    end
  end
end
