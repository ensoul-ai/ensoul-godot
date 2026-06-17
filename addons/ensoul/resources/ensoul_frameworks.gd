class_name EnsoulFrameworks
extends Node

var _http: EnsoulHttp


func list(page: int = 1, per_page: int = 20) -> EnsoulPage:
	var q := {"page": page, "per_page": per_page}
	var result := await _http.get_req("/frameworks", q)
	return EnsoulPage.from_result(result, _http, "/frameworks", q)


func get_framework(framework_id: String) -> Dictionary:
	return await _http.get_req("/frameworks/%s" % framework_id)


func create(body: Dictionary) -> Dictionary:
	return await _http.post("/frameworks", body)


func update(framework_id: String, body: Dictionary) -> Dictionary:
	return await _http.put("/frameworks/%s" % framework_id, body)


func delete(framework_id: String) -> Dictionary:
	return await _http.delete("/frameworks/%s" % framework_id)


func validations(framework_id: String) -> Dictionary:
	## GET /v1/frameworks/{framework_id}/validations
	return await _http.get_req("/frameworks/%s/validations" % framework_id)


func get_instruments(framework_id: String) -> Dictionary:
	return await _http.get_req("/frameworks/%s/instruments" % framework_id)
