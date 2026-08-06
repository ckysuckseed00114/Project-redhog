extends Node

signal broadcast_received(payload: Dictionary)
signal realtime_channel_joined

const HEARTBEAT_INTERVAL := 30.0
const WS_PROTOCOL_VERSION := "2.0.0"
const BINARY_BROADCAST := 0x04
const WEB_SESSION_PATH := "user://web_session.cfg"

var current_user_id: String = ""
var current_access_token: String = ""

var _ws: WebSocketPeer
var _msg_ref: int = 0
var _ws_was_open: bool = false
var _connecting: bool = false
var _heartbeat_timer: float = 0.0
var _pending_broadcasts: Array[Dictionary] = []
var _joined_channels: Dictionary = {} # channel_name -> join_ref
var _pending_join_channels: Array[String] = []
var _primary_channel: String = RealtimeChannel.GLOBAL
var _web_fetch_seq: int = 0
var _web_fetch_pending: Dictionary = {}


func _ready() -> void:
	SupabaseConfig.ensure_loaded()
	_restore_web_session()
	join_channel(RealtimeChannel.GLOBAL)


func is_authenticated() -> bool:
	return current_user_id != "" and current_access_token != ""


func clear_session() -> void:
	current_user_id = ""
	current_access_token = ""
	if OS.has_feature("web"):
		var cfg := ConfigFile.new()
		cfg.save(WEB_SESSION_PATH)


func _save_web_session() -> void:
	if not OS.has_feature("web"):
		return
	var cfg := ConfigFile.new()
	cfg.set_value("auth", "user_id", current_user_id)
	cfg.set_value("auth", "access_token", current_access_token)
	cfg.save(WEB_SESSION_PATH)


func _restore_web_session() -> void:
	if not OS.has_feature("web"):
		return
	var cfg := ConfigFile.new()
	if cfg.load(WEB_SESSION_PATH) != OK:
		return
	current_user_id = str(cfg.get_value("auth", "user_id", ""))
	current_access_token = str(cfg.get_value("auth", "access_token", ""))
	if is_authenticated():
		connect_realtime()


func _apply_auth_response(response_data: Variant) -> bool:
	if response_data is Dictionary:
		current_access_token = str(response_data.get("access_token", ""))
		var user_info: Variant = response_data.get("user", {})
		if user_info is Dictionary:
			current_user_id = str(user_info.get("id", ""))
		else:
			current_user_id = str(response_data.get("user_id", ""))
		if is_authenticated():
			_save_web_session()
			return true
	return false


func _parse_json_body(body: PackedByteArray) -> Variant:
	if body.is_empty():
		return null
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return null
	return json.get_data()


func normalize_rows(data: Variant) -> Array:
	var rows: Array = []
	if data is Array:
		for item in data:
			if item is Dictionary:
				rows.append(item)
	elif data is Dictionary and data.get("data") is Array:
		for item in data.get("data", []):
			if item is Dictionary:
				rows.append(item)
	return rows


func get_primary_channel() -> String:
	return _primary_channel


func set_primary_channel(channel_name: String) -> void:
	_primary_channel = channel_name if channel_name != "" else RealtimeChannel.GLOBAL


func join_channel(channel_name: String) -> void:
	if channel_name == "":
		return
	if _joined_channels.has(channel_name):
		return
	if channel_name not in _pending_join_channels:
		_pending_join_channels.append(channel_name)
	if not is_realtime_ready():
		connect_realtime()
		return
	_do_join_channel(channel_name)


func leave_channel(channel_name: String) -> void:
	if channel_name == "":
		return
	_pending_join_channels.erase(channel_name)
	if not _joined_channels.has(channel_name):
		return
	var join_ref: String = _joined_channels[channel_name]
	_joined_channels.erase(channel_name)
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_msg_ref += 1
		_send_phx(RealtimeChannel.topic_for(channel_name), "phx_leave", {}, str(_msg_ref), join_ref)
	if _primary_channel == channel_name:
		set_primary_channel(RealtimeChannel.GLOBAL)


