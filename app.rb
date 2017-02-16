require "sinatra"
require "sinatra/reloader"
require "json"
require "time"
require "byebug"
require "pry"
#require "sqlite3"

require_relative "./gtfs.rb"

set :show_exceptions, false

def gtfs
  if !$gtfs
    $gtfs = GTFS.new
    $gtfs.load("./data")
    puts "GTFS loaded"
  end
  return $gtfs
end

# クエリーパラメータから必須項目を取り出す
def get_required(params, key)
  key = key.to_s
  if not params.key?(key)
    raise "parameter #{key} is missing"
  end
  return params[key]
end

# クエリーパラメータから任意項目を取り出す
def get_optional(params, key, default=nil)
  key = key.to_s
  if params.key?(key)
    return params[key]
  else
    return default
  end
end

# before
before do
  Dir.chdir(File.dirname(__FILE__))
  response.headers["Content-Type"] = "application/json; charset=utf-8"
  response.headers["Access-Control-Allow-Origin"] = "*"
end

# after
after do
end

error do
  'エラーが発生しました。 - ' + env['sinatra.error'].message
end

get "/" do
  response.headers["Content-Type"] = "text/html; charset=utf-8"
  erb :index
end

#get "/map" do
  #response.headers["Content-Type"] = "text/html; charset=utf-8"
  #File.read("./shimada/index.html")
#end

get "/stops" do
  stops = gtfs.stops
  return JSON.generate({
    stops: stops.map {|k, v| v.to_h}.sort_by {|x| x[:id]}
  })
end

get "/select_stop_times" do
  stop_id = get_required(params, "stop_id")
  stop_times = gtfs.select_stop_times(nil, stop_id)
  return JSON.generate({
    stop_times: stop_times.map {|v| v.to_h}
  })
end

get "/bus_coords" do
  route_ids  = get_required(params, "route_ids").split(":")
  time       = get_required(params, "time")

  t = Time.parse(time)
  trips = gtfs.select_trips_by_time(route_ids, t)
  buses = trips.map {|x|
    {
      bus_code:       x[:id],   # GTFSにはバスコードという概念がないので、trip_idにしておく
      trip_id:        x[:id],
      route_id:       x[:route_id],
      trip_headsign:  x[:trip_headsign],
      coords:         gtfs.get_coords_by_time(x[:id], t),
    }
  }
  return JSON.generate({
    buses: buses,
  })
end

# デバッグ用
get "/dir" do
  Dir.pwd
end


get '/hoge' do
  a = get_required(params, "a")
  b = get_optional(params, "b", 100).to_i
  ret = {
    a: a,
    b: b,
  }
  return JSON.pretty_generate(ret)
end
