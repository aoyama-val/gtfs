require "sinatra"
require "sinatra/reloader"
require "json"
#require "sqlite3"

require_relative "./gtfs.rb"

set :show_exceptions, false

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

GTFS_DIR = "./gtfs_20170131"

# before
before do
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

get "/stops" do
  gtfs = GTFS.new
  gtfs.load(GTFS_DIR)
  stops = gtfs.stops
  return JSON.generate({
    stops: stops.map {|k, v| v.to_h}.sort_by {|x| x[:id]}
  })
end

get "/select_stop_times" do
  stop_id = get_required(params, "stop_id")
  gtfs = GTFS.new
  gtfs.load(GTFS_DIR)
  stop_times = gtfs.select_stop_times(nil, stop_id)
  return JSON.generate({
    stop_times: stop_times.map {|v| v.to_h}
  })
end

get "/dir" do
  Dir.pwd
end


#get '/' do
#  response.headers["Cache-Control"] = "max-age=10, public, must-revalidate"
#  headers = request.env.select {|key, val| key.start_with?("HTTP_") }
#  ret = {
#    hello: "sinatra",
#    headers: headers,
#  }
#  return JSON.generate(ret)
#end

get '/hoge' do
  a = get_required(params, "a")
  b = get_optional(params, "b", 100).to_i
  ret = {
    a: a,
    b: b,
  }
  return JSON.pretty_generate(ret)
end
