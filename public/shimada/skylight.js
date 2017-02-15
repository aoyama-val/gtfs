var g_running;
var g_map;
var g_bus_markers = {}; // bus_code => Marker
var g_colorIndex = 0;
var g_colors = [  // http://www.colordic.org/p/
  "ff1414",
  "ff1489",
  "8914ff",
  "1414ff",
  "1489ff",
  "14ffff",
  "14ff89",
  "14ff14",
  "89ff14",
  "ffff14",
  "ff8914",
];
var g_route_ids;

// 初期化
function skyLightInit(options) {
  g_map = L.map('map', {
    maxZoom: 15,
    minZoom: 10,
    zoom: 13,
    center: options.center,
    crs: L.CRS.Simple,
    continuousWorld: true,
  });

  g_route_ids = options.route_ids;

  var use_tile = false;
  if (use_tile) {
    // タイルを使う場合
    var southWest = [-0.0980224609375, 0.000244140625];
    var northEast = [0, 0.088134765625];
    var main_layer = L.tileLayer('./tile/{z}/{x}_{y}.png?2', {
      noWrap: true,  // trueの場合、左右リピートしない
      maxNativeZoom: 13,
      bounds: [southWest, northEast],
    }).addTo(g_map);
  } else {
    // タイルを使わない場合
    var imageUrl    = options.image_url;
    var imageBounds = options.image_bounds;
    L.imageOverlay(imageUrl, imageBounds).addTo(g_map);
  }

  var hash = new L.Hash(g_map);
  g_map.on('click', function(e) {
    console.log(e.latlng.lat + ", " + e.latlng.lng);
  });

  $('#sidebar').keydown(function(e) {
    if (e.keyCode == 37) {
      incrementTime(-60);
      updateBus();
    } else if (e.keyCode == 39) {
      incrementTime(60);
      updateBus();
    }
  });

  var setRunning = function() {
    g_running = $('#cb1').prop("checked");
  };

  $('#cb1').click(setRunning);

  $('#slider').on("input", function() {
    var $this = $(this);
    var r = $this.val() / $this.attr("max");
    var seconds = Math.floor(86400 * r / 10) * 10;
    console.log("seconds", seconds);
    setTime(seconds);
  });

  setRunning();
  console.log("g_running", g_running);
  // タイマー開始
  setTimeout(update, 0);
}

// 時刻を進める、または戻す
function incrementTime(delta) {
  var time = $('#time').val();
  var a = time.split(":");
  var seconds = parseInt(a[0]) * 60*60 + parseInt(a[1]) * 60 + parseInt(a[2]);
  seconds += delta;
  if (seconds > 86400) {
    seconds = 0;
  }
  setTime(seconds);
}

function setTime(seconds) {
  $('#time').val(Math.floor(seconds / 3600) + ":" + zeroPad(Math.floor((seconds % 3600) / 60), 2)+ ":" + zeroPad(seconds % 60, 2));
}

// バスの表示位置を更新
function updateBus() {
  var time = "2017-02-14 " + $('#time').val();
  $.getJSON("/bus_coords", {route_ids: g_route_ids, time: time}, function(data) {
    moveBusMarkers(data.buses);
  });
}

function moveBusMarkers(buses) {
  // APIから返ってきたデータに含まれていないバスのマーカーを削除する
  var bus_marker_bus_codes = Object.keys(g_bus_markers);
  bus_marker_bus_codes.forEach(function(code) {
    var found = false;
    buses.forEach(function(bus) {
      if (bus.bus_code == code) {
        found = true;
      }
    });
    if (!found) {
      g_map.removeLayer(g_bus_markers[code]);
      delete g_bus_markers[code];
    }
  });

  buses.forEach(moveOneBusMarker);
}

function moveOneBusMarker(bus) {
  if (g_bus_markers[bus.bus_code]) {
    // 既に存在するなら移動だけ
    g_bus_markers[bus.bus_code]._icon.style[L.DomUtil.TRANSITION] = ('all ' + 250 + 'ms linear');
    g_bus_markers[bus.bus_code].setLatLng(bus.coords);
  } else {
    // 存在しないなら新規作成
    g_colorIndex = (g_colorIndex + 1) % g_colors.length;
    var color = g_colors[g_colorIndex];
    var icon = L.divIcon({
      html: '<img src="https://skybrain.ekispert.jp/img/bus_icon?color=' + color + '&w=46&h=46">',
      className: '',
      iconSize: [46, 46],
      iconAnchor: [23, 30],
      popupAnchor: [23, 10],
    });
    //bus.coords[0] += 0.3828125 + 0.05126953125;
    //bus.coords[1] += 0.3701171875 - 0.044921875;
    g_bus_markers[bus.bus_code] = L.marker(bus.coords, {icon: icon}).addTo(g_map);
  }
}

// 一定時間ごとに呼ばれる
function update() {
  if (g_running) {
    var speed = parseInt($('#speed').val());
    incrementTime(speed);
    updateBus();
  }
  setTimeout(update, 250);
}

// ゼロ埋め
function zeroPad(num, len) {
  var str = String(num);
  return ("0000000000" + str).substr(10 + str.length - len);
}
