# PRD: Implementar Gaps do REPLICATION_BLUEPRINT

## Introduction

O `REPLICATION_BLUEPRINT.md` descreve uma arquitetura completa de agente autônomo com ciclo de heartbeat, publicação atômica (8 fases), adversarial review, state management, e 22 skills core. Uma auditoria revelou que **a maioria dessas features existe apenas no blueprint, não no código**. Este PRD especifica a implementação de todos os gaps identificados, tanto no `agent-template` quanto nos 5 experimentos (`business-experiments`).

### Gaps identificados

- **19 de 22 skills core** não existem como templates
- **Pipeline `consolidar-estado`** (8 fases atômicas) não existe
- **Blog server** (Node.js com API REST) não existe
- **Search system** (edge-search/edge-index com SQLite FTS5) não existe
- **Shared skill protocols** (state-protocol.md, report-template.md) ausentes
- **Autonomy policy** ausente
- **9 diretórios estruturais** não criados (threads/, state/, meta-reports/, etc.)
- **Claims/Threads/Events** — ferramentas existem mas infraestrutura de dados não
- **5 plugins Claude Code** não implementados
- **Git structured commits** não implementado
- **State audit, meta-reports, HTML reports** — ferramentas existem mas não são usados

### Repositórios afetados

- `/home/alex/Projects/agent-template` — templates .tpl e arquivos base
- `/home/alex/Projects/business-experiments` — 5 agentes (devolver_ai, fornece_ai, negocia_ai, parceiro_ai, recruta_ai)

## Goals

- Implementar 100% das features descritas no REPLICATION_BLUEPRINT.md
- Manter compatibilidade com o `bootstrap-experiments.sh` existente
- Cada skill template deve ser completo e autocontido (não stubs)
- Blog server funcional com API de chat, entries e autenticação
- Pipeline consolidar-estado operacional end-to-end
- Search system funcional com SQLite FTS5
- Todos os 5 experimentos atualizados via bootstrap
- Todos os templates usam placeholders `{{VARIAVEL}}` substituíveis pelo install.sh/bootstrap

## User Stories

---

### US-001: Criar diretórios estruturais no template

**Description:** Como um operador do template, eu quero que todos os diretórios necessários existam na estrutura do template para que o bootstrap crie a estrutura correta nos experimentos.

**Acceptance Criteria:**
- [ ] Criar no agent-template (com `.gitkeep` em cada): `threads/`, `state/`, `state-snapshots/`, `builds/`, `lab/`, `autonomy/`, `notes/`, `meta-reports/`, `bin/`, `blog/entries/`, `reports/`
- [ ] Atualizar `bootstrap-experiments.sh` para criar esses diretórios em cada agente
- [ ] Verificar que `install.sh` também cria esses diretórios (seção de setup)
- [ ] Todos os 5 experimentos têm os diretórios após re-bootstrap

---

### US-002: Criar shared skill protocols

**Description:** Como um agente autônomo, eu preciso de protocolos compartilhados entre skills para manter consistência de estado e relatórios.

**Acceptance Criteria:**
- [ ] Criar `templates/skills/_shared/state-protocol.md` com:
  - Protocolo de gestão de estado: snapshot PRE → propose changes → edit → audit POST
  - Lista de arquivos protegidos (business.md seções 1-2, CLAUDE.md, rules-core.md)
  - Formato de proposta de mudança (YAML: file, target_text, replacement_text)
  - Regras de rollback (quando reverter)
  - Referência a `edge-state-audit` para snapshot/audit
- [ ] Criar `templates/skills/_shared/report-template.md` com:
  - Estrutura YAML padrão para reports (title, subtitle, sections com blocks)
  - Tipos de block suportados (text, list, table, code, callout, svg)
  - Exemplo completo de YAML spec
  - Instruções para invocar review-gate antes de publicar
  - Referência a `consolidar-estado` como pipeline obrigatório
- [ ] Ambos os arquivos propagados para cada agente em `.claude/skills/_shared/`
- [ ] Heartbeat skill template referencia `_shared/state-protocol.md`

---

### US-003: Criar autonomy policy

**Description:** Como um agente autônomo, eu preciso de uma política clara de quando posso agir sozinho e quando devo perguntar ao humano.

**Acceptance Criteria:**
- [ ] Criar `autonomy/autonomy-policy.md` no template com:
  - **Pré-autorizado** (executar livremente): pesquisa, hipóteses, criação de conteúdo, blog, até $2 spend, busca de domínio, reports
  - **Requer aprovação** (notify.sh --level blocked): criar contas, registrar domínios, pagar >$2, publicar impersonando pessoas reais, decisões legais, mudanças em arquivos protegidos
  - **Guardrails**: acesso a rede monitorado, escrita restrita ao workspace, execução de código rastreada
  - Formato: tabela com contexto → ação → nível de autonomia
- [ ] Arquivo referenciado no CLAUDE.md.tpl como Required Reading ("Every session")
- [ ] Arquivo referenciado no MEMORY.md.tpl
- [ ] Propagado para os 5 experimentos

---

### US-004: Implementar blog server (Node.js)

**Description:** Como um agente autônomo, eu preciso de um blog server interno para publicar insights, receber mensagens via chat API, e servir entries como canal primário de comunicação.

**Acceptance Criteria:**
- [ ] Criar `blog/server.js` — servidor Express.js com as seguintes rotas:
  - `GET /blog/` — lista entries (HTML)
  - `GET /blog/:slug` — entry individual (HTML renderizado de markdown)
  - `GET /api/entries` — lista entries (JSON)
  - `GET /api/entries/:slug` — entry individual (JSON)
  - `POST /api/entries` — criar entry (autenticado)
  - `GET /api/chat` — listar mensagens de chat pendentes (JSON)
  - `POST /api/chat` — enviar mensagem para o agente (JSON)
  - `DELETE /api/chat/:id` — marcar mensagem como lida
  - `GET /api/health` — health check
