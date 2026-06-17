class_name EnsoulMemory
extends Node

## Memory resource — maps to the /v1/memory/* API namespace.
##
## As of API 0.2.0 the memory routes were rebased off
## /v1/personas/{id}/memories onto /v1/memory/{persona_id}. MemoryCreate no
## longer carries memory_type / importance fields; an optional source ("user")
## and references map are the only extra inputs.

var _http: EnsoulHttp


func stats() -> Dictionary:
	## GET /v1/memory/stats — global memory statistics.
	return await _http.get_req("/memory/stats")


func create(
	persona_id: String,
	content: String,
	source: String = "user",
	references: Dictionary = {}
) -> Dictionary:
	## POST /v1/memory/{persona_id} — add a memory (MemoryCreate).
	var body := {"content": content, "source": source}
	if not references.is_empty():
		body["references"] = references
	return await _http.post("/memory/%s" % persona_id, body)


func list(persona_id: String, limit: int = 50, offset: int = 0) -> Dictionary:
	## GET /v1/memory/{persona_id} — list memories.
	##
	## Returns the MemoriesResponse shape
	## {persona_id, memories, working_memory, total} — NOT a paginated envelope.
	var q := {"limit": limit, "offset": offset}
	return await _http.get_req("/memory/%s" % persona_id, q)


func clear(persona_id: String) -> Dictionary:
	## DELETE /v1/memory/{persona_id} — delete all memories for a persona.
	return await _http.delete("/memory/%s" % persona_id)


func delete(persona_id: String, memory_id: String) -> Dictionary:
	## DELETE /v1/memory/{persona_id}/{memory_id} — delete one memory.
	return await _http.delete("/memory/%s/%s" % [persona_id, memory_id])


func update_access(persona_id: String, memory_id: String) -> Dictionary:
	## PATCH /v1/memory/{persona_id}/{memory_id}/access — record an access.
	return await _http.patch("/memory/%s/%s/access" % [persona_id, memory_id])


func batch_create(persona_id: String, memories: Array) -> Dictionary:
	## POST /v1/memory/{persona_id}/batch — add many memories at once.
	return await _http.post("/memory/%s/batch" % persona_id, {"memories": memories})


func consolidate(persona_id: String) -> Dictionary:
	## POST /v1/memory/{persona_id}/consolidate — consolidate memories.
	return await _http.post("/memory/%s/consolidate" % persona_id)


func generate(persona_id: String, options: Dictionary = {}) -> Dictionary:
	## POST /v1/memory/{persona_id}/generate — generate memories.
	return await _http.post("/memory/%s/generate" % persona_id, options)


func working(persona_id: String) -> Dictionary:
	## GET /v1/memory/{persona_id}/working — working-memory snapshot.
	return await _http.get_req("/memory/%s/working" % persona_id)


func get_knowledge(persona_id: String) -> Dictionary:
	## GET /v1/memory/{persona_id}/knowledge — retrieve RAG knowledge.
	return await _http.get_req("/memory/%s/knowledge" % persona_id)


func add_knowledge(persona_id: String, content: String, source: String) -> Dictionary:
	## POST /v1/memory/{persona_id}/knowledge — add RAG knowledge (KnowledgeCreate).
	return await _http.post(
		"/memory/%s/knowledge" % persona_id,
		{"content": content, "source": source}
	)
