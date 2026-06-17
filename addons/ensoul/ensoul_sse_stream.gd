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

# HTTP response state. SSE runs over a raw HTTPClient poll loop (not HTTPRequest),
# so a 4xx/5xx is delivered as an ordinary response body rather than raising — we
# must inspect the status code ourselves or an error stream would silently finish
# (or stall to timeout) instead of surfacing. `_response_code` is read once the
# response arrives; `_is_error` flips the body handler from SSE-parse to
# error-capture so the failure is emitted on `stream_error`.
var _response_code:  int  = 0
var _is_error:       bool = false


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
			if _is_error:
				_emit_error_and_close()
			elif automatic_reconnect and not _closed:
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
	# Latch the HTTP status the first time the response is available. A >=400
	# code means the body is an error payload, not an SSE stream — switch to
	# error-capture mode so we surface it instead of trying to parse events.
	if _response_code == 0:
		_response_code = _client.get_response_code()
		if _response_code >= 400:
			_is_error = true
	var chunk := _client.read_response_body_chunk()
	if chunk.size() > 0:
		_buffer += chunk.get_string_from_utf8().replace("\r", "")
		if not _is_error:
			_parse_buffer()
		return
	# Empty read. For an error response this means the (small) error body has
	# been drained — emit it now rather than waiting for the socket to drop,
	# which also covers keep-alive responses that never reach DISCONNECTED.
	if _is_error:
		_emit_error_and_close()


func _emit_error_and_close() -> void:
	if _closed:
		return
	var msg := "HTTP %d" % _response_code
	var body_text := _buffer.strip_edges()
	if body_text != "":
		msg += ": " + body_text
	stream_error.emit(msg)
	close()


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
