# Ensoul SDK for Godot (GDScript)

Official Godot 4 GDScript SDK for the [Ensoul](https://ensoul-ai.com) API. Build AI NPCs and characters with memory and personality that evolve through real conversation. Scale from a single companion to thousands of NPCs, and run simulations where they grow and change over time. Full parity with all other Ensoul SDKs, including 11 resource namespaces, auto-pagination, SSE streaming, retry with exponential backoff, and dual auth (API key and Bearer token).

**Requirements:** Godot 4.0+

## Installation

**From the Godot Asset Library (recommended):** search for **Ensoul** in the editor's AssetLib tab, download, and enable the plugin under **Project → Project Settings → Plugins**.

**Manual:**

1. Copy the `addons/ensoul/` folder into your project's `addons/` directory
2. Open **Project → Project Settings → Plugins**
3. Enable the **Ensoul** plugin

The `Ensoul` autoload singleton is registered automatically when the plugin is enabled.

## Quick Start

```gdscript
func _ready() -> void:
    Ensoul.configure("ens_your_api_key")

    var result := await Ensoul.personas.create("Aria", "my_domain")
    if result.has("error"):
        push_warning(result.get("error", ""))
        return
    var persona_id: String = result["body"]["id"]

    var reply := await Ensoul.chat.send(persona_id, "Hello, how are you?")
    print(reply["body"]["response"])

    # Continue conversation
    var conv_id: String = reply["body"]["conversation_id"]
    var reply2 := await Ensoul.chat.send(persona_id, "Tell me more.", conv_id)
```

## Streaming (SSE)

```gdscript
var stream := Ensoul.chat.stream(persona_id, "Tell me a story.")
stream.event_received.connect(func(evt: EnsoulServerSentEvent) -> void:
    var chunk := JSON.parse_string(evt.data)
    if chunk == null: return
    if chunk.get("is_final", false):
        print("Done — conv_id: ", chunk.get("conversation_id", ""))
    else:
        print(chunk.get("chunk", ""))
)
stream.stream_finished.connect(func() -> void: print("\nStream complete"))
stream.stream_error.connect(func(msg: String) -> void: push_warning(msg))
```

## Pagination

```gdscript
var page := await Ensoul.personas.list(1, 20)
print("Total personas: %d across %d pages" % [page.total, page.pages])
for persona in page.items:
    print(persona["name"])

# Fetch next page
if page.has_next_page():
    var page2 := await page.next_page()

# Or collect all across all pages
var all := await page.all_items()
```

## Error Handling

GDScript has no exceptions. All methods return a Dictionary result:

```gdscript
var result := await Ensoul.chat.send(persona_id, "Hello!")
if result.has("error"):
    push_warning("Ensoul error (HTTP %s): %s" % [result.get("status_code", "?"), result.get("error", "")])
    return
var text: String = result["body"]["response"]
```

**Success:** `{ "status_code": 200, "body": { ... } }`
**Error:** `{ "error": "message", "status_code": 404 }`

## Configuration

```gdscript
# API key (recommended)
Ensoul.configure("ens_your_api_key")

# Bearer token
Ensoul.configure("", "", "eyJ...")

# Custom base URL (self-hosted)
Ensoul.configure("ens_your_api_key", "https://your-instance.example.com/api")

# Full options
Ensoul.configure(
    "ens_your_api_key",              # api_key
    "https://api.ensoul-ai.com",      # base_url
    "",                               # bearer_token
    30.0,                             # timeout seconds
    3                                 # max retries
)

# Via Resource (inspector-editable, useful for editor tools)
var config := EnsoulConfig.new()
config.api_key = "ens_your_api_key"
Ensoul.configure_with_resource(config)
```

### Environment Variables

If no explicit values are passed, the SDK reads from environment variables:

| Variable | Purpose | Default |
|----------|---------|---------|
| `ENSOUL_API_KEY` | API key | (none) |
| `ENSOUL_BASE_URL` | Base URL | `https://api.ensoul-ai.com` |

## Resource Namespaces

| Namespace | Description |
|-----------|-------------|
| `Ensoul.personas` | Persona CRUD, batch create, personality, filters, connections |
| `Ensoul.chat` | Send messages, SSE streaming, conversation history |
| `Ensoul.memory` | Memory CRUD, batch create, consolidation, knowledge queries |
| `Ensoul.domains` | Domain configuration management |
| `Ensoul.simulations` | Simulation lifecycle, streaming, events, history |
| `Ensoul.aggregate` | Aggregate queries, streaming, grouped streams, simulation, influence |
| `Ensoul.sessions` | Session management, hierarchy, aggregation |
| `Ensoul.frameworks` | Framework CRUD, validation, instruments |
| `Ensoul.auth` | OAuth2 token exchange, API key management |
| `Ensoul.health` | Health checks (no `/v1` prefix) |
| `Ensoul.info` | Server config, rate limits, tiers, features |

## License

Apache-2.0. See [LICENSE](LICENSE).
