require 'rubygems' unless defined? ::Gem
require File.dirname( __FILE__ ) + '/app'

if ENV["RACK_ENV"] != "development"
  logfp = File.open("log.txt", "w")
  logfp.sync = true
  $stdout = logfp
  $stderr = logfp
end

run Sinatra::Application