- [ ] Criar `blog/package.json` com dependências: express, marked, gray-matter, basic-auth
- [ ] Autenticação via HTTP Basic Auth (variáveis `BLOG_AUTH_USER`, `BLOG_AUTH_PASS`)
- [ ] Porta configurável via `BLOG_PORT` (default 8766)
- [ ] Entries são arquivos `.md` em `blog/entries/` com YAML frontmatter (title, date, tags, claims, threads)
- [ ] Chat armazenado em `blog/chat.json` (append-only)
- [ ] Template em `blog/server.js.tpl` com placeholders `{{BLOG_PORT}}`, `{{BLOG_AUTH_USER}}`, `{{BLOG_AUTH_PASS}}`
- [ ] Atualizar `systemd/blog-server.service.tpl` para apontar para server.js
- [ ] Criar `blog/views/` com templates HTML minimalistas (layout.html, entry.html, index.html)
- [ ] Server funcional: `node blog/server.js` sobe e responde em todas as rotas
- [ ] Propagado para os 5 experimentos via bootstrap

---

### US-005: Implementar pipeline consolidar-estado

**Description:** Como um agente autônomo, eu preciso de um pipeline atômico de 8 fases para publicar conteúdo, manter estado consistente, e fazer git commit estruturado.

**Acceptance Criteria:**
- [ ] Criar `bin/consolidar-estado` (bash script executável) com 8 fases:
  - **Phase 0a**: `edge-state-audit snapshot --slug $SLUG` (SHA256 PRE)
  - **Phase 0.3**: `edge-consult` adversarial review do conteúdo principal
  - **Phase 0.5**: `review-gate.py` quality gate no YAML spec (se fornecido). Threshold 3.5/5. Se FAIL, exit code 3
  - **Phase 1**: Publicar blog entry via `POST /api/entries` (curl para blog server)
  - **Phase 2**: Gerar HTML report via `generate_report.py` se YAML spec fornecido. Output em `reports/`
  - **Phase 3**: Verificar publicação (curl GET para confirmar entry existe)
  - **Phase 4**: Gerar meta-report via `edge-meta-report` com state delta + scratchpad. Output em `meta-reports/`
  - **Phase 5**: State commit — extrair claims (`edge-claims`), atualizar threads, log evento (`edge-event`), gerar digest (`edge-digest`)
  - **Phase 5b**: `edge-state-audit audit --slug $SLUG` (comparar PRE vs POST). Se violação, exit code 5
  - **Phase 6**: Git add + commit estruturado com metadados no footer
- [ ] Exit codes semânticos: 0=ok, 1=fatal, 2=partial, 3=review fail, 5=state violation
- [ ] Flags: `--skip-review` (pular Phase 0.3/0.5), `--recover` (re-processar entry sem git commit), `--dry-run`
- [ ] Orphan guard: destage arquivos que não pertencem ao slug atual antes de commitar
- [ ] Log de falhas em `logs/pipeline-failures.jsonl`
- [ ] Idempotência: checar `events.jsonl` antes de duplicar evento
- [ ] Uso: `consolidar-estado blog/entries/2026-03-21-meu-post.md [spec.yaml]`
- [ ] Script propagado para `bin/` de cada experimento

---

### US-006: Implementar search system (edge-search + edge-index)

**Description:** Como um agente autônomo, eu preciso buscar no meu próprio corpus local para evitar redescobrir temas e conectar conhecimento existente.

**Acceptance Criteria:**
- [ ] Criar `tools/edge-index` (bash/python) que:
  - Recebe diretórios como argumentos: `edge-index reports/ notes/ blog/entries/`
  - Extrai texto de arquivos .md e .html
  - Indexa em SQLite com FTS5 (full-text search): `state/search.db`
  - Schema: `CREATE VIRTUAL TABLE corpus USING fts5(path, title, content, tags)`
  - Flag `--no-embed` para pular embeddings (default: sem embeddings)
  - Flag `--quiet` para suprimir output
  - Incremental: só re-indexa arquivos modificados desde última indexação (checar mtime)
- [ ] Criar `tools/edge-search` (bash/python) que:
  - Recebe query como argumento: `edge-search "adversarial review" -k 5`
  - Busca via FTS5 na SQLite
  - Retorna resultados rankeados: path, title, snippet, score
  - Flag `-k N` para limitar resultados (default 5)
  - Flag `--json` para output JSON
- [ ] Atualizar `heartbeat.sh.tpl` para chamar `edge-index` no final (sync RAG index), como já sugerido no blueprint
- [ ] Criar `state/` diretório para conter `search.db`
- [ ] Propagado para os 5 experimentos

---

### US-007: Skill template — {PREFIX}-descoberta

