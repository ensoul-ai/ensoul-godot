class_name EnsoulConfig
extends Resource

const DEFAULT_BASE_URL     := "https://api.ensoul-ai.com"
const DEFAULT_TIMEOUT_SEC  := 300.0  # inference (domain gen, chat) routinely takes 30-120s+
const DEFAULT_MAX_RETRIES  := 3
const DEFAULT_RETRY_BASE   := 1.0
const API_VERSION          := "v1"

@export var base_url:       String = DEFAULT_BASE_URL
@export var api_key:        String = ""
@export var bearer_token:   String = ""
@export var timeout:        float  = DEFAULT_TIMEOUT_SEC
@export var max_retries:    int    = DEFAULT_MAX_RETRIES
@export var retry_base_sec: float  = DEFAULT_RETRY_BASE


func _init(
	p_api_key:      String = "",
	p_base_url:     String = "",
	p_bearer_token: String = "",
	p_timeout:      float  = DEFAULT_TIMEOUT_SEC,
	p_max_retries:  int    = DEFAULT_MAX_RETRIES
) -> void:
	# Resolve from environment variables if not provided
	if p_api_key == "":
		p_api_key = OS.get_environment("ENSOUL_API_KEY")
	if p_base_url == "":
		p_base_url = OS.get_environment("ENSOUL_BASE_URL")
		if p_base_url == "":
			p_base_url = DEFAULT_BASE_URL

	api_key      = p_api_key
	base_url     = p_base_url.trim_suffix("/")
	bearer_token = p_bearer_token
	timeout      = p_timeout
	max_retries  = p_max_retries


func api_url() -> String:
	return "%s/%s" % [base_url.trim_suffix("/"), API_VERSION]