# เพิ่มส่วนนี้เข้าไปในคลาส เพื่อคอย poll WebSocket ทุกเฟรม
func _process(delta: float) -> void:
	# --- โค้ด WebSocket เดิมปล่อยไว้ตามเดิม ---
	if _ws != null:
		_ws.poll()
		var state := _ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			if not _ws_was_open:
				_ws_was_open = true
				_flush_pending_channel_joins()
			_heartbeat_timer += delta
			if _heartbeat_timer >= HEARTBEAT_INTERVAL:
				_heartbeat_timer = 0.0
				_send_heartbeat()
			while _ws.get_available_packet_count() > 0:
				var packet := _ws.get_packet()
				if _ws.was_string_packet():
					_handle_ws_text(packet.get_string_from_utf8())
				else:
					_handle_ws_binary(packet)
		elif state == WebSocketPeer.STATE_CLOSED:
			var was_connected := _ws_was_open
			_reset_realtime_state()
			if was_connected and current_user_id != "":
				call_deferred("connect_realtime")


func _reset_realtime_state() -> void:
	_ws_was_open = false
	for channel_name in _joined_channels.keys():
		if channel_name not in _pending_join_channels:
			_pending_join_channels.append(channel_name)
	_joined_channels.clear()
	_connecting = false
	_heartbeat_timer = 0.0
	if RealtimeChannel.GLOBAL not in _pending_join_channels:
		_pending_join_channels.append(RealtimeChannel.GLOBAL)


func _realtime_ws_url() -> String:
	var host := SupabaseConfig.host()
	var url := "wss://%s/realtime/v1/websocket?apikey=%s&vsn=%s" % [
		host, SupabaseConfig.anon_key.uri_encode(), WS_PROTOCOL_VERSION.uri_encode()
	]
	if current_access_token != "":
		url += "&token=" + current_access_token.uri_encode()
	return url


func connect_realtime() -> void:
	if current_access_token == "" and current_user_id == "":
		return
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_flush_pending_channel_joins()
		return
	if _connecting:
		return
	if _ws == null:
		_ws = WebSocketPeer.new()
	elif _ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_ws.close()
		_reset_realtime_state()
	var err := _ws.connect_to_url(_realtime_ws_url())
	if err != OK:
		push_warning("Supabase Realtime connect failed: %s" % error_string(err))
		return
	_connecting = true
	_msg_ref = 0


func is_realtime_ready() -> bool:
	return _ws != null \
		and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN \
		and not _joined_channels.is_empty()


func send_broadcast(event_name: String, data: Dictionary, channel: String = "") -> void:
	var target_channel := channel if channel != "" else _primary_channel
	if target_channel == "":
		target_channel = RealtimeChannel.GLOBAL
	_send_broadcast_http(event_name, data, target_channel)
	if not is_realtime_ready():
		connect_realtime()


func _send_broadcast_now(event_name: String, data: Dictionary, channel: String = "") -> void:
	_send_broadcast_http(event_name, data, channel)


func _send_broadcast_http(event_name: String, data: Dictionary, channel: String) -> void:
	var host := SupabaseConfig.host()
	var url := "https://%s/realtime/v1/api/broadcast/%s/events/%s" % [
		host,
		channel.uri_encode(),
		event_name.uri_encode(),
	]
	var auth_token := current_access_token if current_access_token != "" else SupabaseConfig.anon_key
	var headers := PackedStringArray([
		"apikey: " + SupabaseConfig.anon_key,
		"Authorization: Bearer " + auth_token,
		"Content-Type: application/json",
	])
	var http := HTTPRequest.new()
	add_child(http)
	
	# 🌟 1. เอาฟังก์ชันมาเก็บในตัวแปร callback ก่อน ป้องกัน Parser งง
	var callback = func(_result, response_code, _headers, body, req_node):
		if is_instance_valid(req_node):
			req_node.queue_free()
		if response_code < 200 or response_code >= 300:
			if OS.is_debug_build():
				push_warning(
					"Broadcast HTTP %d: %s" % [response_code, body.get_string_from_utf8()]
				)
				
	# 🌟 2. เอา callback มาต่อกับ .bind(http) ตรงนี้แทน
	http.request_completed.connect(callback.bind(http))
	
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(data))


func _flush_pending_broadcasts() -> void:
	if not is_realtime_ready():
		return
	var queue := _pending_broadcasts.duplicate()
	_pending_broadcasts.clear()
	for item in queue:
		_send_broadcast_now(
			str(item.get("event", "")),
			item.get("data", {}),
			str(item.get("channel", _primary_channel))
		)


