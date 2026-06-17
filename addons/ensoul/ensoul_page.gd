## Paginated response container.
##
## WARNING: EnsoulPage extends RefCounted and contains async methods (next_page,
## all_items). Callers MUST hold a local variable reference to the page during
## await calls to prevent GC from collecting it mid-coroutine.
## Correct:   var page := await client.personas.list(); var all := await page.all_items()
## Dangerous: var all := await (await client.personas.list()).all_items()
class_name EnsoulPage
extends RefCounted

var items:    Array = []
var total:    int   = 0
var page:     int   = 1
var per_page: int   = 20
var pages:    int   = 1

# Private — for fetching next page
var _http:  EnsoulHttp
var _path:  String
var _query: Dictionary


static func from_result(result: Dictionary, http: EnsoulHttp, path: String, query: Dictionary) -> EnsoulPage:
	var p := EnsoulPage.new()
	p._http  = http
	p._path  = path
	p._query = query.duplicate()
	if result.has("error"):
		return p
	var body: Dictionary = result.get("body", {})
	p.items    = body.get("items", [])
	p.total    = body.get("total", 0)
	p.page     = body.get("page", 1)
	p.per_page = body.get("per_page", p.items.size())
	p.pages    = body.get("pages", 1)
	return p


func has_next_page() -> bool:
	return page < pages


func next_page() -> EnsoulPage:
	var q := _query.duplicate()
	q["page"] = page + 1
	var result := await _http.get_req(_path, q)
	return EnsoulPage.from_result(result, _http, _path, q)


## Collect all items across all pages into a single Array.
## Usage: var all = await page.all_items()
func all_items() -> Array:
	var all := items.duplicate()
	var current: EnsoulPage = self
	while current.has_next_page():
		current = await current.next_page()
		all.append_array(current.items)
	return all
