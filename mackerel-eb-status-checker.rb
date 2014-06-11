#!/usr/bin/env ruby

require 'dotenv'
Dotenv.load

require 'mackerel'
require 'aws-sdk'
require 'optparse'

REQUIRED_OPTS = ['e', 's']
opts = ARGV.getopts('e:r:s:')

REQUIRED_OPTS.each do |key|
  if opts[key].nil? or opts[key].empty?
    puts "Usage:\n mackerel-checker.rb -s [Mackerel Service Name] -e [Elastic Beanstalk Environment Name]"
    exit 1
  end
end

mkr_opts = { service: opts['s'] }
mkr_opts[:roles] = opts['r'] if opts['r']
eb_environment_name = opts['e']

puts "=== Get Mackerel info ==="
puts "find by #{mkr_opts}"

mkr = Mackerel::Client.new(mackerel_api_key: ENV['MACKEREL_APIKEY'])
hosts = mkr.get_hosts(mkr_opts)
hosts.each do |host|
  p host.name
end

puts ""
puts "=== Get AWS info ==="
puts "environment = #{eb_environment_name}"

ec2 = AWS::EC2.new
instances = {}
ec2.instances.with_tag('elasticbeanstalk:environment-name', eb_environment_name).each do |instance|
  next if instance.status != :running
  ip = instance.private_ip_address
  name = "ip-#{ip.gsub(/\./, '-')}"
  instances[name] = instance
  puts name
end

puts ""
puts "Checking ..."

hosts.each do |host|
  if instances[host.name]
    puts "#{host.name} is #{instances[host.name].status}"
  else
    puts "#{host.name} seems terminated. Update status to :poweroff"
    mkr.update_host_status(host.id, :poweroff)
  end
end