**Description:** Como um agente autônomo, eu preciso de uma skill de exploração lateral para encontrar conexões inesperadas e expandir meu repertório.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/descoberta/SKILL.md` com:
  - **Propósito**: Exploração lateral, conexões entre domínios, serendipidade
  - **Trigger**: Heartbeat (PREFLIGHT_CLEAN ou classificação EXPLORE)
  - **Passos completos**:
    1. Absorver contexto: ler últimos 3 blog entries, threads ativos, briefing.md
    2. Escolher ângulo: tema adjacente ao domínio principal, nunca o tema principal direto
    3. `edge-fontes` com query exploratória (combinar domínio + área inesperada)
    4. Derivar antes de pesquisar (Feynman): formular hipótese antes de ler resultados
    5. `edge-consult --mode collab` para expandir ângulos não vistos
    6. `edge-scratch add` para observações mid-sessão
    7. Gerar YAML spec com descobertas
    8. `review-gate` no YAML
    9. Escrever blog entry com claims e threads
    10. `consolidar-estado` para publicar
    11. `edge-skill-step end` para verificar completude
  - Referência a `_shared/state-protocol.md` e `_shared/report-template.md`
  - Formato de claims no frontmatter do blog entry
- [ ] Registrar passos em `tools/skill-steps-registry.yaml` sob `descoberta:`
- [ ] Template usa placeholders `{{PREFIX}}`, `{{WORK_DIR}}`
- [ ] Propagado para os 5 experimentos como `{AGENT}-descoberta`

---

### US-008: Skill template — {PREFIX}-lazer

**Description:** Como um agente autônomo, eu preciso de breaks criativos para manter diversidade de pensamento e evitar saturação temática.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/lazer/SKILL.md` com:
  - **Propósito**: Break criativo — builds, derivações, haikus, analogias, jogos mentais
  - **Trigger**: Heartbeat (PREFLIGHT_CLEAN, ~20% dos beats)
  - **Passos completos**:
    1. Escolher formato criativo: derivação matemática, analogia cross-domain, haiku técnico, thought experiment, mini-build
    2. Contexto leve: NÃO ler estado completo — apenas personality.md para manter tom
    3. Executar atividade criativa (sem ferramentas externas — puro raciocínio)
    4. `edge-scratch add` com resultado
    5. Se insight relevante surgir: formular como claim
    6. Blog entry curto (formato leve, sem YAML spec pesado)
    7. `consolidar-estado` (com `--skip-review` — lazer não precisa de quality gate)
    8. `edge-skill-step end`
  - Anti-saturação: verificar últimos 3 beats — se todos foram lazer, forçar mudança
- [ ] Registrar passos em `skill-steps-registry.yaml`
- [ ] Propagado para os 5 experimentos

---

### US-009: Skill template — {PREFIX}-reflexao

**Description:** Como um agente autônomo, eu preciso de auto-reflexão periódica para processar feedback, podar regras obsoletas, e atualizar meu comportamento.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/reflexao/SKILL.md` com:
  - **Propósito**: Auto-reflexão, processar feedback, atualizar regras, podar memória
  - **Trigger**: Heartbeat (a cada ~5 beats), ou quando há feedback acumulado
  - **Passos completos**:
    1. Ler `memory/misses.md` — erros acumulados que uma regra teria prevenido
    2. Ler `memory/debugging.md` — padrões de erros recorrentes
    3. Ler `memory/rules-core.md` — estado atual das regras (max 15)
    4. `git_signals.py` — extrair fix chains e gaps persistentes do git log
    5. `edge-state-lint` — verificar consistência de estado
    6. `ledger_rollup.py` — agregar execution ledger em ops-hotspots
    7. Avaliar cada regra: ainda útil? citada nos últimos 10 beats? conflita com outra?
    8. Propor mudanças: novas regras (de misses), podar regras stale, ajustar thresholds
    9. `edge-consult` adversarial: "essas mudanças de regras fazem sentido?"
    10. Aplicar mudanças via `edge-state-audit propose` + edit + audit
    11. Atualizar `memory/topics/` — mover conhecimento maduro para topic, podar clutter
    12. Blog entry de reflexão (meta-cognitivo: o que aprendi, o que mudei, por quê)
    13. `consolidar-estado`
    14. `edge-skill-step end`
  - **NUNCA** atualizar CLAUDE.md diretamente — só via esta skill
  - Curadoria trigger: regra não citada em 10 sessões → candidata a remoção
- [ ] Registrar passos em `skill-steps-registry.yaml`
- [ ] Propagado para os 5 experimentos

---

### US-010: Skill template — {PREFIX}-estrategia

**Description:** Como um agente autônomo, eu preciso avaliar prioridades periodicamente, identificar gaps estratégicos, e rebalancear meu foco.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/estrategia/SKILL.md` com:
  - **Propósito**: Planejamento estratégico, avaliação de prioridades, identificação de gaps
  - **Trigger**: Heartbeat (a cada ~5 beats), ou quando task ledger tem muitos itens blocked
  - **Passos completos**:
    1. Ler `business.md` — modelo de negócio e métricas
    2. Ler `experiments.log` — últimos 10 ciclos (hipóteses, keeps, reverts)
    3. `edge-task stats` — estado do task ledger (doing, blocked, stale)
    4. `edge-claims --stats` — conhecimento acumulado e gaps abertos
    5. `edge-digest` — briefing compactado do estado
    6. Identificar: o que está funcionando? o que está travado? onde há gap no playbook?
    7. Priorizar: qual ação de maior impacto para as próximas 5 beats?
    8. `edge-consult` adversarial: "estou priorizando certo? que ponto cego tenho?"
    9. Atualizar task ledger: re-priorizar, dropar tasks obsoletas, criar novas
    10. Blog entry estratégico com decisões e justificativas
    11. `consolidar-estado`
    12. `edge-skill-step end`
- [ ] Registrar passos em `skill-steps-registry.yaml`
- [ ] Propagado para os 5 experimentos

---

### US-011: Skill template — {PREFIX}-planejar

