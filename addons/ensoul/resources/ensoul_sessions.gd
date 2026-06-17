class_name EnsoulSessions
extends Node

## Hierarchical session orchestration — maps to /v1/sessions/*.
##
## As of API 0.2.0 these routes are no longer nested under a persona: a session
## is created against the authenticated team/user context, so create() no longer
## takes a persona_id (SessionCreate has no persona field). This is a distinct
## family from /v1/chat/sessions (chat-message threads) — never rebase chat
## session methods onto these routes.

var _http: EnsoulHttp


func create(
	tier: int = 0,
	parent_session_id: String = "",
	system_instructions: String = "",
	extras: Dictionary = {}
) -> Dictionary:
	## POST /v1/sessions — create a session (SessionCreate).
	##
	## extras merges arbitrary additional SessionCreate fields into the body
	## (mirrors the Python SOT's **kwargs / the cpp+unity `extras` param).
	var body := {"tier": tier}
	if parent_session_id != "": body["parent_session_id"] = parent_session_id
	if system_instructions != "": body["system_instructions"] = system_instructions
	for k in extras: body[k] = extras[k]
	return await _http.post("/sessions", body)


func get_session(session_id: String) -> Dictionary:
	## GET /v1/sessions/{session_id}
	return await _http.get_req("/sessions/%s" % session_id)


func delete(session_id: String, cancel_children: bool = false) -> Dictionary:
	## DELETE /v1/sessions/{session_id}
	var suffix := "?cancel_children=%s" % ("true" if cancel_children else "false")
	return await _http.delete("/sessions/%s%s" % [session_id, suffix])


func list(
	tier: int = -1,
	status: String = "",
	parent_session_id: String = "",
	page: int = 1,
	per_page: int = 20
) -> EnsoulPage:
	## GET /v1/sessions — list sessions (paginated).
	var q := {"page": page, "per_page": per_page}
	if tier >= 0: q["tier"] = tier
	if status != "": q["status"] = status
	if parent_session_id != "": q["parent_session_id"] = parent_session_id
	var result := await _http.get_req("/sessions", q)
	return EnsoulPage.from_result(result, _http, "/sessions", q)


func hierarchy() -> Dictionary:
	## GET /v1/sessions/hierarchy — full session tree.
	return await _http.get_req("/sessions/hierarchy")


func info() -> Dictionary:
	## GET /v1/sessions/info — session-system info.
	return await _http.get_req("/sessions/info")


func stats() -> Dictionary:
	## GET /v1/sessions/stats/summary — session statistics.
	return await _http.get_req("/sessions/stats/summary")


func get_child_sessions(session_id: String, page: int = 1, per_page: int = 20) -> Dictionary:
	## GET /v1/sessions/{session_id}/children
	## (Named get_child_sessions, not get_children, to avoid shadowing the
	## built-in Node.get_children().)
	var q := {"page": page, "per_page": per_page}
	return await _http.get_req("/sessions/%s/children" % session_id, q)


func aggregate_children(session_id: String, aggregation_mode: String = "summary") -> Dictionary:
	## POST /v1/sessions/{session_id}/aggregate (AggregateChildrenRequest).
	return await _http.post(
		"/sessions/%s/aggregate" % session_id,
		{"aggregation_mode": aggregation_mode}
	)
