q = { 'lowest' => 0, 'low' => 0, 'average' => 0, 'high' => 0, 'default' => 0 }
Sidekiq::Cron::Job.all.collect do |j|
  q[j.instance_variable_get(:@queue)]
end
puts q.inspect