**Description:** Como um agente autônomo, eu preciso transformar insights e hipóteses em propostas concretas de ação.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/planejar/SKILL.md` com:
  - **Propósito**: Converter insight/hipótese em plano de execução concreto
  - **Trigger**: Heartbeat (quando há hipótese aprovada sem plano) ou usuário
  - **Passos completos**:
    1. Identificar hipótese ou insight a planejar (de experiments.log ou blog)
    2. Ler contexto relevante: business.md, claims, threads ativos
    3. Decompor em ações atômicas (max 5 passos)
    4. Para cada ação: definir artefato esperado, métrica de sucesso, rollback
    5. Estimar: posso executar autonomamente? (checar autonomy-policy.md)
    6. `edge-consult`: "esse plano é viável? que falta?"
    7. Registrar plano em task ledger (`edge-task add` para cada ação)
    8. Blog entry com plano detalhado
    9. `consolidar-estado`
    10. `edge-skill-step end`
- [ ] Registrar passos em `skill-steps-registry.yaml`
- [ ] Propagado para os 5 experimentos

---

### US-012: Skill template — {PREFIX}-executar

**Description:** Como um agente autônomo, eu preciso implementar mudanças concretas em projetos quando autorizado.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/executar/SKILL.md` com:
  - **Propósito**: Implementar mudanças em projetos (código, conteúdo, configuração)
  - **Trigger**: NUNCA por heartbeat — apenas via usuário ou plano aprovado
  - **Passos completos**:
    1. Identificar task a executar (de task ledger, com status "todo" ou "doing")
    2. Verificar autonomy-policy.md: esta ação está pré-autorizada?
    3. Se não: `notify.sh --level blocked` e parar
    4. `edge-state-audit snapshot` PRE
    5. Executar a implementação (código, conteúdo, config)
    6. Testar/validar resultado
    7. `edge-state-audit audit` POST
    8. `edge-task update` status → done (ou blocked se falhou)
    9. Registrar em experiments.log se for um experimento
    10. Blog entry com resultado e artefatos
    11. `consolidar-estado`
    12. `edge-skill-step end`
  - Guardrails: nunca modificar arquivos protegidos sem proposta via state-audit
- [ ] Registrar passos em `skill-steps-registry.yaml`
- [ ] Propagado para os 5 experimentos

---

### US-013: Skill template — {PREFIX}-blog

**Description:** Como um agente autônomo, eu preciso de uma sub-skill para criar blog entries padronizadas com frontmatter correto.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/blog/SKILL.md` com:
  - **Propósito**: Criar blog entry com YAML frontmatter padronizado
  - **Trigger**: Chamada por outras skills (sub-skill), nunca direto pelo heartbeat
  - **Formato de entry**:
    ```yaml
    ---
    title: "Título"
    date: "YYYY-MM-DDTHH:MM:SSZ"
    tags: [tag1, tag2]
    skill: "{skill que gerou}"
    thread: "{thread-id se aplicável}"
    claims:
      - "Claim verificada 1"
      - "!Gap identificado que precisa investigação"
    memory:
      - "Insight como regra: when [X], [Y]"
    ---
    Conteúdo em markdown...
    ```
  - Naming convention: `YYYY-MM-DD-slug.md`
  - Validação: title, date, tags obrigatórios
  - Claims com `!` prefix = gaps abertos
  - Campo `memory:` = insights que podem virar regras em rules-core.md
- [ ] Propagado para os 5 experimentos

---

### US-014: Skill template — {PREFIX}-relatorio

**Description:** Como um agente autônomo, eu preciso gerar relatórios HTML autocontidos a partir de YAML specs.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/relatorio/SKILL.md` com:
  - **Propósito**: Gerar relatório HTML via YAML spec + generate_report.py
  - **Trigger**: Chamada por outras skills (sub-skill)
  - **Passos**:
    1. Receber ou gerar YAML spec conforme `_shared/report-template.md`
    2. `review-gate` no YAML spec
    3. Se FAIL: ajustar com base no feedback, re-rodar (max 2 tentativas)
    4. `generate_report.py spec.yaml` → `reports/relatorio.html`
    5. `validate_svg.py` no HTML gerado (se contém SVG)
    6. Retornar path do relatório
  - **NUNCA** chamar `generate_report.py` diretamente de outras skills — sempre via esta skill
- [ ] Propagado para os 5 experimentos

---

### US-015: Skill template — {PREFIX}-fontes

**Description:** Como um agente autônomo, eu preciso de uma sub-skill padronizada para buscar fontes externas.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/fontes/SKILL.md` com:
  - **Propósito**: Buscar fontes externas via edge-fontes
  - **Trigger**: Chamada por outras skills (sub-skill)
  - **Passos**:
    1. Verificar corpus local primeiro (`edge-search` se disponível)
    2. Se corpus insuficiente: `edge-fontes` com query estruturada
    3. Filtrar resultados por qualidade/relevância
    4. Retornar resultados curados
  - Princípio: internal sources first, external só quando necessário
  - Custo: ~$0.01-0.03 por busca Exa
- [ ] Propagado para os 5 experimentos

---

### US-016: Skill template — {PREFIX}-contexto

**Description:** Como um agente autônomo, eu preciso sintetizar meu estado atual de forma compacta antes de tomar decisões.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/contexto/SKILL.md` com:
  - **Propósito**: Sintetizar estado atual do trabalho
  - **Trigger**: Chamada por outras skills como passo preparatório
  - **Passos**:
    1. `edge-digest` — briefing.md a partir de dados estruturados
    2. Ler últimos 3 eventos (`edge-event recent`)
    3. Ler threads ativos com resurface vencido
    4. Ler task ledger (`edge-task list --status doing,blocked`)
    5. Ler últimas 3 blog entries (títulos + claims)
    6. Retornar síntese compacta (<500 tokens)
- [ ] Propagado para os 5 experimentos

---

### US-017: Skill template — {PREFIX}-estado

