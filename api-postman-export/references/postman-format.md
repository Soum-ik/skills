# Postman Collection v2.1 Format Reference

Schema URL (required in every collection):
```
https://schema.getpostman.com/json/collection/v2.1.0/collection.json
```

Validate against: `https://schema.getpostman.com/json/collection/v2.1.0/collection.json`

---

## Minimal valid collection

```json
{
  "info": {
    "name": "My API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": []
}
```

---

## Collection with variables and auth folder

```json
{
  "info": {
    "name": "My API",
    "description": "Generated from codebase",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "variable": [
    { "key": "baseUrl", "value": "http://localhost:3000", "type": "string" },
    { "key": "authToken", "value": "", "type": "string" }
  ],
  "item": [
    {
      "name": "Auth",
      "item": [
        {
          "name": "POST /auth/login",
          "event": [
            {
              "listen": "test",
              "script": {
                "exec": [
                  "pm.test('Status is 200', () => pm.response.to.have.status(200));",
                  "const json = pm.response.json();",
                  "if (json.token) pm.collectionVariables.set('authToken', json.token);"
                ],
                "type": "text/javascript"
              }
            }
          ],
          "request": {
            "method": "POST",
            "header": [
              { "key": "Content-Type", "value": "application/json" }
            ],
            "body": {
              "mode": "raw",
              "raw": "{\n  \"email\": \"user@example.com\",\n  \"password\": \"password123\"\n}",
              "options": { "raw": { "language": "json" } }
            },
            "url": {
              "raw": "{{baseUrl}}/auth/login",
              "host": ["{{baseUrl}}"],
              "path": ["auth", "login"]
            },
            "description": "Authenticate and store token in collection variable."
          },
          "response": []
        }
      ]
    }
  ]
}
```

---

## Request with path params, query, body, tests, and saved response

```json
{
  "name": "GET /api/users/:id",
  "event": [
    {
      "listen": "test",
      "script": {
        "exec": [
          "pm.test('Status code is 200', function () {",
          "    pm.response.to.have.status(200);",
          "});",
          "pm.test('Response has id', function () {",
          "    const json = pm.response.json();",
          "    pm.expect(json).to.have.property('id');",
          "});"
        ],
        "type": "text/javascript"
      }
    }
  ],
  "request": {
    "auth": {
      "type": "bearer",
      "bearer": [{ "key": "token", "value": "{{authToken}}", "type": "string" }]
    },
    "method": "GET",
    "header": [],
    "url": {
      "raw": "{{baseUrl}}/api/users/:id?id=abc-123",
      "host": ["{{baseUrl}}"],
      "path": ["api", "users", ":id"],
      "variable": [
        { "key": "id", "value": "abc-123", "description": "User UUID" }
      ],
      "query": []
    },
    "description": "Retrieve a single user by ID. Requires authentication."
  },
  "response": [
    {
      "name": "Success",
      "originalRequest": {
        "method": "GET",
        "header": [],
        "url": {
          "raw": "{{baseUrl}}/api/users/abc-123",
          "host": ["{{baseUrl}}"],
          "path": ["api", "users", "abc-123"]
        }
      },
      "status": "OK",
      "code": 200,
      "_postman_previewlanguage": "json",
      "header": [{ "key": "Content-Type", "value": "application/json" }],
      "body": "{\n  \"id\": \"abc-123\",\n  \"email\": \"user@example.com\"\n}"
    }
  ]
}
```

---

## POST with JSON body

```json
{
  "name": "POST /api/users",
  "request": {
    "method": "POST",
    "header": [
      { "key": "Content-Type", "value": "application/json" }
    ],
    "body": {
      "mode": "raw",
      "raw": "{\n  \"email\": \"new@example.com\",\n  \"name\": \"Jane Doe\"\n}",
      "options": { "raw": { "language": "json" } }
    },
    "url": {
      "raw": "{{baseUrl}}/api/users",
      "host": ["{{baseUrl}}"],
      "path": ["api", "users"]
    }
  },
  "response": []
}
```

---

## File upload (form-data)

```json
{
  "body": {
    "mode": "formdata",
    "formdata": [
      {
        "key": "file",
        "type": "file",
        "src": [],
        "description": "Image file to upload"
      },
      { "key": "title", "value": "My Photo", "type": "text" }
    ]
  }
}
```

---

## URL construction rules

| Route in code | Postman path array |
|--------------|-------------------|
| `/api/users` | `["api", "users"]` |
| `/api/users/:id` | `["api", "users", ":id"]` with variable `{ "key": "id", "value": "..." }` |
| `/api/users/{id}` (FastAPI/OpenAPI) | Same as `:id` style |

Always set `"host": ["{{baseUrl}}"]` and `"raw": "{{baseUrl}}/api/users/:id"`.

---

## Test script patterns

**Status check:**
```javascript
pm.test("Status code is 201", () => pm.response.to.have.status(201));
```

**JSON body property:**
```javascript
pm.test("Has email field", () => {
    pm.expect(pm.response.json()).to.have.property("email");
});
```

**Array response:**
```javascript
pm.test("Returns array", () => {
    pm.expect(pm.response.json()).to.be.an("array");
});
```

**Error case (4xx):**
```javascript
pm.test("Returns 404 for missing user", () => pm.response.to.have.status(404));
```

**Response time:**
```javascript
pm.test("Response time under 500ms", () => {
    pm.expect(pm.response.responseTime).to.be.below(500);
});
```

---

## Folder structure convention

```
Collection Root
├── Auth/
│   └── POST /auth/login
├── Users/
│   ├── GET /api/users
│   ├── GET /api/users/:id
│   ├── POST /api/users
│   ├── PUT /api/users/:id
│   └── DELETE /api/users/:id
└── Orders/
    └── ...
```

Each folder is an object with `"name"` and `"item"` (array of requests or sub-folders).
