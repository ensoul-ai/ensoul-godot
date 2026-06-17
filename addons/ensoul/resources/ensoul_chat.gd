class_name EnsoulChat
extends Node

var _http: EnsoulHttp


func send(
	persona_id: String,
	message: String,
	conversation_id: String = "",
	user_id: String = "",
	max_tokens: int = 1024,
	temperature: float = 1.0,
	include_memories: bool = true,
	include_knowledge: bool = true
) -> Dictionary:
	var body := {
		"message": message,
		"max_tokens": max_tokens,
		"temperature": temperature,
		"include_memories": include_memories,
		"include_knowledge": include_knowledge,
	}
	if conversation_id != "": body["conversation_id"] = conversation_id
	if user_id         != "": body["user_id"]         = user_id
	return await _http.post("/personas/%s/chat" % persona_id, body)


func stream(persona_id: String, message: String, extras: Dictionary = {}) -> EnsoulSseStream:
	var config: EnsoulConfig = _http._config
	var url := config.api_url() + ("/personas/%s/chat/stream" % persona_id)
	var headers := PackedStringArray()
	headers.append("Content-Type: application/json")
	if config.bearer_token != "":
		headers.append("Authorization: Bearer %s" % config.bearer_token)
	elif config.api_key != "":
		headers.append("X-Api-Key: %s" % config.api_key)
	var body := {"message": message}
	body.merge(extras)
	var sse := EnsoulSseStream.new()
	add_child(sse)
	sse.connect_to_url(url, headers, JSON.stringify(body), HTTPClient.METHOD_POST)
	return sse


func get_conversations(persona_id: String, page: int = 1, per_page: int = 20) -> EnsoulPage:
	var q := {"page": page, "per_page": per_page}
	var path := "/personas/%s/conversations" % persona_id
	var result := await _http.get_req(path, q)
	return EnsoulPage.from_result(result, _http, path, q)


func get_conversation(persona_id: String, conversation_id: String) -> Dictionary:
	return await _http.get_req("/personas/%s/conversations/%s" % [persona_id, conversation_id])


# -- Chat sessions (persisted conversation history) -----------------------

func create_session(
	team_id: String,
	user_id: String,
	domain_id: String,
	persona_id: String = "",
	mode: String = "",
	participant_persona_ids: Array = [],
	title: String = ""
) -> Dictionary:
	## POST /v1/chat/sessions
	var body := {
		"team_id": team_id,
		"user_id": user_id,
		"domain_id": domain_id,
	}
	if persona_id != "": body["persona_id"] = persona_id
	if mode != "": body["mode"] = mode
	if not participant_persona_ids.is_empty():
		body["participant_persona_ids"] = participant_persona_ids
	if title != "": body["title"] = title
	return await _http.post("/chat/sessions", body)


func list_sessions(
	user_id: String,
	mode: String = "",
	domain_id: String = "",
	include_archived = null,
	page: int = 1,
	per_page: int = 20
) -> Dictionary:
	## GET /v1/chat/sessions
	var q := {"user_id": user_id, "page": page, "per_page": per_page}
	if mode != "": q["mode"] = mode
	if domain_id != "": q["domain_id"] = domain_id
	if include_archived != null: q["include_archived"] = include_archived
	return await _http.get_req("/chat/sessions", q)


func session_stats(team_id: String, start_date: String, end_date: String) -> Dictionary:
	## GET /v1/chat/sessions/stats
	var q := {"team_id": team_id, "start_date": start_date, "end_date": end_date}
	return await _http.get_req("/chat/sessions/stats", q)


func get_session(session_id: String, user_id: String = "") -> Dictionary:
	## GET /v1/chat/sessions/{session_id}
	var q := {}
	if user_id != "": q["user_id"] = user_id
	return await _http.get_req("/chat/sessions/%s" % session_id, q)


func update_session(session_id: String, title: String = "", is_archived = null) -> Dictionary:
	## PATCH /v1/chat/sessions/{session_id}
	var body := {}
	if title != "": body["title"] = title
	if is_archived != null: body["is_archived"] = is_archived
	return await _http.patch("/chat/sessions/%s" % session_id, body)


func delete_session(session_id: String) -> Dictionary:
	## DELETE /v1/chat/sessions/{session_id} — 204 No Content.
	return await _http.delete("/chat/sessions/%s" % session_id)


func archive_session(session_id: String) -> Dictionary:
	## POST /v1/chat/sessions/{session_id}/archive
	return await _http.post("/chat/sessions/%s/archive" % session_id)


func add_message(
	session_id: String,
	role: String,
	content: String,
	input_tokens: int = -1,
	output_tokens: int = -1,
	model_used: String = "",
	metadata: Dictionary = {}
) -> Dictionary:
	## POST /v1/chat/sessions/{session_id}/messages
	var body := {"role": role, "content": content}
	if input_tokens >= 0: body["input_tokens"] = input_tokens
	if output_tokens >= 0: body["output_tokens"] = output_tokens
	if model_used != "": body["model_used"] = model_used
	if not metadata.is_empty(): body["metadata"] = metadata
	return await _http.post("/chat/sessions/%s/messages" % session_id, body)


func get_messages(session_id: String, limit: int = -1, offset: int = -1) -> Dictionary:
	## GET /v1/chat/sessions/{session_id}/messages — returns a bare JSON array
	## under result.body.
	var q := {}
	if limit >= 0: q["limit"] = limit
	if offset >= 0: q["offset"] = offset
	return await _http.get_req("/chat/sessions/%s/messages" % session_id, q)