**Description:** Como um agente autônomo, eu preciso gerenciar meu estado de forma segura e auditável.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/estado/SKILL.md` com:
  - **Propósito**: Gerenciar estado do agente (snapshot, propose, audit)
  - **Trigger**: Chamada por outras skills
  - **Passos**:
    1. `edge-state-audit snapshot --slug $SLUG` — capturar SHA256 PRE
    2. Propor mudanças declarativas: `edge-state-audit propose --slug $SLUG` (YAML)
    3. Aplicar mudanças (editar arquivos)
    4. `edge-state-audit audit --slug $SLUG` — verificar PRE vs POST
    5. Se divergência: reverter e reportar
  - Referência completa ao `_shared/state-protocol.md`
  - Lista de arquivos protegidos que requerem proposta formal
- [ ] Propagado para os 5 experimentos

---

### US-018: Skill template — {PREFIX}-salvar-estado

**Description:** Como um agente autônomo, eu preciso salvar estado persistente de forma padronizada.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/salvar-estado/SKILL.md` com:
  - **Propósito**: Salvar estado persistente (claims, threads, events, digest)
  - **Trigger**: Chamada por consolidar-estado (Phase 5) ou diretamente
  - **Passos**:
    1. Extrair claims do artefato (`edge-claims extract`)
    2. Atualizar threads relevantes (criar novo ou append)
    3. Registrar evento (`edge-event log`)
    4. Regenerar digest (`edge-digest`)
    5. Verificar consistência (`edge-state-lint`)
- [ ] Propagado para os 5 experimentos

---

### US-019: Skill template — {PREFIX}-autonomia

**Description:** Como um agente autônomo, eu preciso expandir minhas capacidades de forma controlada e documentada.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/autonomia/SKILL.md` com:
  - **Propósito**: Expandir capacidades autônomas (novas ferramentas, integrações, skills)
  - **Trigger**: Heartbeat (raro) ou usuário
  - **Passos**:
    1. Identificar gap de capacidade (o que o agente precisa fazer mas não consegue?)
    2. Propor expansão: nova ferramenta, novo skill, nova integração
    3. `edge-consult` adversarial: "essa expansão é necessária ou prematura?"
    4. Se aprovada: implementar com testes
    5. Atualizar autonomy-policy.md se novas ações forem pré-autorizadas
    6. Registrar em blog + experiments.log
    7. `consolidar-estado`
  - Guardrail: expansões que afetam segurança requerem aprovação humana
- [ ] Propagado para os 5 experimentos

---

### US-020: Skill template — {PREFIX}-curadoria-corpus

**Description:** Como um agente autônomo, eu preciso curar meu corpus de conhecimento periodicamente para evitar clutter.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/curadoria-corpus/SKILL.md` com:
  - **Propósito**: Curadoria do corpus de conhecimento (limpar, reorganizar, identificar gaps)
  - **Trigger**: Heartbeat (periódico, quando corpus > 30 files) ou explícito
  - **Passos**:
    1. `curadoria_compute.py --mode stats` — inventário do corpus
    2. Self-probes: buscar temas centrais no próprio corpus, verificar cobertura
    3. Identificar: duplicatas, conteúdo stale, gaps de cobertura
    4. Propor ações: merge, archive, delete, criar novo topic
    5. Executar ações (com state-audit)
    6. Blog entry com resultados da curadoria
    7. `consolidar-estado`
  - Princípio: "se deletar este arquivo e meu comportamento não mudar, era clutter"
- [ ] Propagado para os 5 experimentos

---

### US-021: Skill template — {PREFIX}-experimento

**Description:** Como um agente autônomo, eu preciso rodar experimentos de negócio de forma padronizada e registrar resultados.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/experimento/SKILL.md` com:
  - **Propósito**: Rodar experimento de negócio (hipótese → teste → medição → decisão)
  - **Trigger**: Heartbeat ou usuário
  - **Passos**:
    1. Selecionar hipótese (de experiments.log pendentes ou novo gap identificado)
    2. Definir método: ANALYTICAL (pré-launch), EMPIRICAL (com dados reais), SIMULATION
    3. Executar teste (criar artefato, rodar simulação, analisar dados)
    4. Medir resultado: metric_delta quantificado
    5. Decisão: KEEP ou REVERT com justificativa
    6. `edge-consult` adversarial: "essa conclusão é sólida?"
    7. Registrar em `experiments.log` (JSON format padronizado)
    8. Ethical check: PASSED ou BLOCKED
    9. Blog entry com hipótese, método, resultado, decisão
    10. `consolidar-estado`
    11. `edge-skill-step end`
  - Formato experiments.log:
    ```json
    {"timestamp":"ISO8601","cycle":N,"hypothesis":"...","method":"ANALYTICAL|EMPIRICAL|SIMULATION","result":"...","metric_delta":N,"artifact":"path","action":{"type":"KEEP|REVERT","variant":"A|B","note":"..."},"ethical_check":{"status":"PASSED|BLOCKED","note":"..."}}
    ```
- [ ] Registrar passos em `skill-steps-registry.yaml`
- [ ] Propagado para os 5 experimentos

---

### US-022: Skill template — {PREFIX}-log

**Description:** Como um agente autônomo, eu preciso de uma sub-skill para logging padronizado de atividades.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/log/SKILL.md` com:
  - **Propósito**: Logging estruturado de atividades do agente
  - **Trigger**: Chamada por outras skills (sub-skill)
  - **Ações**:
    - Log evento: `edge-event log --type {tipo} --summary "{...}" --skill {skill} --thread {thread}`
    - Log erro: append em `memory/debugging.md` com timestamp, contexto, ação corretiva
    - Log miss: append em `memory/misses.md` com contexto e regra que teria prevenido
    - Responder chat: `POST /api/chat` com resposta a mensagem pendente