func _send_heartbeat() -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_msg_ref += 1
	_send_phx("phoenix", "heartbeat", {}, str(_msg_ref))


func _flush_pending_channel_joins() -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var queue := _pending_join_channels.duplicate()
	for channel_name in queue:
		if not _joined_channels.has(channel_name):
			_do_join_channel(channel_name)


func _do_join_channel(channel_name: String) -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	if _joined_channels.has(channel_name):
		_pending_join_channels.erase(channel_name)
		return
	_msg_ref += 1
	var join_ref := str(_msg_ref)
	var topic := RealtimeChannel.topic_for(channel_name)
	var join_payload := {
		"config": {
			"broadcast": {"ack": false, "self": false},
			"presence": {"key": "", "enabled": false},
			"postgres_changes": [],
			"private": false,
		},
	}
	if current_access_token != "":
		join_payload["access_token"] = current_access_token
	_joined_channels[channel_name] = join_ref
	_pending_join_channels.erase(channel_name)
	_send_phx(topic, "phx_join", join_payload, join_ref, join_ref)


func _send_phx(
	topic: String,
	event: String,
	payload: Dictionary,
	ref: String,
	join_ref: String = ""
) -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	
	var jr: Variant = null
	if join_ref != "":
		jr = join_ref
	
	var msg: Array = [jr, ref, topic, event, payload]
	_ws.send_text(JSON.stringify(msg))

func _handle_ws_text(text: String) -> void:
	if text.is_empty():
		return
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var data: Variant = json.get_data()
	if not data is Array or data.size() < 5:
		return
	var event: String = str(data[3])
	var payload: Variant = data[4]
	if not payload is Dictionary:
		return
	if event == "phx_reply":
		var topic := str(data[2]) if data.size() > 2 else ""
		var ref := str(data[1]) if data.size() > 1 else ""
		if str(payload.get("status", "")) == "ok":
			for channel_name in _joined_channels.keys():
				if _joined_channels[channel_name] == ref and RealtimeChannel.topic_for(channel_name) == topic:
					_connecting = false
					if OS.is_debug_build():
						print("✅ Realtime joined channel: ", channel_name)
					realtime_channel_joined.emit()
					_flush_pending_broadcasts()
					_flush_pending_channel_joins()
					return
		else:
			push_warning("Supabase Realtime join failed (%s): %s" % [topic, str(payload.get("response", payload))])
		return
	if event == "broadcast":
		var inner_event := str(payload.get("event", ""))
		var inner_payload: Variant = payload.get("payload", {})
		if inner_payload is Dictionary:
			_emit_broadcast(inner_event, inner_payload)
		return


func _handle_ws_binary(packet: PackedByteArray) -> void:
	if packet.size() < 5 or packet[0] != BINARY_BROADCAST:
		return
	var topic_size := int(packet[1])
	var event_size := int(packet[2])
	var meta_size := int(packet[3])
	var payload_enc := int(packet[4])
	if payload_enc != 1:
		return
	var event_start := 5 + topic_size
	var meta_start := event_start + event_size
	var payload_start := meta_start + meta_size
	if packet.size() <= payload_start:
		return
	var user_event := packet.slice(event_start, meta_start).get_string_from_utf8()
	var payload_text := packet.slice(payload_start).get_string_from_utf8()
	var json := JSON.new()
	if json.parse(payload_text) != OK:
		return
	var parsed: Variant = json.get_data()
	if parsed is Dictionary:
		_emit_broadcast(user_event, parsed)


func _emit_broadcast(event_name: String, payload: Dictionary) -> void:
	if OS.is_debug_build() and event_name == "pos_update":
		print("[Realtime] recv pos_update from ", payload.get("character_id", "?"))
	var emit_data: Dictionary = payload.duplicate()
	emit_data["event"] = event_name
	broadcast_received.emit(emit_data)


func _connect_http_callback(http: HTTPRequest, on_complete: Callable) -> void:
	# 🌟 1. เอาฟังก์ชันมาเก็บในตัวแปร callback ก่อน
	var callback = func(result, response_code, headers_res, body, req_node):
		if is_instance_valid(req_node):
			req_node.queue_free()
		if not is_instance_valid(self) or not is_inside_tree():
			return
		if on_complete.is_valid():
			on_complete.call(result, response_code, headers_res, body)
			
	http.request_completed.connect(callback.bind(http))


