class_name EnsoulAuth
extends Node

var _http: EnsoulHttp


func token(username: String, password: String) -> Dictionary:
	return await _http.post_form("/auth/token",
		{"username": username, "password": password, "grant_type": "password"})


func refresh(refresh_token: String) -> Dictionary:
	return await _http.post_form("/auth/refresh",
		{"refresh_token": refresh_token, "grant_type": "refresh_token"})


func me() -> Dictionary:
	return await _http.get_req("/auth/me")


func create_api_key(p_name: String, expires_days: int = 365, scopes: Array = []) -> Dictionary:
	var body := {"name": p_name, "expires_days": expires_days}
	if not scopes.is_empty(): body["scopes"] = scopes
	return await _http.post("/api-keys", body)


func list_api_keys() -> Dictionary:
	return await _http.get_req("/api-keys")


func revoke_api_key(key_id: String) -> Dictionary:
	return await _http.delete("/api-keys/%s" % key_id)