- [ ] Propagado para os 5 experimentos

---

### US-023: Skill template — {PREFIX}-mapa

**Description:** Como um agente autônomo, eu preciso de mind mapping para visualizar conexões entre temas.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/mapa/SKILL.md` com:
  - **Propósito**: Gerar mind map visual de um tema ou do estado do conhecimento
  - **Trigger**: Usuário (não despachado pelo heartbeat)
  - **Passos**:
    1. Identificar tema central
    2. Extrair claims e threads relacionados
    3. Gerar mapa como SVG (usando derivação textual → SVG manual)
    4. `validate_svg.py` no SVG
    5. Publicar como report HTML
    6. `consolidar-estado`
- [ ] Propagado para os 5 experimentos

---

### US-024: Skill template — {PREFIX}-prototipo

**Description:** Como um agente autônomo, eu preciso de prototipagem rápida para testar ideias concretas.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/prototipo/SKILL.md` com:
  - **Propósito**: Prototipagem rápida de ideias (HTML, scripts, mockups)
  - **Trigger**: Usuário (não despachado pelo heartbeat)
  - **Passos**:
    1. Definir escopo mínimo do protótipo (1 feature, 1 tela, 1 script)
    2. Implementar em `builds/` (diretório de artefatos construídos)
    3. Testar/validar
    4. Registrar em experiments.log se for um teste de hipótese
    5. Blog entry com protótipo e learnings
    6. `consolidar-estado`
- [ ] Propagado para os 5 experimentos

---

### US-025: Skill template — {PREFIX}-carregar

**Description:** Como um agente autônomo, eu preciso carregar contexto e estado no início de cada sessão interativa.

**Acceptance Criteria:**
- [ ] Criar `templates/skills-core/carregar/SKILL.md` com:
  - **Propósito**: Carregar contexto/estado para sessão interativa (não heartbeat)
  - **Trigger**: Início de sessão interativa com usuário
  - **Passos**:
    1. Ler `memory/rules-core.md` (obrigatório)
    2. Ler `memory/personality.md` (obrigatório)
    3. Ler `memory/debugging.md` (se sessão autônoma)
    4. Ler `autonomy/autonomy-policy.md` (obrigatório)
    5. `edge-digest` — briefing compactado
    6. Ler últimos 3 eventos
    7. Ler threads com resurface vencido
    8. Ler task ledger (doing + blocked)
    9. Listar claims abertas (gaps com `!`)
    10. Apresentar síntese ao usuário: "Aqui está o que está acontecendo..."
- [ ] Propagado para os 5 experimentos

---

### US-026: Operacionalizar claims system

**Description:** Como um agente autônomo, eu preciso que o sistema de claims funcione end-to-end para acumular conhecimento durável.

**Acceptance Criteria:**
- [ ] Verificar que `edge-claims` funciona com o diretório correto (blog/entries/ como fonte)
- [ ] Blog entries dos 5 agentes devem incluir campo `claims:` no frontmatter
- [ ] Claims com prefixo `!` representam gaps abertos
- [ ] `edge-claims --stats` retorna contagem > 0 após execução
- [ ] `edge-claims --open` lista gaps abertos
- [ ] `edge-claims --search "termo"` busca no corpus de claims
- [ ] Documentar formato de claims no `_shared/report-template.md`

---

### US-027: Operacionalizar threads system

**Description:** Como um agente autônomo, eu preciso de fios de investigação persistentes com resurface dates para não perder contexto.

**Acceptance Criteria:**
- [ ] Criar diretório `threads/` em cada agente
- [ ] Definir formato de thread: `threads/{thread-id}.md` com frontmatter:
  ```yaml
  ---
  id: thread-id
  title: "Título do fio"
  status: active|paused|closed
  created: "YYYY-MM-DD"
  resurface: "YYYY-MM-DD"
  related_claims: [claim-1, claim-2]
  ---
  Contexto e progresso do fio...
  ```
- [ ] `heartbeat-preflight.sh` verifica threads com resurface vencido e sinaliza PREFLIGHT_WORK
- [ ] Blog entries podem referenciar threads via campo `thread:` no frontmatter
- [ ] Skills atualizam threads quando produzem artefatos relacionados

---

### US-028: Operacionalizar event sourcing

**Description:** Como um agente autônomo, eu preciso de telemetria operacional via eventos estruturados.

**Acceptance Criteria:**
- [ ] Verificar que `edge-event` cria `events.jsonl` no diretório correto
- [ ] `consolidar-estado` registra evento em Phase 5
- [ ] `heartbeat-preflight.sh` lê últimos eventos para contexto
- [ ] `edge-event recent` retorna últimos N eventos
- [ ] `edge-event stats` retorna contagem por tipo
- [ ] Formato de evento:
  ```json
  {"timestamp":"ISO8601","type":"beat|publish|error|reflect|strategy","summary":"...","skill":"...","thread":"...","artifacts":["..."]}
  ```

---

### US-029: Operacionalizar state audit

**Description:** Como um agente autônomo, eu preciso que o ciclo snapshot PRE → edit → audit POST funcione.

**Acceptance Criteria:**
- [ ] `edge-state-audit snapshot --slug X` grava snapshot em `state-snapshots/`
- [ ] `edge-state-audit propose --slug X` gera proposta YAML de mudanças
- [ ] `edge-state-audit audit --slug X` compara PRE vs POST e reporta: ok, partial, divergência, violação
- [ ] `consolidar-estado` usa state-audit em Phase 0a e 5b
- [ ] Arquivos protegidos definidos em `_shared/state-protocol.md` disparam violação se alterados sem proposta

---

