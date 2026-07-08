# api-postman-export

A Claude Code Skill that discovers every HTTP API in a codebase and turns it into a documented, testable **Postman Collection v2.1** — plus a human-readable Markdown reference.

Point Claude at a project and it will inventory the routes, capture request/response shapes, write realistic examples, and hand back two files ready to import and share.

## What you get

Every run produces two deliverables:

| File | Purpose |
|------|---------|
| `postman/<project>.postman_collection.json` | Importable Postman Collection v2.1 with folders, variables, tests, and saved responses |
| `docs/api-reference.md` | Human-readable API catalog with curl examples, auth notes, and response shapes |

## When to use it

Trigger this skill whenever you want to:

- Catalog every endpoint in an unfamiliar codebase
- Generate a Postman collection without hand-writing JSON
- Produce API documentation directly from source code
- Bootstrap request/response tests for a new project
- Reconcile an existing OpenAPI spec against what the code actually exposes

Natural prompts that fire the skill: *"export our endpoints to Postman"*, *"what APIs do we have?"*, *"document the REST routes"*, *"give me curl examples for every endpoint"*.

## How it works

The skill runs a seven-phase workflow:

1. **Understand the project** — stack, entry point, base URL, auth mechanism
2. **Discover every endpoint** — framework-aware grep patterns; cross-check against tests and specs
3. **Write realistic test examples** — pulled from fixtures, tests, and schema defaults
4. **Generate the Postman collection** — folders per resource, variables for `baseUrl` / `authToken`, test scripts on every request
5. **Write the Markdown reference** — curl snippets, response shapes, auth notes
6. **Validate** — `scripts/validate_collection.py` must pass before delivery
7. **Present** — file locations, import instructions, endpoint count, uncertain items flagged

Supported frameworks include Express, NestJS, Fastify, FastAPI, Flask, Django, Gin, Chi, net/http, Spring, and more. See `references/discovery-patterns.md` for the full pattern list.

## Layout

```
api-postman-export/
├── SKILL.md                          # Skill definition + workflow
├── assets/
│   └── collection-template.json      # Postman v2.1 skeleton
├── references/
│   ├── discovery-patterns.md         # Framework-specific route patterns
│   └── postman-format.md             # Postman collection schema reference
├── scripts/
│   └── validate_collection.py        # Collection validator
└── evals/
    └── evals.json                    # Evaluation cases
```

## Installation

Drop the folder into your Claude Code skills directory:

```bash
git clone https://github.com/Soum-ik/api-postman-export ~/.claude/skills/api-postman-export
```

Claude Code auto-discovers skills at startup. Verify with `/skills` or by mentioning Postman export in any project.

## Using the output

1. Open Postman → **Import** → drag `postman/<project>.postman_collection.json`
2. Set the `baseUrl` and `authToken` collection variables (or run the `Auth` folder first — the login request saves the token automatically)
3. Send any request; the bundled test scripts assert status and shape

## Conventions

| Item | Convention |
|------|-----------|
| Collection filename | `postman/<kebab-project-name>.postman_collection.json` |
| Docs filename | `docs/api-reference.md` |
| Folder names | PascalCase resource names (`Users`, `Orders`) |
| Request names | `<METHOD> <path>` e.g. `GET /api/users/:id` |
| Uncertain endpoints | Prefix with `[?]` and describe the uncertainty |
| Secrets | Never inlined — always via `{{authToken}}` / `{{apiKey}}` variables |

## License

MIT
