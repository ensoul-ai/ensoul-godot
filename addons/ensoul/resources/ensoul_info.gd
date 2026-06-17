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
