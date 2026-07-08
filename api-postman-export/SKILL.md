---
name: api-postman-export
description: Discover all HTTP APIs in a codebase, document them with request/response examples and tests, and generate a Postman Collection v2.1 JSON file ready to import. Use whenever the user mentions Postman, API collection export, API documentation from code, endpoint inventory, REST API testing, curl examples for routes, or wants to catalog/document/test the project's APIs — even if they only say "what APIs do we have" or "export our endpoints."
---

# API Discovery & Postman Export

Turn a codebase into a documented, testable Postman collection. The deliverable is always two files:

1. **`docs/api-reference.md`** — human-readable API catalog with curl examples
2. **`postman/<project-name>.postman_collection.json`** — importable Postman Collection v2.1

## Workflow

### Phase 1: Understand the project

Before searching for routes, establish context:

1. Read `README`, `package.json`, `pyproject.toml`, `go.mod`, or equivalent to identify the stack.
2. Find the server entry point (e.g. `main.ts`, `app.py`, `server.js`, `cmd/main.go`).
3. Note base URL, port, and auth mechanism from env files (`.env.example`), config, or middleware — never copy real secrets into output files.
4. Check for existing OpenAPI/Swagger specs (`openapi.yaml`, `swagger.json`). If one exists and is current, use it as the primary source and cross-check against code.

Read `references/discovery-patterns.md` for framework-specific search patterns once you know the stack.

### Phase 2: Discover every endpoint

Search systematically — do not stop at the first router file.

**Universal signals to grep:**

```
@app.route|@router\.|Router\(|\.get\(|\.post\(|\.put\(|\.patch\(|\.delete\(
app\.(get|post|put|patch|delete)
http\.HandleFunc|mux\.|chi\.|gin\.
@GetMapping|@PostMapping|@RequestMapping
fastify\.(get|post)|server\.(get|post)
```

**For each endpoint, capture:**

| Field | Source |
|-------|--------|
| HTTP method | Route decorator / handler registration |
| Path | Route string (include path params like `:id`) |
| Handler file | File + function name |
| Auth required | Middleware, guards, `@UseGuards`, `authenticate` |
| Request body | DTO, schema, validation (Zod, Joi, Pydantic, class-validator) |
| Query params | Handler args, `@Query`, `req.query` |
| Path params | Route segments, `@Param`, `req.params` |
| Response shape | Return type, serializer, response DTO |
| Status codes | Explicit `status()` calls, exception handlers |

Group endpoints by resource or router module (e.g. `Users`, `Auth`, `Orders`).

**Coverage check:** Compare your count against any existing route list, OpenAPI spec, or test files. If counts diverge, search again with alternate patterns before proceeding.

### Phase 3: Write realistic test examples

For every endpoint, derive example values from:

1. Existing tests (`*.test.ts`, `*_test.go`, `test_*.py`)
2. Seed/fixture data
3. Schema defaults and enum constraints
4. Sensible placeholders only when nothing else exists — mark these with `(example)` in descriptions

Each example needs:

- **Headers** — `Content-Type`, `Authorization` (use `{{authToken}}` variable, never hardcode secrets)
- **Body** — valid JSON matching the schema
- **Expected response** — status code + sample JSON body
- **Postman test script** — at minimum:

```javascript
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});
pm.test("Response is JSON", function () {
    pm.response.to.be.json;
});
```

Add domain-specific assertions when response shape is known (e.g. check `id` field exists, array length > 0).

### Phase 4: Generate the Postman collection

Read `references/postman-format.md` for the full schema. Use `assets/collection-template.json` as the starting skeleton.

**Collection-level requirements:**

```json
{
  "info": {
    "name": "<Project Name> API",
    "description": "Auto-generated from codebase. Generated: <ISO date>.",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "variable": [
    { "key": "baseUrl", "value": "http://localhost:3000", "type": "string" },
    { "key": "authToken", "value": "", "type": "string" }
  ]
}
```

**Per-request structure:**

