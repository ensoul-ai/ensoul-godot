class_name EnsoulEndUsers
extends Node
## The end users you name as user_id on chat.

var _http: EnsoulHttp


func forget(user_id: String) -> Dictionary:
	## POST /v1/end-users/forget. Erases the end user's conversations, their messages and
	## the memories from them. Full keys only: a key bound to one persona gets 403 with
	## error_code key_scope. Turns under the same user_id are refused for a short while
	## after (409 error_code end_user_forgotten). result.body is
	## {"user_id", "conversations_erased", "memories_erased"}.
	return await _http.post("/end-users/forget", {"user_id": user_id})
