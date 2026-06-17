class_name EnsoulHealth
extends Node

var _http: EnsoulHttp


func check() -> Dictionary:
	return await _http.get_raw("/health")


func ready() -> Dictionary:
	return await _http.get_raw("/health/ready")


func live() -> Dictionary:
	return await _http.get_raw("/health/live")
