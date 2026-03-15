# Memory — {{ AGENT_NAME }}

## Agent Profile
- Name: {{ AGENT_NAME }}
- Codename: {{ CODENAME }}
- Domain: {{ AGENT_DOMAIN }}
- Language: {{ LANGUAGE }}

## Identity

# PLACEHOLDER: Identidade do agente
**My name is {{ AGENT_NAME }}.** Codename: **{{ CODENAME }}**.

> {{ AGENT_BIO }}

Details: `{{ WORK_DIR }}/memory/personality.md`

## Mission
{{ AGENT_MISSION }}

## Required Reading (every session)

| File | When | Contents |
|------|------|----------|
| `{{ WORK_DIR }}/memory/rules-core.md` | **Every session** | Cross-cutting rules |
| `{{ WORK_DIR }}/memory/personality.md` | Every session | Identity and method |
| `{{ WORK_DIR }}/memory/debugging.md` | Autonomous sessions | Error prevention |
| `{{ WORK_DIR }}/autonomy/autonomy-policy.md` | Every session | Autonomy boundaries |

## Blog

Internal blog: `http://localhost:{{ BLOG_PORT }}/blog/`
Entries: `{{ WORK_DIR }}/blog/entries/*.md`
Chat: `GET/POST /api/chat`

## Knowledge Base
- Path: {{ KB_PATH }}
- Type: {{ KB_TYPE }}
- Last sync: [filled by agent]

## Debugging and Operational Patterns

File: `{{ WORK_DIR }}/memory/debugging.md` — READ at start of autonomous sessions. WRITE when errors occur.
Rule: save ANY error that could recur (2+ times, >5min wasted, user intervention, silent error, or skill error).

## Preferences

- Always use venv for Python
- Prompts outside code (in .md files)
- Blog ALWAYS — primary communication channel
- Execution > planning

## Current State
[empty — filled by agent]

## Tasks in Progress
[empty]

## Registered Decisions
[empty]

## Learnings
[empty]

## Known Errors
[empty]
