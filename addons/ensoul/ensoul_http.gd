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

# HTTP methods that are safe to replay: re-sending them cannot create duplicate side
# effects. POST/PATCH are NOT here — replaying a POST that already reached the server
# (e.g. a 120s domain generation that timed out the client) re-runs the inference and
# double-bills the caller. Mirrors the Python/TS SDK policy.
const _IDEMPOTENT_METHODS: Array[int] = [
	HTTPClient.METHOD_GET,
	HTTPClient.METHOD_HEAD,
	HTTPClient.METHOD_OPTIONS,
	HTTPClient.METHOD_PUT,
	HTTPClient.METHOD_DELETE,
]

var _config: EnsoulConfig
var _extra_headers: Array[String] = []

## A failed result is {"error": String, "status_code": int}. When the API names the
## failure, a 4xx result also carries "error_code" (the wire code, one of the
## ERROR_CODE_* constants below or another code the API sends) and "error_detail" (the
## error body's fields: conversation_id on conversation_ended; persona_id,
## current_count, limit and upgrade_url on persona_calls). A 402 names its quota in
## "error_code" (persona_calls, credits, persona or domain).
const ERROR_CODE_USER_ID_REQUIRED := "user_id_required"
const ERROR_CODE_PERSONA_CALLS := "persona_calls"
const ERROR_CODE_TURN_IN_FLIGHT := "turn_in_flight"
const ERROR_CODE_CONVERSATION_ENDED := "conversation_ended"
const ERROR_CODE_END_USER_FORGOTTEN := "end_user_forgotten"


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


func delete(path: String, query: Dictionary = {}) -> Dictionary:
	return await _request(_build_url(path, query), HTTPClient.METHOD_DELETE, _build_headers())


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


func _is_idempotent(method: int) -> bool:
	return method in _IDEMPOTENT_METHODS


# Parse the Retry-After header (delay-seconds form) from a response header array.
# Returns the delay in seconds, or -1.0 when the header is absent or unparseable.
func _parse_retry_after(resp_headers: PackedStringArray) -> float:
	for h in resp_headers:
		var idx := h.find(":")
		if idx == -1:
			continue
		if h.substr(0, idx).strip_edges().to_lower() == "retry-after":
			var value := h.substr(idx + 1).strip_edges()
			return value.to_float() if value.is_valid_float() else -1.0
	return -1.0


## The "error_code" and "error_detail" keys for a 4xx body, or {} when the body names no
## code. The API sends a flat body: {"error": code, "request_id": ..., ...} on a typed
## refusal, and {"error": "Not Found", "message": ...} on a plain HTTP error, whose
## human-readable error names no code. A body wrapped as {"detail": {...}} is read the
## same way; a string detail names none.
static func error_fields(http_code: int, text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var parsed: Dictionary = json.data
	var detail = parsed.get("detail")
	var fields: Dictionary = detail if typeof(detail) == TYPE_DICTIONARY else parsed
	var out := {}
	if http_code == 402:
		if typeof(fields.get("resource")) == TYPE_STRING:
			out["error_code"] = fields["resource"]
	elif _is_wire_code(fields.get("error")):
		out["error_code"] = fields["error"]
	if out.has("error_code"):
		out["error_detail"] = fields
	return out


## True for a machine-readable code such as "turn_in_flight": lowercase letters, digits
## and underscores. A human-readable error such as "Not Found" is not a code.
static func _is_wire_code(value) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var code: String = value
	if code.is_empty():
		return false
	for i in code.length():
		var c := code.unicode_at(i)
		var ok := (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95
		if not ok:
			return false
	return true


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
		var resp_headers: PackedStringArray = response[2]
		var body_bytes: PackedByteArray = response[3]
		var text: String = body_bytes.get_string_from_utf8()

		if result != HTTPRequest.RESULT_SUCCESS:
			# Only replay idempotent methods on a transport error; a POST/PATCH may
			# already have executed server-side, so retrying would double-bill.
			if result in _RETRY_RESULTS and _is_idempotent(method) and attempt < _config.max_retries:
				last_error = "Request error (result=%d), retrying..." % result
				await get_tree().create_timer(_config.retry_base_sec * pow(2.0, attempt)).timeout
				continue
			return {"error": "Request failed (result=%d)" % result}

		# 429 means the server did not process the request (rate limited), so it is safe
		# to retry for any method — honoring Retry-After when the server provides it.
		if http_code == 429:
			if attempt < _config.max_retries:
				last_error = "HTTP 429: %s" % text
				var retry_after := _parse_retry_after(resp_headers)
				var wait_429 := retry_after if retry_after > 0.0 else _config.retry_base_sec * pow(2.0, attempt)
				await get_tree().create_timer(wait_429).timeout
				continue
			return {"error": "HTTP 429: %s" % text, "status_code": 429}

		if http_code >= 400 and http_code < 500:
			var failure := {"error": "HTTP %d: %s" % [http_code, text], "status_code": http_code}
			failure.merge(error_fields(http_code, text))
			return failure

		if http_code >= 500:
			last_error = "HTTP %d: %s" % [http_code, text]
			# Idempotent methods retry any 5xx; POST/PATCH only retry 503 (explicit
			# backpressure) — a 500/502 may mean the request already ran server-side.
			if (_is_idempotent(method) or http_code == 503) and attempt < _config.max_retries:
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
