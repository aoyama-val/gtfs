require "byebug"
require "csv"
require "ostruct"
require "pp"
require "time"

class GTFS
  def initialize
    @stops = {}   # id (String) => Hash
    @trips = {}  # id (String) => Hash
    @stop_times = {}  # id (String) => Hash

  end

  def load(dir)
    # load stops
    @stops = {}   # id (String) => Hash
    csv = CSV.read("#{dir}/stops.txt", headers: true)
    csv.each do |row|
      stop = OpenStruct.new({
        id:   row["stop_id"],
        name: row["stop_name"],
      })
      @stops[row["stop_id"]] = stop
    end

    # load trips
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

    # load routes
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

    # load stop_times
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

    # construct trip_times
    # trip_id (String) => [start_time, end_time]
    @trip_times = @stop_times.group_by {|id, stop_times| stop_times[:trip_id]}
                .map {|trip_id, v| arrival_times = v.map {|x| x[1].arrival_time}; [trip_id, [arrival_times.min, arrival_times.max]]}
                .to_h
  end

  def load_stop_coords(csv_path)
    @stop_coords = {}
    csv = CSV.read(csv_path, headers: true)
    csv.each do |row|
      coord = OpenStruct.new({
        stop_id: row["stop_id"],
        x: row["x"].to_f,
        y: row["y"].to_f,
      })
      @stop_coords[row["stop_id"]] = coord
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

  def select_trips_by_route_id(route_id)
    return trips = @trips.select {|k, v| v.route_id == route_id}
  end

  def select_stops_by_trip_id(trip_id)
    return @stop_times.select {|k, v| v.trip_id == trip_id}.map {|k, v| {arrival_time: v.arrival_time, stop: @stops[v.stop_id]}}
  end

  # 指定された時間に走っているtrip（便）を返す
  # @param  [Array<String>]   route_ids
  # @param  [Time]            time
  def select_trips_by_time(route_ids, time)
    str_time = time.strftime("%H:%M:%S")
    trip_times = @trip_times.select {|k, v| v[0] <= str_time && str_time <= v[1]}
    trip_ids = trip_times.keys
    return trips = trip_ids.map {|id| @trips[id]}.select {|trip| route_ids.include?(trip[:route_id])}
  end

  # 指定した時刻における両側のバス停（最後に通過したバス停、次に通過するバス停）を返す
  # @param  [String]  trip_id
  # @param  [Time]    time
  def select_bus_stops_by_time(trip_id, time)
    str_time = time.strftime("%H:%M:%S")
    #trip = @trips[trip_id]
    stop_times = @stop_times.select {|k, v| v[:trip_id] == trip_id}.values
    #puts "stop_times = "
    #pp stop_times
    stop_times.each_with_index do |stop_time, i|
      if stop_time[:arrival_time] <= str_time && stop_times[i + 1] && str_time <= stop_times[i + 1][:arrival_time]
        #pp stop_time[:arrival_time]
        #pp str_time
        #pp stop_times[i + 1][:arrival_time]
        return [stop_time, stop_times[i + 1]]
      end
    end
    return nil
  end

  # 指定した時刻におけるバスの座標 (x, y) を計算する
  # @param  [String]  trip_id
  # @param  [Time]    time
  def get_coords_by_time(trip_id, time)
    bs1, bs2 = select_bus_stops_by_time(trip_id, time)
    if bs1 && bs2
      str_today = time.strftime("%Y-%m-%d")
      t1 = Time.parse("#{str_today} #{bs1[:arrival_time]}")
      t2 = Time.parse("#{str_today} #{bs2[:arrival_time]}")
      #p t1
      #p t2
      if t1 == t2
        t = 0
      else
        t = (time - t1) / (t2 - t1).to_f
      end
      pp coords1 = @stop_coords[bs1[:stop_id].gsub(/_.*/, "")]
      pp coords2 = @stop_coords[bs2[:stop_id].gsub(/_.*/, "")]
      return GTFS.lerp(coords1, coords2, t)
    else
      puts "bs1 or bs2 not found"
      return nil
    end
  end

  def self.lerp(coords1, coords2, t)
    return [
      coords1[:x] + (coords2[:x] - coords1[:x]) * t,
      coords1[:y] + (coords2[:y] - coords1[:y]) * t,
    ]
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
    gtfs.load("./gtfs_20170131")

    rows = gtfs.select_stop_times(target_route_id, target_stop_id)
    rows.each do |row|
      puts "arrival_time=#{row[:arrival_time]} stop_id=#{row[:stop_id]} stop_name=#{row[:stop_name]} route_name=#{row[:route_short_name]}"
    end
  end

  def self.test2
    gtfs = GTFS.new
    gtfs.load("./gtfs_20170131")
    gtfs.load_stop_coords("./shimada/stop_coords.csv")
    #pp gtfs.select_stops_by_trip_id("J22209L011TD05")
    now = Time.new(2017, 2, 14, 16, 52)
    pp gtfs.select_trips_by_time(["J22209L011"], now)
    #pp gtfs.select_bus_stops_by_time("J22209L011TU06", now)
    #pp gtfs.get_coords_by_time("J22209L011TU06", now)
  end

end


if __FILE__ == $0
  #GTFS.main
  GTFS.test2
end
