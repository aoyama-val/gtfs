require "csv"
require "ostruct"

class GTFS
  def initialize
    @stops = {}   # id (String) => Hash
    @trips = {}  # id (String) => Hash
    @stop_times = {}  # id (String) => Hash

  end

  def load(dir)
    @stops = {}   # id (String) => Hash
    csv = CSV.read("#{dir}/stops.txt", headers: true)
    csv.each do |row|
      stop = OpenStruct.new({
        id:   row["stop_id"],
        name: row["stop_name"],
      })
      @stops[row["stop_id"]] = stop
    end

    @trips = {}  # id (String) => Hash
    csv = CSV.read("#{dir}/trips.txt", headers: true)
    csv.each do |row|
      trip = OpenStruct.new({
        id:       row["trip_id"],
        route_id: row["route_id"],
        trip_headsign: row["trip_headsign"],
      })
      @trips[row["trip_id"]] = trip
    end

    @routes = {}  # id (String) => Hash
    csv = CSV.read("#{dir}/routes.txt", headers: true)
    csv.each do |row|
      route = OpenStruct.new({
        id:               row["route_id"],
        route_short_name: row["route_short_name"],
        route_long_name:  row["route_long_name"],
      })
      @routes[row["route_id"]] = route
    end

    #p @trips

    @stop_times = {}  # id (String) => Hash
    id = 0
    csv = CSV.read("#{dir}/stop_times.txt", headers: true)
    csv.each do |row|
      id += 1
      stop_time = OpenStruct.new({
        id: id,
        trip_id: row["trip_id"],
        stop_id: row["stop_id"],
        arrival_time: row["arrival_time"],
      })
      @stop_times[id] = stop_time
    end

  end

  def select_stop_times(target_route_id, target_stop_id)
    # @tripsのうち、route_idが指定のものを抽出
    if target_route_id.nil?
      trip_ids = @trips.map {|k, v| k}
    else
      trip_ids = @trips.select {|k, v| v[:route_id] == target_route_id}.map {|k, v| k}
    end

    p trip_ids

    result = []
    @stop_times.each do |stop_time_id, stop_time|
      if !trip_ids.include?(stop_time[:trip_id])
        next
      end
      if stop_time[:stop_id] != target_stop_id
        next
      end

      stop = @stops[target_stop_id]
      trip = @trips[stop_time[:trip_id]]
      route = @routes[trip[:route_id]]
      result << OpenStruct.new({
        arrival_time: stop_time[:arrival_time],
        stop_id: stop[:id],
        stop_name: stop[:name],
        route_short_name: route[:route_short_name],
        trip_headsign: trip[:trip_headsign],
      })
    end
    return result.sort_by {|x| x.arrival_time}
  end

  def stops
    return @stops
  end

  def self.main
    # 指定路線、指定バス停を通る全時刻を出力するスクリプト

    # J22209L08   = 夢づくり会館線
    # J22209009_0 = 横岡新田
    # J22209867_0 = 金谷本町
    target_route_id = "J22209L08"
    target_route_id = nil
    target_stop_id = "J22209954"
    target_stop_id = "J22209009_0"
    target_stop_id = "J222092081_3"
    #@target_stop_id  = "J22209867_0"
    #@target_stop_id  = nil

    gtfs = GTFS.new
    gtfs.load

    rows = gtfs.select_stop_times(target_route_id, target_stop_id)
    rows.each do |row|
      puts "arrival_time=#{row[:arrival_time]} stop_id=#{row[:stop_id]} stop_name=#{row[:stop_name]} route_name=#{row[:route_short_name]}"
    end
  end
end

#GTFS.main
