<div align="center">

# Soum-ik / skills

**A growing collection of Claude Code skills.**

[![skills.sh](https://img.shields.io/badge/skills.sh-soum--ik-000?style=for-the-badge)](https://skills.sh/soum-ik)
[![GitHub](https://img.shields.io/badge/GitHub-Soum--ik-181717?style=for-the-badge&logo=github)](https://github.com/Soum-ik)
[![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](./LICENSE)

</div>

---

## What's inside

Each folder in this repo is a self-contained Claude Code skill — drop-in capabilities that make Claude better at a specific task. Skills work in Claude Code, Cursor, Codex, Gemini CLI, and every agent that follows the [skills.sh](https://skills.sh) standard.

## Skills

| Skill | What it does |
|-------|--------------|
| [**api-postman-export**](./api-postman-export) | Discovers every HTTP endpoint in a codebase and exports it as an importable Postman Collection v2.1 — with tests, curl examples, and a Markdown API reference. Works across Express, NestJS, FastAPI, Flask, Django, Gin, Chi, and more. |

*More skills coming soon.*

## Install a skill

Use the [skills CLI](https://skills.sh) — one command, works with any agent:

```bash
npx skills add https://github.com/Soum-ik/skills --skill <skill-name>
```

**Example:**

```bash
npx skills add https://github.com/Soum-ik/skills --skill api-postman-export
```

The CLI will ask which agents to install it into (Claude Code, Cursor, Codex, etc.) and handle the rest.

## Install all skills at once

```bash
npx skills add https://github.com/Soum-ik/skills
```

## Manual install

Prefer to do it yourself? Clone into your agent's skills directory:

```bash
git clone https://github.com/Soum-ik/skills.git ~/.claude/skills-soum-ik
```

Then symlink or copy the specific skill folder you want:

```bash
ln -s ~/.claude/skills-soum-ik/api-postman-export ~/.claude/skills/api-postman-export
```

## Repo structure

```
skills/
├── README.md                    ← you are here
├── LICENSE
└── <skill-name>/
    ├── SKILL.md                 ← skill definition (name, description, workflow)
    ├── README.md                ← per-skill docs
    ├── assets/                  ← templates and static files
    ├── references/              ← deep-dive docs Claude reads on demand
    ├── scripts/                 ← helper scripts (validators, generators)
    └── evals/                   ← evaluation cases
```

## Contributing a skill idea

Have an idea for a skill? Open an [issue](https://github.com/Soum-ik/skills/issues) — describe the workflow you'd like automated and I'll consider it for the next release.

## Author

**Soumik Sarkar**
- GitHub — [@Soum-ik](https://github.com/Soum-ik)
- skills.sh profile — [skills.sh/soum-ik](https://skills.sh/soum-ik)

## License

[MIT](./LICENSE) — free to use, modify, and share.
