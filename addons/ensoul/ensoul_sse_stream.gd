class_name EnsoulSseStream
extends Node

signal event_received(event: EnsoulServerSentEvent)
signal stream_finished()
signal stream_error(message: String)

var automatic_reconnect: bool = false

var _client:         HTTPClient
var _config:         EnsoulConfig
var _url:            String
var _method:         int
var _headers:        PackedStringArray
var _payload:        String
var _closed:         bool = true
var _last_event_id:  String = ""
var _buffer:         String = ""
var _path:           String = "/"

# SSE parse state
var _block_event:    String = "message"
var _block_data:     String = ""
var _block_id:       String = ""
var _retry_ms:       int    = 3000


func connect_to_url(
	url: String,
	headers: PackedStringArray = PackedStringArray(),
	payload: String = "",
	method: int = HTTPClient.METHOD_GET
) -> Error:
	if not _closed:
		return ERR_ALREADY_IN_USE
	_url     = url
	_method  = method
	_payload = payload
	_headers = headers.duplicate()
	_headers.append("Accept: text/event-stream")
	_headers.append("Cache-Control: no-cache")
	_closed  = false
	return _start_connection()


func close() -> void:
	_closed = true
	set_process(false)
	if _client:
		_client.close()
		_client = null


func _process(_delta: float) -> void:
	if _closed or _client == null:
		return
	_client.poll()
	match _client.get_status():
		HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING:
			pass
		HTTPClient.STATUS_CONNECTED:
			_start_request()
		HTTPClient.STATUS_REQUESTING:
			pass
		HTTPClient.STATUS_BODY:
			_poll_body()
		HTTPClient.STATUS_DISCONNECTED:
			if automatic_reconnect and not _closed:
				set_process(false)
				await get_tree().create_timer(_retry_ms / 1000.0).timeout
				if not _closed:
					_start_connection()
			else:
				stream_finished.emit()
				close()
		HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR, \
		HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CANT_RESOLVE:
			stream_error.emit("Connection error: status=%d" % _client.get_status())
			close()


func _start_connection() -> Error:
	_client = HTTPClient.new()
	var parsed := _url.split("://", true, 1)
	var use_tls := parsed[0] == "https"
	var rest := parsed[1] if parsed.size() > 1 else _url
	var slash_idx := rest.find("/")
	var host := rest.substr(0, slash_idx) if slash_idx != -1 else rest
	_path    = rest.substr(slash_idx) if slash_idx != -1 else "/"
	var err := _client.connect_to_host(host, -1, TLSOptions.client() if use_tls else null)
	if err != OK:
		return err
	set_process(true)
	return OK


func _start_request() -> void:
	var headers := _headers.duplicate()
	if _last_event_id != "":
		headers.append("Last-Event-ID: " + _last_event_id)
	_client.request(_method, _path, headers, _payload)


func _poll_body() -> void:
	var chunk := _client.read_response_body_chunk()
	if chunk.size() == 0:
		return
	_buffer += chunk.get_string_from_utf8().replace("\r", "")
	_parse_buffer()


func _parse_buffer() -> void:
	while true:
		var end := _buffer.find("\n\n")
		if end == -1:
			break
		var block := _buffer.substr(0, end)
		_buffer = _buffer.substr(end + 2)
		_parse_block(block)


func _parse_block(block: String) -> void:
	for line in block.split("\n"):
		if line.is_empty() or line.begins_with(":"):
			continue
		var colon := line.find(":")
		var field := line.substr(0, colon) if colon != -1 else line
		var value := ""
		if colon != -1:
			value = line.substr(colon + 1)
			if value.begins_with(" "):
				value = value.substr(1)
		match field:
			"event": _block_event = value
			"data":
				if _block_data != "":
					_block_data += "\n"
				_block_data += value
			"id":
				_block_id = value
				_last_event_id = value
			"retry":
				if value.is_valid_int():
					_retry_ms = value.to_int()

	if _block_data != "":
		_dispatch_event()


func _dispatch_event() -> void:
	var evt := EnsoulServerSentEvent.new()
	evt.type          = _block_event
	evt.data          = _block_data
	evt.last_event_id = _block_id
	# Reset block state
	_block_event = "message"
	_block_data  = ""
	_block_id    = ""
	event_received.emit.call_deferred(evt)
	# Auto-close stream when the server signals the final event
	var parsed := JSON.parse_string(evt.data)
	if parsed is Dictionary and parsed.get("is_final", false):
		close()
		stream_finished.emit.call_deferred()