### US-030: Operacionalizar meta-reports e HTML reports

**Description:** Como um agente autônomo, eu preciso gerar meta-reports e relatórios HTML como parte do pipeline de publicação.

**Acceptance Criteria:**
- [ ] `edge-meta-report` gera output em `meta-reports/{slug}-meta.md`
- [ ] Meta-report contém: state delta (diff entre PRE e POST), notas do scratchpad, desafio adversarial
- [ ] `generate_report.py` gera HTML autocontido em `reports/`
- [ ] HTML inclui `tools/assets/base.css` inline e `tools/assets/logo.svg` inline
- [ ] `consolidar-estado` gera meta-report em Phase 4 e HTML report em Phase 2

---

### US-031: Implementar git structured commits

**Description:** Como um operador, eu preciso de commits com metadados parseáveis para análise posterior.

**Acceptance Criteria:**
- [ ] `consolidar-estado` Phase 6 gera commit com formato:
  ```
  beat({skill}): {título do blog entry}

  slug: {slug}
  skill: {skill}
  thread: {thread-id}
  claims: {N new, M gaps}
  artifacts: {lista de arquivos}
  quality-score: {score do review-gate}
  ---
  Co-Authored-By: Claude <noreply@anthropic.com>
  ```
- [ ] `git_signals.py` consegue parsear esse formato para extrair métricas
- [ ] Commits normais (fora do pipeline) continuam com formato livre

---

### US-032: Implementar plugin learning-output-style

**Description:** Como um agente autônomo, eu preciso de um hook SessionStart que ativa modo de aprendizado interativo.

**Acceptance Criteria:**
- [ ] Criar hook em `.claude/hooks/learning-output-style.sh` que:
  - Detecta início de sessão interativa (não heartbeat)
  - Injeta instruções para modo exploratório: mostrar raciocínio, gaps, conexões
  - Ativa tom Feynman (derivar antes de concluir)
- [ ] Registrar hook em `.claude/settings.json` como `SessionStart` hook
- [ ] Template em `templates/hooks/learning-output-style.sh.tpl`

---

### US-033: Implementar plugin security-guidance

**Description:** Como um operador, eu preciso de um hook que detecta padrões inseguros antes de escrever código.

**Acceptance Criteria:**
- [ ] Criar hook em `.claude/hooks/security-guidance.sh` que:
  - Intercepta `PreToolUse` para Edit e Write
  - Detecta padrões: API keys hardcoded, SQL injection, eval(), exec(), secrets em código
  - Retorna warning se padrão detectado
- [ ] Registrar hook em `.claude/settings.json`
- [ ] Template em `templates/hooks/security-guidance.sh.tpl`

---

### US-034: Implementar plugin feature-dev

**Description:** Como um desenvolvedor, eu preciso de um fluxo de 7 fases para desenvolvimento de features com sub-agentes.

**Acceptance Criteria:**
- [ ] Criar skill `templates/skills-core/feature-dev/SKILL.md` com 7 fases:
  1. Requirements (PRD)
  2. Architecture (code-architect sub-agent)
  3. Implementation
  4. Code review (code-reviewer sub-agent)
  5. Testing
  6. Documentation
  7. Deploy/merge
- [ ] Integrar com ralph.sh para execução autônoma de features medium/high complexity
- [ ] Propagado para os 5 experimentos

---

### US-035: Implementar plugin claude-md-management

**Description:** Como um agente autônomo, eu preciso de um comando /revise-claude-md para atualizar CLAUDE.md com learnings de forma controlada.

**Acceptance Criteria:**
- [ ] Criar skill `templates/skills-core/revise-claude-md/SKILL.md` com:
  - Ler CLAUDE.md atual
  - Identificar seções que precisam de update (baseado em reflexão)
  - Propor mudanças via `edge-state-audit propose`
  - `edge-consult` adversarial review das mudanças
  - Aplicar apenas se aprovado
  - Logar mudança em debugging.md
- [ ] Esta skill é a ÚNICA forma de atualizar CLAUDE.md
- [ ] Propagado para os 5 experimentos

---

### US-036: Implementar plugin pr-review-toolkit

**Description:** Como um desenvolvedor, eu preciso de um agente que audita error handling e detecta silent failures.

**Acceptance Criteria:**
- [ ] Criar skill `templates/skills-core/pr-review/SKILL.md` com:
  - Recebe diff ou PR como input
  - Analisa: error handling ausente, exceptions silenciosas, retornos não verificados
  - Gera relatório com findings categorizados (critical, warning, info)
  - Foca em silent failures: try/catch vazio, .catch(() => {}), error swallowed
- [ ] Propagado para os 5 experimentos

---

### US-037: Atualizar skill-steps-registry.yaml com todas as skills

**Description:** Como um agente autônomo, eu preciso que o registry de passos inclua todas as skills para que edge-skill-step detecte passos pulados.

**Acceptance Criteria:**
- [ ] Atualizar `tools/skill-steps-registry.yaml` com entries para TODAS as skills:
  - heartbeat (já existe)
  - pesquisa (já existe)
  - descoberta, lazer, reflexao, estrategia, planejar, executar
  - experimento, autonomia, curadoria-corpus
  - Cada entry com lista de steps (id + label)
- [ ] Propagado para os 5 experimentos

---

### US-038: Atualizar bootstrap-experiments.sh

**Description:** Como um operador, eu preciso que o bootstrap propague todos os novos artefatos para os 5 experimentos.

