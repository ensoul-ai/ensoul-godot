class_name EnsoulSimulations
extends Node

var _http: EnsoulHttp


func create(
	p_name: String,
	domain_id: String,
	description: String = "",
	config: Dictionary = {},
	participant_persona_ids: Array = []
) -> Dictionary:
	var body := {"name": p_name, "domain_id": domain_id}
	if description != "": body["description"] = description
	if not config.is_empty(): body["config"] = config
	if not participant_persona_ids.is_empty():
		body["participant_persona_ids"] = participant_persona_ids
	return await _http.post("/simulations", body)


func get_simulation(simulation_id: String) -> Dictionary:
	return await _http.get_req("/simulations/%s" % simulation_id)


func list(page: int = 1, per_page: int = 20) -> EnsoulPage:
	var q := {"page": page, "per_page": per_page}
	var result := await _http.get_req("/simulations", q)
	return EnsoulPage.from_result(result, _http, "/simulations", q)


func start(simulation_id: String, ticks: int = -1) -> Dictionary:
	var body := {}
	if ticks >= 0: body["ticks"] = ticks
	return await _http.post("/simulations/%s/start" % simulation_id, body)


func pause(simulation_id: String) -> Dictionary:
	## POST /v1/simulations/{simulation_id}/pause
	## (Note: there is no /stop route — pause is the live counterpart of start.)
	return await _http.post("/simulations/%s/pause" % simulation_id)


func delete(simulation_id: String) -> Dictionary:
	## DELETE /v1/simulations/{simulation_id} — delete a simulation. Returns 204.
	return await _http.delete("/simulations/%s" % simulation_id)


func stream(simulation_id: String) -> EnsoulSseStream:
	var config: EnsoulConfig = _http._config
	var url := config.api_url() + ("/simulations/%s/stream" % simulation_id)
	var headers := PackedStringArray()
	if config.bearer_token != "":
		headers.append("Authorization: Bearer %s" % config.bearer_token)
	elif config.api_key != "":
		headers.append("X-Api-Key: %s" % config.api_key)
	var sse := EnsoulSseStream.new()
	add_child(sse)
	sse.connect_to_url(url, headers)
	return sse


func get_events(simulation_id: String, page: int = 1, per_page: int = 20) -> EnsoulPage:
	var q := {"page": page, "per_page": per_page}
	var path := "/simulations/%s/events" % simulation_id
	var result := await _http.get_req(path, q)
	return EnsoulPage.from_result(result, _http, path, q)


func get_history(simulation_id: String) -> Dictionary:
	return await _http.get_req("/simulations/%s/history" % simulation_id)


func list_participants(simulation_id: String, page: int = 1, per_page: int = 20) -> Dictionary:
	## GET /v1/simulations/{simulation_id}/participants
	var q := {"page": page, "per_page": per_page}
	return await _http.get_req("/simulations/%s/participants" % simulation_id, q)


func add_participants(simulation_id: String, persona_ids: Array) -> Dictionary:
	## POST /v1/simulations/{simulation_id}/participants
	var body := {"persona_ids": persona_ids}
	return await _http.post("/simulations/%s/participants" % simulation_id, body)


func get_event_ticks(simulation_id: String) -> Dictionary:
	## GET /v1/simulations/{simulation_id}/events/ticks
	return await _http.get_req("/simulations/%s/events/ticks" % simulation_id)
