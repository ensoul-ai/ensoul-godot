class_name EnsoulAudit
extends Node

## Audit and verification resource.
##
## Exposes the tamper-evident audit trail (Merkle-committed communication
## events) and the public content-verification endpoint. Responses are the
## raw decoded JSON wrapped in the transport result ({status_code, body}),
## except get_signing_key which returns raw PEM text ({status_code, text}).

var _http: EnsoulHttp


func get_event(event_id: String) -> Dictionary:
	## GET /v1/audit/events/{event_id}
	return await _http.get_req("/audit/events/%s" % event_id)


func get_commitment(commitment_id: String) -> Dictionary:
	## GET /v1/audit/commitments/{commitment_id}
	return await _http.get_req("/audit/commitments/%s" % commitment_id)


func get_proof(event_id: String) -> Dictionary:
	## GET /v1/audit/proofs/{event_id} — Merkle inclusion proof.
	return await _http.get_req("/audit/proofs/%s" % event_id)


func verify(audit_event_id: String, content_hash: String = "") -> Dictionary:
	## POST /v1/verify — verify AI-generated content against the audit trail.
	var body := {"audit_event_id": audit_event_id}
	if content_hash != "": body["content_hash"] = content_hash
	return await _http.post("/verify", body)


func get_signing_key() -> Dictionary:
	## GET /.well-known/ensoul-signing-key.pem — ECDSA public key (PEM text).
	## Non-versioned, public endpoint. Returns {status_code, text}.
	return await _http.get_text("/.well-known/ensoul-signing-key.pem")
