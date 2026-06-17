class_name EnsoulDomains
extends Node

var _http: EnsoulHttp


func list(page: int = 1, per_page: int = 20) -> EnsoulPage:
	var q := {"page": page, "per_page": per_page}
	var result := await _http.get_req("/domains", q)
	return EnsoulPage.from_result(result, _http, "/domains", q)


func get_domain(domain_id: String) -> Dictionary:
	return await _http.get_req("/domains/%s" % domain_id)


func create(config: Dictionary) -> Dictionary:
	## POST /v1/domains — create a domain from a full DomainConfigCreate body.
	##
	## Step 1 of the dev workflow. To build the config with the AI wizard
	## instead of by hand, call generate() first and pass its body["config"] here.
	##
	## GDScript has no struct type for request bodies, so `config` is a Dictionary.
	## It mirrors the DomainConfigCreate Pydantic model (the API source of truth
	## in src/api/models/domains.py). Required keys are mandatory; every optional
	## key falls back to the server default if omitted. Shape:
	##
	##   # --- required ---
	##   "name": String                       # lowercase, alphanumeric, underscores
	##   "display_name": String               # human-readable name
	##   "tiers": Array[Dictionary]           # TierDefinition; must include root at level 0
	##     # each: {"level": int, "name": String, "description"?: String}
	##   "personality_schema": Dictionary     # PersonalitySchema
	##     # {"fields": Array[Dictionary],     # FieldDefinition (see below)
	##     #  "version"?: String,
	##     #  "trait_correlations"?: Array[Dictionary]}  # {"trait_a","trait_b","correlation"(float),"description"?}
	##     # FieldDefinition: {"path": String,
	##     #                   "field_type": "float"|"int"|"str"|"enum"|"bool",
	##     #                   "range_min"?: float, "range_max"?: float,
	##     #                   "default"?: Dictionary, "required"?: bool,
	##     #                   "heritability"?: float, "description"?: String,
	##     #                   "enum_values"?: Array[String]}
	##   # --- optional ---
	##   "version"?: String                   # semver, defaults to "1.0.0"
	##   "description"?: String
	##   "archetypes"?: Array[Dictionary]     # {"id","name","tier"(int),"parent_id"?,
	##                                        #  "personality_modifiers"?: Dictionary (deltas, -50..50),
	##                                        #  "description"?,"metadata"?: Dictionary,"probability"?: float}
	##   "name_patterns"?: Array[Dictionary]  # {"tier_id","tier_value","first_names"?,"last_names"?,
	##                                        #  "patterns"?,"gender_handling"?: "neutral"|"separate"|"none",
	##                                        #  "prefixes"?,"suffixes"?}
	##   "memory_templates"?: Array[Dictionary]  # {"template_id","template_type": "universal"|"contextual",
	##                                        #  "template_string","context_type"?,"context_id"?,
	##                                        #  "probability"?: float,"importance"?: float,"tags"?: Array[String]}
	##   "filterable_fields"?: Array[Dictionary]  # {"path","type": "range"|"select"|"multiselect","label",
	##                                        #  "description"?,"min"?,"max"?,"step"?,"options_from"?,
	##                                        #  "options"?: Array[{"value","label"}]}
	##   "tier_values"?: Array[Dictionary]    # {"tier_id","options": Array[{"value","label","probability"?}],
	##                                        #  "parent_tier_id"?,"parent_value_mapping"?: Dictionary}
	##   "image_generation"?: Dictionary      # {"default_style"?,"styles"?: Array[{"name","style_prompt",
	##                                        #  "description"?,"negative_prompt"?}],"prompt_prefix"?,"prompt_suffix"?}
	##   "behavioral_guidelines"?: Array[String]  # rules added to every persona's system prompt
	##   "chat_guardrails"?: Array[String]    # short directives re-injected each chat turn
	##   "chat_temperature"?: float           # per-domain sampling temperature (0.0-2.0)
	##   "entity_noun"?: String               # identity framing, e.g. "person", "pet", "character"
	##   "is_draft"?: bool
	##   "tags"?: Array[String]
	##   "frameworks"?: Array[String]
	return await _http.post("/domains", config)


func generate(
	description: String,
	context: Dictionary = {},
	target_sections: Array = ["all"]
) -> Dictionary:
	## POST /v1/domains/generate — AI wizard (requires PRO tier).
	##
	## Generate a domain configuration from a natural-language `description`
	## using Claude. The returned body["config"] is a ready-to-use
	## DomainConfigCreate Dictionary that can be passed straight to create().
	##
	## Returns a GeneratedConfigResponse body:
	##   {"config": Dictionary,        # DomainConfigCreate (see create() shape)
	##    "explanation": String,
	##    "suggestions": Array[String],
	##    "confidence": float}         # 0.0-1.0
	var body := {"description": description}
	if not context.is_empty():
		body["context"] = context
	if not target_sections.is_empty():
		body["target_sections"] = target_sections
	return await _http.post("/domains/generate", body)


func update(domain_id: String, body: Dictionary) -> Dictionary:
	return await _http.put("/domains/%s" % domain_id, body)


func delete(domain_id: String) -> Dictionary:
	return await _http.delete("/domains/%s" % domain_id)


func validate(config: Dictionary) -> Dictionary:
	## POST /v1/domains/validate — validate a domain config (DomainConfigCreate).
	## Top-level route (no domain id in the path).
	return await _http.post("/domains/validate", config)