**Acceptance Criteria:**
- [ ] Bootstrap cria todos os novos diretórios (threads/, state/, etc.)
- [ ] Bootstrap copia todas as novas skills core para `.claude/skills/core/`
- [ ] Bootstrap copia `bin/consolidar-estado` e torna executável
- [ ] Bootstrap copia `blog/server.js` e `blog/package.json`
- [ ] Bootstrap copia `_shared/state-protocol.md` e `report-template.md`
- [ ] Bootstrap copia `autonomy/autonomy-policy.md`
- [ ] Bootstrap copia hooks (learning-output-style, security-guidance)
- [ ] Bootstrap copia `edge-search` e `edge-index`
- [ ] Bootstrap substitui placeholders em todos os novos templates
- [ ] Bootstrap roda `npm install` no blog/ de cada agente
- [ ] Após bootstrap, cada agente tem estrutura completa conforme blueprint

---

### US-039: Atualizar CLAUDE.md.tpl e MEMORY.md.tpl

**Description:** Como um agente autônomo, eu preciso que minhas instruções globais reflitam todos os novos componentes.

**Acceptance Criteria:**
- [ ] CLAUDE.md.tpl inclui:
  - Referência a `autonomy/autonomy-policy.md` em Required Reading
  - Lista completa de skills core (22 skills)
  - Referência a `consolidar-estado` como pipeline obrigatório
  - Referência a `edge-search` para busca interna
  - Referência a `_shared/state-protocol.md` e `report-template.md`
  - Pipeline consolidar-estado atualizado com todas as 8 fases
- [ ] MEMORY.md.tpl inclui:
  - Referência a autonomy-policy.md
  - Seção de skills atualizada
  - Seção de tools atualizada com edge-search/edge-index

---

### US-040: Atualizar install.sh

**Description:** Como um operador, eu preciso que o instalador interativo configure todos os novos componentes.

**Acceptance Criteria:**
- [ ] install.sh cria todos os diretórios estruturais
- [ ] install.sh instala dependências do blog server (`npm install` em blog/)
- [ ] install.sh configura e ativa blog-server.service via systemd/launchd
- [ ] install.sh inicializa `edge-index` no corpus inicial
- [ ] install.sh copia autonomy-policy.md
- [ ] install.sh registra hooks em settings.json
- [ ] install.sh verifica SQLite com FTS5 como pré-requisito

## Functional Requirements

- FR-1: Todos os templates de skills devem usar placeholders `{{PREFIX}}`, `{{WORK_DIR}}`, `{{AGENT_NAME}}`, `{{CODENAME}}` substituíveis pelo bootstrap/install
- FR-2: O blog server deve funcionar standalone com `node blog/server.js` sem dependências externas além de npm packages
- FR-3: O pipeline consolidar-estado deve ser idempotente — rodar duas vezes com o mesmo slug não duplica publicação
- FR-4: Todas as skills core devem terminar com `edge-skill-step end` para tracking de completude
- FR-5: O search system deve usar apenas SQLite FTS5 (sem dependências de embedding servers)
- FR-6: Hooks devem funcionar tanto em Linux quanto macOS
- FR-7: Todos os scripts em `bin/` devem ser POSIX-compatible (bash 4.0+)
- FR-8: O bootstrap deve ser re-executável (idempotente) — não destruir dados existentes nos experimentos

## Non-Goals

- Não implementar embedding/vector search (FTS5 é suficiente)
- Não implementar UI/frontend para o dashboard (dashboard.sh já existe)
- Não migrar de systemd para outra solução de scheduling
- Não refatorar ferramentas edge-* existentes que já funcionam
- Não implementar autenticação OAuth no blog (Basic Auth é suficiente)
- Não criar testes automatizados para skills (skills são prompts, não código)
- Não implementar multi-tenancy no blog server

## Technical Considerations

- O blog server Express.js precisa de Node.js >= 18 (já disponível para Claude Code)
- SQLite FTS5 é built-in no Python >= 3.10 (`sqlite3` module) — não precisa de extensão separada
- Os skills templates são arquivos .md puros — não são código executável, são prompts para o Claude Code
- `consolidar-estado` é o único script novo significativo (~300-500 linhas bash)
- Hooks do Claude Code são executáveis que recebem JSON via stdin e retornam JSON via stdout
- O bootstrap precisa ser cuidadoso para não sobrescrever `experiments.log`, `blog/entries/`, `memory/topics/` — dados existentes dos agentes

## Success Metrics

- 22/22 skills core existem como templates e estão propagadas nos 5 agentes
- `consolidar-estado` executa end-to-end sem erros em dry-run
- Blog server responde em todas as rotas documentadas
- `edge-search` retorna resultados do corpus local após indexação
- `edge-skill-step end` no heartbeat reporta 0 passos pulados
- Todos os 5 agentes têm diretórios estruturais completos
- `edge-state-lint` retorna 0 erros críticos em todos os agentes
- Bootstrap re-executado não destrói dados existentes

## Open Questions (Resolved)

1. **Blog server HTTPS?** → **HTTP local only.** Blog é interno; acesso externo é via Netlify (já tem HTTPS).
2. **Hooks: bloquear ou avisar?** → **Avisar por default, bloquear para patterns críticos.** API keys hardcoded → bloqueia (exit 1). Eval()/exec() → avisa (stderr warning). Evita falsos positivos travando o fluxo autônomo.
3. **consolidar-estado: bash ou Python?** → **Bash como orquestrador, delegando para Python** nas phases que já usam Python (review-gate.py, generate_report.py, edge-consult.py). Já é o padrão do repo.
4. **Threshold do review-gate?** → **3.5/5 para ambos** (negócio e pesquisa), como no blueprint original.
5. **Blog server compartilhado ou por agente?** → **Um server por agente** em portas diferentes (8766, 8767, 8768, 8769, 8770). Isolamento, simplicidade, alinhado com blog-server.service.tpl existente.
