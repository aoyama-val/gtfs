require 'rubygems' unless defined? ::Gem
require File.dirname( __FILE__ ) + '/app'

logfp = File.open("log.txt", "w")
logfp.sync = true
$stdout = logfp
$stderr = logfp

run Sinatra::Application
