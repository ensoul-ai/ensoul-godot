class_name EnsoulAuth
extends Node
## Token exchange and the current identity. API keys are made in Studio; the SDK
## only sends them.

var _http: EnsoulHttp


func token(username: String, password: String) -> Dictionary:
	return await _http.post_form("/auth/token",
		{"username": username, "password": password, "grant_type": "password"})


func refresh(refresh_token: String) -> Dictionary:
	return await _http.post_form("/auth/refresh",
		{"refresh_token": refresh_token, "grant_type": "refresh_token"})


func me() -> Dictionary:
	return await _http.get_req("/auth/me")
