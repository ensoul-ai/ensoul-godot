class_name EnsoulHttp
extends Node

const _RETRY_RESULTS: Array[int] = [
	HTTPRequest.RESULT_CANT_CONNECT,
	HTTPRequest.RESULT_CONNECTION_ERROR,
	HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR,
	HTTPRequest.RESULT_NO_RESPONSE,
	HTTPRequest.RESULT_TIMEOUT,
	HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH,
]

var _config: EnsoulConfig
var _extra_headers: Array[String] = []


func setup(config: EnsoulConfig) -> void:
	_config = config


func set_extra_headers(headers: Array[String]) -> void:
	_extra_headers = headers


func get_req(path: String, query: Dictionary = {}) -> Dictionary:
	return await _request(_build_url(path, query), HTTPClient.METHOD_GET, _build_headers())


func post(path: String, body: Dictionary = {}) -> Dictionary:
	var headers := _build_headers()
	headers.append("Content-Type: application/json")
	return await _request(_build_url(path), HTTPClient.METHOD_POST, headers, JSON.stringify(body))


func put(path: String, body: Dictionary = {}) -> Dictionary:
	var headers := _build_headers()
	headers.append("Content-Type: application/json")
	return await _request(_build_url(path), HTTPClient.METHOD_PUT, headers, JSON.stringify(body))


func patch(path: String, body: Dictionary = {}) -> Dictionary:
	var headers := _build_headers()
	headers.append("Content-Type: application/json")
	return await _request(_build_url(path), HTTPClient.METHOD_PATCH, headers, JSON.stringify(body))


func delete(path: String) -> Dictionary:
	return await _request(_build_url(path), HTTPClient.METHOD_DELETE, _build_headers())


func post_form(path: String, form_data: Dictionary) -> Dictionary:
	var headers := _build_headers()
	headers.append("Content-Type: application/x-www-form-urlencoded")
	var parts: Array[String] = []
	for key in form_data:
		parts.append("%s=%s" % [key, str(form_data[key]).uri_encode()])
	return await _request(_build_url(path), HTTPClient.METHOD_POST, headers, "&".join(parts))


# Health endpoints use base_url without /v1
func get_raw(path: String) -> Dictionary:
	var url := _config.base_url.trim_suffix("/") + path
	return await _request(url, HTTPClient.METHOD_GET, _build_headers())


# Fetch a non-versioned path returning the raw response body as text
# (e.g. the PEM signing key at /.well-known/...). Returns {status_code, text}.
func get_text(path: String) -> Dictionary:
	var url := _config.base_url.trim_suffix("/") + path
	return await _request(url, HTTPClient.METHOD_GET, _build_headers(), "", true)


func _build_headers() -> Array[String]:
	var headers: Array[String] = ["Accept: application/json"]
	if _config.bearer_token != "":
		headers.append("Authorization: Bearer %s" % _config.bearer_token)
	elif _config.api_key != "":
		headers.append("X-Api-Key: %s" % _config.api_key)
	for h in _extra_headers:
		headers.append(h)
	return headers


func _build_url(path: String, query: Dictionary = {}) -> String:
	var url := _config.api_url() + path
	if query.is_empty():
		return url
	var parts: Array[String] = []
	for key in query:
		if query[key] != null:
			parts.append("%s=%s" % [key, str(query[key])])
	if parts.is_empty():
		return url
	return url + "?" + "&".join(parts)


func _request(url: String, method: int, headers: Array[String], body: String = "", raw_text: bool = false) -> Dictionary:
	var last_error := ""
	# max_retries=0 means 1 attempt (no retries), matching Python/TS/Unity SDKs
	for attempt in _config.max_retries + 1:
		var http := HTTPRequest.new()
		http.timeout = _config.timeout
		add_child(http)

		var err: Error = http.request(url, PackedStringArray(headers), method, body)
		if err != OK:
			http.queue_free()
			return {"error": "HTTPRequest failed to start: %s" % error_string(err)}

		var response: Array = await http.request_completed
		http.queue_free()

		var result: int       = response[0]
		var http_code: int    = response[1]
		var body_bytes: PackedByteArray = response[3]
		var text: String = body_bytes.get_string_from_utf8()

		if result != HTTPRequest.RESULT_SUCCESS:
			if result in _RETRY_RESULTS and attempt < _config.max_retries:
				last_error = "Request error (result=%d), retrying..." % result
				await get_tree().create_timer(_config.retry_base_sec * pow(2.0, attempt)).timeout
				continue
			return {"error": "Request failed (result=%d)" % result}

		if http_code >= 400 and http_code < 500:
			return {"error": "HTTP %d: %s" % [http_code, text], "status_code": http_code}

		if http_code >= 500:
			last_error = "HTTP %d: %s" % [http_code, text]
			if attempt < _config.max_retries:
				await get_tree().create_timer(_config.retry_base_sec * pow(2.0, attempt)).timeout
				continue
			return {"error": last_error, "status_code": http_code}

		if raw_text:
			return {"status_code": http_code, "text": text}

		if text.is_empty():
			return {"status_code": http_code, "body": {}}

		var json := JSON.new()
		if json.parse(text) != OK:
			return {"error": "JSON parse error: %s" % json.get_error_message()}

		return {"status_code": http_code, "body": json.data}

	return {"error": last_error if last_error != "" else "Max retries exceeded"}
