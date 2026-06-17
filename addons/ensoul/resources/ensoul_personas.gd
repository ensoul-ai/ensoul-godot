class_name EnsoulPersonas
extends Node

var _http: EnsoulHttp


func create(
	p_name: String,
	domain: String,
	personality_data: Dictionary = {}
) -> Dictionary:
	var body := {"name": p_name, "domain": domain}
	if not personality_data.is_empty():
		body["personality_data"] = personality_data
	return await _http.post("/personas", body)


func get_persona(persona_id: String) -> Dictionary:
	return await _http.get_req("/personas/%s" % persona_id)


func update(persona_id: String, fields: Dictionary) -> Dictionary:
	return await _http.put("/personas/%s" % persona_id, fields)


func delete(persona_id: String) -> Dictionary:
	return await _http.delete("/personas/%s" % persona_id)


func list(
	page: int = 1, per_page: int = 20,
	region: String = "", archetype: String = "",
	country: String = "", city: String = ""
) -> EnsoulPage:
	var q := {"page": page, "per_page": per_page}
	if region    != "": q["region"]    = region
	if archetype != "": q["archetype"] = archetype
	if country   != "": q["country"]   = country
	if city      != "": q["city"]      = city
	var result := await _http.get_req("/personas", q)
	return EnsoulPage.from_result(result, _http, "/personas", q)


func batch_create(personas: Array, batch_id: String = "", domain: String = "") -> Dictionary:
	var body: Dictionary = {"personas": personas}
	if batch_id != "": body["batch_id"] = batch_id
	if domain   != "": body["domain"]   = domain
	return await _http.post("/personas/batch", body)


func get_personality(persona_id: String) -> Dictionary:
	return await _http.get_req("/personas/%s/personality" % persona_id)


func get_filters() -> Dictionary:
	return await _http.get_req("/personas/filters")


func get_connections(persona_id: String) -> Dictionary:
	return await _http.get_req("/personas/%s/connections" % persona_id)