func sign_up(email: String, password: String, callback: Callable = Callable()) -> void:
	SupabaseConfig.ensure_loaded()
	var url = SupabaseConfig.auth_url + "signup"
	var headers = [
		"apikey: " + SupabaseConfig.anon_key,
		"Content-Type: application/json"
	]
	var body_data = {"email": email, "password": password}

	var http = HTTPRequest.new()
	add_child(http)
	_connect_http_callback(http, func(_result, response_code, _headers_res, body):
		var json = JSON.new()
		json.parse(body.get_string_from_utf8())
		var response_data = json.get_data()

		if response_code >= 200 and response_code < 300:
			print("✅ สมัครสมาชิกสำเร็จ: ", response_data)
			if callback.is_valid():
				callback.call(true, response_data)
		else:
			print("❌ สมัครสมาชิกไม่สำเร็จ (Code %d): " % response_code, response_data)
			if callback.is_valid():
				callback.call(false, response_data)
	)
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body_data))


func sign_in(email: String, password: String, callback: Callable = Callable()) -> void:
	SupabaseConfig.ensure_loaded()
	var url = SupabaseConfig.auth_url + "token?grant_type=password"
	var headers = [
		"apikey: " + SupabaseConfig.anon_key,
		"Content-Type: application/json"
	]
	var body_data = {"email": email, "password": password}

	var http = HTTPRequest.new()
	add_child(http)
	_connect_http_callback(http, func(_result, response_code, _headers_res, body):
		var response_data: Variant = _parse_json_body(body)

		if response_code >= 200 and response_code < 300 and _apply_auth_response(response_data):
			print("✅ ล็อกอินสำเร็จ! User ID: ", current_user_id)
			connect_realtime()
			if callback.is_valid():
				callback.call(true, response_data)
		else:
			print("❌ ล็อกอินไม่สำเร็จ (Code %d): " % response_code, response_data)
			if callback.is_valid():
				callback.call(false, response_data)
	)
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body_data))


func insert_data(table_name: String, data: Dictionary, callback: Callable = Callable()) -> void:
	SupabaseConfig.ensure_loaded()
	var url = SupabaseConfig.url + table_name
	var auth_token = current_access_token if current_access_token != "" else SupabaseConfig.anon_key
	var headers = [
		"apikey: " + SupabaseConfig.anon_key,
		"Authorization: Bearer " + auth_token,
		"Content-Type: application/json",
		"Prefer: return=representation"
	]

	var http = HTTPRequest.new()
	add_child(http)
	_connect_http_callback(http, func(_result, response_code, _headers_res, body):
		var json = JSON.new()
		json.parse(body.get_string_from_utf8())
		var response_data = json.get_data()

		if response_code >= 200 and response_code < 300:
			if callback.is_valid():
				callback.call(true, response_data)
		else:
			print("❌ บันทึกข้อมูลล้มเหลว (Code %d): " % response_code, response_data)
			if callback.is_valid():
				callback.call(false, response_data)
	)
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(data))


func fetch_data(table_name: String, query_params: String = "", callback: Callable = Callable()) -> void:
	SupabaseConfig.ensure_loaded()

	var fixed_params := query_params
	if fixed_params != "":
		fixed_params = fixed_params.replace('eq."', 'eq.').replace('"', '')

	var url := SupabaseConfig.url + table_name + ("?" + fixed_params if fixed_params != "" else "")
	var auth_token := current_access_token if current_access_token != "" else SupabaseConfig.anon_key

	if OS.has_feature("web"):
		_fetch_data_browser(url, auth_token, callback)
		return

	_fetch_data_http(url, auth_token, callback)


func _fetch_data_http(url: String, auth_token: String, callback: Callable) -> void:
	var headers := PackedStringArray([
		"apikey: " + SupabaseConfig.anon_key,
		"Authorization: Bearer " + auth_token,
		"Accept: application/json",
		"Accept-Encoding: identity",
	])

	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	_connect_http_callback(http, func(result, response_code, _headers_res, body):
		var body_text: String = body.get_string_from_utf8() if not body.is_empty() else ""
		var response_data: Variant = _parse_json_body(body)
		var rows := normalize_rows(response_data)

		if result != HTTPRequest.RESULT_SUCCESS:
			print("❌ ดึงข้อมูลล้มเหลว (HTTP result %d) url=", url)
			if callback.is_valid():
				callback.call(false, rows)
			return

		if response_code >= 200 and response_code < 300:
			print("✅ fetch OK status=", response_code, " rows=", rows.size())
			if callback.is_valid():
				callback.call(true, rows)
		else:
			print("❌ ดึงข้อมูลล้มเหลว (Code %d): " % response_code, body_text.left(200))
			if callback.is_valid():
				callback.call(false, rows)
	)
	http.request(url, headers, HTTPClient.METHOD_GET)


