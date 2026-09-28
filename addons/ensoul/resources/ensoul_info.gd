class_name EnsoulInfo
extends Node

## Info resource — maps to GET /v1/api/info.
##
## BREAKING (API 0.2.0): the four /v1/info/{config,rate_limits,tiers,features}
## routes were collapsed into a single GET /v1/api/info returning an
## APIInfoResponse blob. The standalone server-side endpoints are gone; the
## convenience accessors below each fetch that one blob and slice out their
## relevant sub-section client-side (rate_limiting, access_tiers, features).

var _http: EnsoulHttp


func get_info() -> Dictionary:
	## GET /v1/api/info — full server info (APIInfoResponse).
	return await _http.get_req("/api/info")


func me() -> Dictionary:
	## GET /v1/api/me: the caller's tier, remaining quota and key binding. result.body.key
	## is {"kind": "persona", "persona_id": id} for a key bound to one persona, else
	## {"kind": "full", "persona_id": null}. Read it with key_binding(result).
	return await _http.get_req("/api/me")


static func key_binding(result: Dictionary) -> Dictionary:
	## The key binding of a me() result: {"kind", "persona_id"}, or {} when the result is
	## an error or comes from an API build that predates the key binding.
	var body = result.get("body")
	if typeof(body) != TYPE_DICTIONARY:
		return {}
	var key = body.get("key")
	return key if typeof(key) == TYPE_DICTIONARY else {}


func config() -> Dictionary:
	## Full server-info envelope (alias for get_info()).
	return await get_info()


func rate_limits() -> Dictionary:
	## Rate-limiting sub-section, parsed from the single /v1/api/info response.
	var result := await get_info()
	if result.has("error"):
		return result
	return result.get("body", {}).get("rate_limiting", {})


func tiers() -> Array:
	## Access-tier definitions sub-section, parsed from /v1/api/info.
	var result := await get_info()
	if result.has("error"):
		return []
	return result.get("body", {}).get("access_tiers", [])


func features() -> Dictionary:
	## Feature-flags sub-section, parsed from /v1/api/info.
	var result := await get_info()
	if result.has("error"):
		return result
	return result.get("body", {}).get("features", {})
