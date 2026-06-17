class_name EnsoulClient
extends Node

const VERSION := "0.1.0"

var personas:    EnsoulPersonas
var chat:        EnsoulChat
var memory:      EnsoulMemory
var domains:     EnsoulDomains
var simulations: EnsoulSimulations
var aggregate:   EnsoulAggregate
var audit:       EnsoulAudit
var sessions:    EnsoulSessions
var frameworks:  EnsoulFrameworks
var auth:        EnsoulAuth
var health:      EnsoulHealth
var info:        EnsoulInfo

var _http: EnsoulHttp


func configure(
	api_key:      String = "",
	base_url:     String = "",
	bearer_token: String = "",
	timeout:      float  = EnsoulConfig.DEFAULT_TIMEOUT_SEC,
	max_retries:  int    = EnsoulConfig.DEFAULT_MAX_RETRIES
) -> void:
	var config := EnsoulConfig.new(api_key, base_url, bearer_token, timeout, max_retries)
	_setup(config)


func configure_with_resource(config: EnsoulConfig) -> void:
	_setup(config)


func _setup(config: EnsoulConfig) -> void:
	# Clear any existing setup
	for child in get_children():
		child.queue_free()

	_http = EnsoulHttp.new()
	_http.setup(config)
	add_child(_http)

	personas    = EnsoulPersonas.new();    personas._http = _http; add_child(personas)
	chat        = EnsoulChat.new();        chat._http = _http;     add_child(chat)
	memory      = EnsoulMemory.new();      memory._http = _http;   add_child(memory)
	domains     = EnsoulDomains.new();     domains._http = _http;  add_child(domains)
	simulations = EnsoulSimulations.new(); simulations._http = _http; add_child(simulations)
	aggregate   = EnsoulAggregate.new();   aggregate._http = _http; add_child(aggregate)
	audit       = EnsoulAudit.new();       audit._http = _http;    add_child(audit)
	sessions    = EnsoulSessions.new();    sessions._http = _http; add_child(sessions)
	frameworks  = EnsoulFrameworks.new();  frameworks._http = _http; add_child(frameworks)
	auth        = EnsoulAuth.new();        auth._http = _http;     add_child(auth)
	health      = EnsoulHealth.new();      health._http = _http;   add_child(health)
	info        = EnsoulInfo.new();        info._http = _http;     add_child(info)
