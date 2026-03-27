# PLACEHOLDER_MANIFEST.md
# Intermediate artifact for install.sh generation (Prompt B)
# Each entry defines a placeholder, its description, and the question to ask the installer.

---

## Placeholders Defined

| Placeholder | Type | Required | Default | Installer Question |
|---|---|---|---|---|
| `{{ AGENT_NAME }}` | string | yes | — | "What is the name/codename of your agent? (e.g., my-agent, atlas, orion)" |
| `{{ CODENAME }}` | string | no | same as AGENT_NAME | "Codename for the agent? [Enter to use AGENT_NAME]" |
| `{{ AGENT_MISSION }}` | text | yes | — | "Describe the agent's mission in 1-2 sentences:" |
| `{{ AGENT_BIO }}` | text | no | derived from mission | "Short bio/tagline for the agent (1 line):" |
| `{{ AGENT_PERSONA }}` | text | no | "Direct, technical, detail-oriented" | "What is the agent's tone of voice? [Enter for default]" |
| `{{ AGENT_COGNITIVE_PROFILE }}` | text | no | "Analytical. Decomposes problems, seeks underlying structure." | "Describe the agent's cognitive profile [Enter for default]:" |
| `{{ AGENT_DOMAIN }}` | string | yes | — | "What is the business domain? (e.g., edtech, fintech, health, retail)" |
| `{{ LANGUAGE }}` | string | no | "pt-BR" | "Primary language? [Enter for pt-BR]" |
| `{{ REPO_NAME }}` | string | yes | — | "GitHub repository name (e.g., my-agent):" |
| `{{ REPO_OWNER }}` | string | yes | — | "GitHub user/org (e.g., johndoe):" |
| `{{ WORK_DIR }}` | path | calculated | — | computed as the repo's absolute path at install time |
| `{{ USER_HOME }}` | path | calculated | — | computed as $HOME at install time |
| `{{ OPENAI_API_KEY }}` | secret | yes | — | "Enter your OPENAI_API_KEY (sk-...):" |
| `{{ GEMINI_API_KEY }}` | secret | yes | — | "Enter your GEMINI_API_KEY (from aistudio.google.com):" |
| `{{ EXA_API_KEY }}` | secret | no | "" | "Enter your EXA_API_KEY (leave empty to skip):" |
| `{{ SKILL_PREFIX }}` | string | yes | AGENT_NAME | "Skill prefix for slash commands? (e.g., 'aeita' → /aeita-heartbeat) [Enter to use AGENT_NAME]:" |
| `{{ TOOL_PREFIX }}` | string | yes | "edge" | "Tool prefix for CLI tools? (e.g., 'edge' → edge-fontes) [Enter for 'edge']:" |
| `{{ HEARTBEAT_INTERVAL }}` | enum | yes | hourly | "Heartbeat frequency? [1: every 30min, 2: hourly, 3: every 2h, 4: daily]" |
| `{{ HEARTBEAT_SECONDS }}` | int | calculated | — | computed from HEARTBEAT_INTERVAL (1800, 3600, 7200, 86400) |
| `{{ SYSTEMD_INTERVAL }}` | string | calculated | — | computed from HEARTBEAT_INTERVAL (30min, 1h, 2h, 24h) |
| `{{ HEARTBEAT_PROMPT }}` | long_text | yes | — | "What prompt should be sent to the agent each cycle? ($EDITOR will open)" |
| `{{ KB_PATH }}` | path_or_url | yes | — | "Where is the business knowledge base? (local path, git URL, or https URL):" |
| `{{ KB_TYPE }}` | enum | calculated | — | auto-detected from KB_PATH type |
| `{{ KB_REFRESH }}` | enum | no | on-start | "When to update the KB? [1: on start, 2: daily, 3: manual]" |
| `{{ USER_TIMEZONE }}` | string | no | America/Sao_Paulo | "Timezone? [Enter for America/Sao_Paulo]" |
| `{{ GITHUB_USER }}` | string | calculated | — | detected via: `gh api user --jq .login` |
| `{{ BLOG_PORT }}` | int | no | 8080 | "Blog/web server port (Enter for 8080, empty to disable):" |
| `{{ BLOG_AUTH_USER }}` | string | no | "admin" | "Blog auth username [Enter for admin]:" |
| `{{ BLOG_AUTH_PASS }}` | secret | no | — | "Blog auth password:" |

---

## Question Groups (order in install.sh)

### Group 1 — Agent Identity
- AGENT_NAME
- CODENAME (optional, defaults to AGENT_NAME)
- AGENT_MISSION
- AGENT_BIO (optional, derived from mission)
- AGENT_PERSONA (optional)
- AGENT_COGNITIVE_PROFILE (optional)
- AGENT_DOMAIN
- LANGUAGE (optional)

### Group 2 — Repository and Access
- REPO_OWNER (auto-detected via `gh`, confirm)
- REPO_NAME
- SKILL_PREFIX (defaults to AGENT_NAME)
- TOOL_PREFIX (defaults to "edge")

