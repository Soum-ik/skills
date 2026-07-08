# API Discovery Patterns by Framework

Use these patterns after identifying the project's stack. Always trace from entry point → router registration → handler.

---

## Node.js / TypeScript

### Express
```javascript
// Search patterns
app.get|post|put|patch|delete
router.get|post|put|patch|delete
app.use('/prefix', router)
```
- Check `app.js`, `server.ts`, `routes/` directory
- Middleware order matters for auth — read `app.use(authenticate)` placement
- DTOs often in `validators/`, `schemas/`, or inline in route files

### Fastify
```javascript
fastify.get|post|put|patch|delete
fastify.register(plugin, { prefix: '/api' })
```
- Schemas in route `schema: { body, response, querystring, params }`

### NestJS
```typescript
@Controller('users')
@Get() @Post() @Put() @Patch() @Delete()
@UseGuards(AuthGuard)
@Body() @Param() @Query()
```
- Global prefix in `main.ts`: `app.setGlobalPrefix('api')`
- DTOs in `*.dto.ts`, validation via class-validator decorators

### Hono / Elysia / tRPC
- Hono: `app.get('/path', handler)` — check `app.route()` mounts
- Elysia: `.get()`, `.post()` chain; schemas inline
- tRPC: procedures in `router.ts`; expose as HTTP via adapter — document the HTTP path from adapter config

---

## Python

### FastAPI
```python
@app.get|post|put|patch|delete
@router.get|post
APIRouter(prefix="/users")
```
- Models in Pydantic `BaseModel` classes
- Auto-generated OpenAPI at `/docs` or `/openapi.json` — fetch and cross-check
- Dependencies: `Depends(get_current_user)` indicate auth

### Flask
```python
@app.route('/path', methods=['GET', 'POST'])
@app.get|post (Flask 2.0+)
Blueprint('name', __name__, url_prefix='/api')
```
- Schemas in Marshmallow, Pydantic, or WTForms

### Django REST Framework
```python
urlpatterns = [path('users/', UserView.as_view())]
class UserView(APIView|ViewSet)
@action(detail=True, methods=['post'])
```
- Serializers define request/response shape
- Check `urls.py` at project and app level
- ViewSets generate multiple routes from one class — list all `@action` decorators

---

## Go

```go
http.HandleFunc|mux.HandleFunc
router.GET|POST|PUT|PATCH|DELETE  // gin, chi, echo
r.Route("/users", func(r chi.Router) { ... })
```
- **Gin**: `router.Group("/api/v1")`
- **Chi**: `r.Route`, `r.Get`, `r.Post`
- **Echo**: `e.GET`, `e.Group`
- **net/http**: `http.Handle`, `ServeMux` patterns
- Struct tags on handler input structs define JSON/query fields

---

## Ruby

### Rails
```ruby
resources :users
get|post|put|patch|delete '/path'
namespace :api do ... end
```
- Run `rails routes` if CLI available — authoritative route list
- Strong params in controllers define allowed body fields
- Serializers (ActiveModel::Serializer, Blueprinter, jbuilder) define responses

---

## Java / Kotlin

### Spring Boot
```java
@RestController
@RequestMapping("/api/users")
@GetMapping @PostMapping @PutMapping @DeleteMapping
@PathVariable @RequestBody @RequestParam
```
- DTOs/records for request/response
- Security: `@PreAuthorize`, Spring Security config for public vs protected paths

---

## PHP

### Laravel
```php
Route::get|post|put|patch|delete
Route::apiResource('users', UserController::class)
Route::prefix('api')->group(...)
```
- Run `php artisan route:list` if available
- Form Requests define validation rules

---

## Rust

```rust
// Actix
#[get("/users/{id}")]
web::resource("/users").route(web::get().to(...))

// Axum
Router::new().route("/users", get(handler))
```
- Serde structs with `#[derive(Deserialize, Serialize)]` define shapes

---

## Existing spec files

| File pattern | Action |
|-------------|--------|
| `openapi.yaml`, `openapi.json` | Primary source; validate against code |
| `swagger.yaml`, `swagger.json` | Same as OpenAPI (may be v2 — convert mentally) |
| `*.proto` + gRPC gateway | HTTP paths in `google.api.http` annotations |
| GraphQL schema (`schema.graphql`) | List queries/mutations; POST to GraphQL endpoint |

---

## Auth discovery checklist

Search for these to determine auth requirements per route or globally:

```
authenticate|authorize|authMiddleware|AuthGuard|@PreAuthorize
jwt|passport|session|apiKey|bearer
Depends(get_current_user)|getAuth|requireAuth
401|403|Unauthorized
```

Document whether auth is global, per-route, or role-based.
