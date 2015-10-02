#!/usr/bin/env ruby
require File.dirname(__FILE__) + '/../config/environment'
q = { 'lowest' => 0, 'low' => 0, 'average' => 0, 'high' => 0, 'default' => 0 }
Sidekiq::Cron::Job.all.collect do |j|
  q[j.instance_variable_get(:@queue)] += 1
end
puts q.inspect