### Group 3 — APIs and Credentials
- OPENAI_API_KEY
- GEMINI_API_KEY (for deep research + adversarial validation)
- EXA_API_KEY (optional)

### Group 4 — Heartbeat
- HEARTBEAT_INTERVAL (enum → auto-compute HEARTBEAT_SECONDS and SYSTEMD_INTERVAL)
- HEARTBEAT_PROMPT (open $EDITOR for long input)

### Group 5 — Knowledge Base
- KB_PATH (with validation: accepts existing local path, valid git URL, https URL)
- KB_TYPE (auto-detected)
- KB_REFRESH (optional)

### Group 6 — System (optional, with defaults)
- USER_TIMEZONE
- BLOG_PORT
- BLOG_AUTH_USER
- BLOG_AUTH_PASS

### Computed at Install Time (not asked)
- WORK_DIR — `$(pwd)` at install time
- USER_HOME — `$HOME` at install time
- GITHUB_USER — `gh api user --jq .login`
- KB_TYPE — detected from KB_PATH format
- HEARTBEAT_SECONDS — from HEARTBEAT_INTERVAL mapping
- SYSTEMD_INTERVAL — from HEARTBEAT_INTERVAL mapping

---

## Validations

```
OPENAI_API_KEY     → must start with "sk-"
GEMINI_API_KEY     → must start with "AIza"
EXA_API_KEY        → if provided, non-empty string
KB_PATH (local)    → must exist: test -d "$KB_PATH" || test -f "$KB_PATH"
KB_PATH (git)      → must be valid git URL: git ls-remote "$KB_PATH" 2>/dev/null
KB_PATH (url)      → must respond: curl -sI "$KB_PATH" | grep -q "200"
REPO_NAME          → only letters, numbers, and hyphens: [a-zA-Z0-9-]+
AGENT_NAME         → only letters, numbers, and hyphens: [a-zA-Z0-9-]+
HEARTBEAT_INTERVAL → must be 1, 2, 3, or 4
BLOG_PORT          → numeric, 1024-65535
```

---

## OS → Activation Method

```
Linux   → systemd (cp service + timer → ~/.config/systemd/user/, systemctl --user enable/start)
macOS   → launchd (cp plist → ~/Library/LaunchAgents/, launchctl load)
Windows → Task Scheduler (New-ScheduledTask via PS1)
```

---

## Files That Use Each Placeholder

| Placeholder | Files |
|---|---|
| `AGENT_NAME` | CLAUDE.md.tpl, MEMORY.md.tpl, personality.md.tpl, heartbeat.sh.tpl, heartbeat.plist.tpl, kb.config.tpl, agent-heartbeat.service.tpl, agent-heartbeat.timer.tpl, blog-server.service.tpl, .env.example, models.env.example |
| `CODENAME` | CLAUDE.md.tpl, MEMORY.md.tpl |
| `AGENT_MISSION` | CLAUDE.md.tpl, MEMORY.md.tpl |
| `AGENT_BIO` | CLAUDE.md.tpl, MEMORY.md.tpl, personality.md.tpl |
| `AGENT_PERSONA` | personality.md.tpl |
| `AGENT_COGNITIVE_PROFILE` | personality.md.tpl |
| `AGENT_DOMAIN` | CLAUDE.md.tpl, MEMORY.md.tpl, kb.config.tpl |
| `LANGUAGE` | MEMORY.md.tpl |
| `WORK_DIR` | CLAUDE.md.tpl, MEMORY.md.tpl, heartbeat.sh.tpl, heartbeat.ps1.tpl, heartbeat.plist.tpl, blog-server.service.tpl |
| `USER_HOME` | heartbeat.plist.tpl |
| `SKILL_PREFIX` | CLAUDE.md.tpl, heartbeat.sh.tpl, heartbeat.ps1.tpl |
| `TOOL_PREFIX` | CLAUDE.md.tpl |
| `BLOG_PORT` | CLAUDE.md.tpl, MEMORY.md.tpl, blog-server.service.tpl |
| `KB_PATH` | CLAUDE.md.tpl, MEMORY.md.tpl, kb.config.tpl |
| `KB_TYPE` | CLAUDE.md.tpl, MEMORY.md.tpl, kb.config.tpl |
| `KB_REFRESH` | CLAUDE.md.tpl, kb.config.tpl |
| `HEARTBEAT_INTERVAL` | CLAUDE.md.tpl |
| `HEARTBEAT_PROMPT` | CLAUDE.md.tpl |
| `HEARTBEAT_SECONDS` | heartbeat.plist.tpl |
| `SYSTEMD_INTERVAL` | agent-heartbeat.timer.tpl |
| `REPO_OWNER` | heartbeat.plist.tpl |
| `BLOG_AUTH_USER` | (runtime only — secrets/keys.env) |
| `BLOG_AUTH_PASS` | (runtime only — secrets/keys.env) |
| `OPENAI_API_KEY` | (runtime only — secrets/keys.env) |
| `GEMINI_API_KEY` | (runtime only — secrets/keys.env) |
| `EXA_API_KEY` | (runtime only — secrets/keys.env) |