func _fetch_data_browser(url: String, auth_token: String, callback: Callable) -> void:
	_web_fetch_seq += 1
	var fetch_id := _web_fetch_seq
	_web_fetch_pending[fetch_id] = callback

	var js_cb := JavaScriptBridge.create_callback(func(args: Array) -> void:
		if not _web_fetch_pending.has(fetch_id):
			return
		var pending: Callable = _web_fetch_pending[fetch_id]
		_web_fetch_pending.erase(fetch_id)
		if not pending.is_valid() or args.is_empty():
			pending.call(false, [])
			return
			
		var packet_json := JSON.new()
		if packet_json.parse(str(args[0])) != OK:
			pending.call(false, [])
			return
			
		var raw_packet: Variant = packet_json.get_data()
		if not raw_packet is Dictionary:
			pending.call(false, [])
			return
			
		# 🌟 แปลงชนิดเป็น Dictionary ชัดเจนเพื่อให้คอมไพเลอร์รู้ประเภทข้อมูลภายใน
		var packet: Dictionary = raw_packet
		
		var status: int = int(packet.get("status", 0))
		var body_text: String = str(packet.get("body", ""))
		
		var body_json := JSON.new()
		body_json.parse(body_text)
		var rows: Array = normalize_rows(body_json.get_data())
		var ok: bool = status >= 200 and status < 300
		
		print("[BrowserFetch] status=", status, " rows=", rows.size())
		pending.call(ok, rows)
	)

	var js := """
	(function() {
		fetch(%s, {
			method: 'GET',
			headers: {
				'apikey': %s,
				'Authorization': 'Bearer ' + %s,
				'Accept': 'application/json'
			}
		}).then(function(r) {
			return r.text().then(function(t) {
				var payload = JSON.stringify({ status: r.status, body: t });
				%s([payload]);
			});
		}).catch(function(e) {
			%s([JSON.stringify({ status: 0, body: String(e) })]);
		});
	})();
	""" % [
		JSON.stringify(url),
		JSON.stringify(SupabaseConfig.anon_key),
		JSON.stringify(auth_token),
		js_cb,
		js_cb,
	]
	print("[BrowserFetch] start url=", url)
	JavaScriptBridge.eval(js)

	get_tree().create_timer(8.0).timeout.connect(func() -> void:
		if not _web_fetch_pending.has(fetch_id):
			return
		print("[BrowserFetch] timeout — fallback HTTPRequest")
		var pending: Callable = _web_fetch_pending[fetch_id]
		_web_fetch_pending.erase(fetch_id)
		if pending.is_valid():
			_fetch_data_http(url, auth_token, pending)
	, CONNECT_ONE_SHOT)

func update_data(table: String, query: String, data: Dictionary, callback: Callable = Callable()) -> void:
	SupabaseConfig.ensure_loaded()
	var url = SupabaseConfig.url + table + "?" + query
	var auth_token = current_access_token if current_access_token != "" else SupabaseConfig.anon_key
	var headers = [
		"apikey: " + SupabaseConfig.anon_key,
		"Authorization: Bearer " + auth_token,
		"Content-Type: application/json",
		"Prefer: return=representation"
	]

	var http = HTTPRequest.new()
	add_child(http)
	_connect_http_callback(http, func(_result, response_code, _headers_res, body):
		var json = JSON.new()
		json.parse(body.get_string_from_utf8())
		var response_data = json.get_data()

		if response_code >= 200 and response_code < 300:
			if callback.is_valid():
				callback.call(true, response_data)
		else:
			print("❌ อัปเดตข้อมูลล้มเหลว (Code %d): " % response_code, response_data)
			if callback.is_valid():
				callback.call(false, response_data)
	)
	http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(data))