- Organize into folders matching your resource groups
- URL uses `{{baseUrl}}` + path; path params become `:paramName` segments
- Query params include `description` field
- Body uses `mode: "raw"`, `raw: "<json>"`, `options: { "raw": { "language": "json" } }`
- Attach `event` with `listen: "test"` containing the test script
- Include at least one saved `response` example per request (from Phase 3)

**Auth patterns:**

| Auth type | Collection setup |
|-----------|-----------------|
| Bearer JWT | Collection variable `authToken`; header `Authorization: Bearer {{authToken}}` |
| API key | Variable `apiKey`; header or query per code |
| Basic | Collection auth type `basic` with placeholder username/password |
| Cookie/session | Document in description; add login request in `Auth` folder that sets variable via test script |
| None | No auth header |

If the project has a login/token endpoint, add it as the first request in an `Auth` folder with a test script that saves the token:

```javascript
const json = pm.response.json();
if (json.token) pm.collectionVariables.set("authToken", json.token);
```

### Phase 5: Write the markdown reference

Create `docs/api-reference.md` with this structure:

```markdown
# <Project> API Reference

> Auto-generated from codebase on <date>. Import `postman/<name>.postman_collection.json` into Postman.

## Setup
- Base URL: `http://localhost:<port>`
- Auth: <description>
- Postman variables: `baseUrl`, `authToken`

## Endpoints

### <Resource Group>

#### `GET /api/users/:id`
Get a user by ID.

**Auth:** Bearer token required

**Path params:**
| Name | Type | Description |
|------|------|-------------|
| id | string | User UUID |

**Response `200`:**
```json
{ "id": "...", "email": "user@example.com" }
```

**curl:**
```bash
curl -X GET "http://localhost:3000/api/users/abc-123" \
  -H "Authorization: Bearer $TOKEN"
```
```

### Phase 6: Validate before delivering

Run the bundled validator:

```bash
python scripts/validate_collection.py postman/<project-name>.postman_collection.json
```

Fix any reported errors. The collection must pass validation before you present it to the user.

### Phase 7: Present to the user

Tell the user:

1. Where both output files are saved
2. How to import: Postman → Import → drag the `.postman_collection.json` file
3. Set `baseUrl` and `authToken` in collection variables (or run the Auth folder first)
4. Endpoint count discovered and any endpoints marked as uncertain

## Output conventions

| Item | Convention |
|------|-----------|
| Collection file | `postman/<kebab-project-name>.postman_collection.json` |
| Docs file | `docs/api-reference.md` |
| Folder names | PascalCase resource names (`Users`, `Orders`) |
| Request names | `<METHOD> <path>` e.g. `GET /api/users/:id` |
| Variables | `baseUrl`, `authToken`, plus any project-specific vars |
| Uncertain endpoints | Prefix request name with `[?]` and note in description |

## When OpenAPI already exists

If the project has a current OpenAPI 3 spec:

1. Parse it for the endpoint list and schemas
2. Cross-check against code — flag spec-only or code-only endpoints
3. Still generate the Postman collection (Postman imports OpenAPI, but our collection includes tests and project-specific variables)
4. Prefer code over spec when they conflict; note discrepancies in `docs/api-reference.md`

## Common pitfalls

- **Missing global prefix** — Express `app.use('/api/v1', router)` means routes are prefixed; include it in paths
- **Duplicate routes** — Same path, different methods are separate requests; same method+path from different mounts are duplicates to resolve
- **GraphQL** — Document as POST to `/graphql` with example query/mutation in body; one request per operation type or a folder of named operations
- **WebSocket** — Note in docs; Postman supports WebSocket requests (method `"WEBSOCKET"`) for v10+
- **File uploads** — Use `mode: "formdata"` with a file field description, not raw JSON

## Bundled resources

| File | When to read |
|------|-------------|
| `references/discovery-patterns.md` | After identifying the framework |
| `references/postman-format.md` | When building the JSON collection |
| `assets/collection-template.json` | Starting point for the collection |
| `scripts/validate_collection.py` | Before delivering output |
