# Agent Template — Agente Autônomo Claude Code

Template para criar agentes autônomos de IA baseados no Claude Code CLI.

## Instalação Rápida

```bash
# Clone e execute o instalador
git clone https://github.com/alexlopespereira/agent-template.git my-agent
cd my-agent && bash install.sh
```

Ou use como template do GitHub:
```bash
gh repo create my-agent --template alexlopespereira/agent-template --private
cd my-agent && bash install.sh
```

## O que o Instalador Faz

1. Coleta informações sobre o agente (nome, missão, domínio, APIs)
2. Substitui placeholders em todos os arquivos de configuração
3. Configura o ciclo autônomo de heartbeat (systemd/launchd/Task Scheduler)
4. Conecta a base de conhecimento do negócio
5. Executa o primeiro ciclo para validação

## Estrutura Após Instalação

```
your-repo/
├── CLAUDE.md           ← instruções do agente (personalizadas)
├── MEMORY.md           ← memória persistente (começa vazia)
├── heartbeat.sh        ← script de execução autônoma
├── kb.config           ← configuração da base de conhecimento
├── tools/              ← ferramentas CLI do agente
├── memory/             ← arquivos de memória estruturada
│   ├── rules-core.md   ← regras transversais (max 15)
│   ├── personality.md  ← perfil cognitivo
│   ├── metodo.md       ← método Feynman
│   ├── debugging.md    ← log de erros
│   └── topics/         ← clusters temáticos de conhecimento
├── blog/entries/       ← entradas do blog do agente
├── reports/            ← relatórios HTML
├── logs/               ← logs de execução
├── secrets/            ← chaves de API (gitignored)
└── systemd/            ← units systemd (Linux)
```

## Pré-requisitos

- **Claude Code**: `npm install -g @anthropic-ai/claude-code`
- **GitHub CLI**: `gh auth login`
- **Python 3.10+** com pip e venv
- **ANTHROPIC_API_KEY** configurada
- **OPENAI_API_KEY** para revisão adversarial (review-gate, edge-consult)

## Conceitos-Chave

### Heartbeat

O heartbeat é o ciclo autônomo do agente. Ele é acionado por um timer (systemd no Linux, launchd no macOS) em intervalo configurável e executa a seguinte sequência:

```
┌─────────────────────────────────────────────────────────────┐
│                    CICLO DO HEARTBEAT                        │
│                                                             │
│  1. Lock — impede ciclos sobrepostos                        │
│  2. Secrets — carrega .env do diretório secrets/            │
│  3. Human Gate — verifica se o humano respondeu ao ciclo    │
│     anterior; se não, pula este beat                        │
│  4. Preflight — checagem determinística em bash (~3s,       │
│     zero tokens): detecta sinais de trabalho pendente       │
│     (mensagens, threads, erros, insights, sessões)          │
│  5. Skill Heartbeat — invoca Claude (max 30 turns) que      │
│     executa as fases abaixo                                 │
│  6. Human Gate — gera relatório e bloqueia próximo beat     │
│     até o humano responder (Telegram ou blog chat)          │
│  7. Cleanup — remove temporários, atualiza RAG              │
└─────────────────────────────────────────────────────────────┘
```

**Fases da skill heartbeat (executadas pelo LLM):**

| Fase | O que faz |
|------|-----------|
| **0 — Preflight** | Carrega regras, personalidade, métricas de negócio, hipóteses e memória acumulada |
| **0.5 — Resolve Blockers** | Tenta resolver bloqueios com ações pré-autorizadas (deploys, config, pacotes). Escala ao humano se exigir conta nova, pagamento ou decisão legal |
| **0.7 — Gap Analysis** | Compara estado atual contra o playbook de negócios, identifica gaps estratégicos, gera novas hipóteses, usa `edge-deepresearch` para dados externos |
| **1 — Diagnóstico** | Avalia métricas, identifica hipótese de maior impacto, audita assets existentes (LP, emails, copy) para inconsistências |
| **2 — Execução** | Escolhe UMA hipótese, define métrica-alvo, executa (pesquisa, criação de conteúdo, análise). Tarefas simples (≤3 arquivos) são feitas direto; complexas são delegadas ao Ralph |
| **3 — Registro** | Registra resultado em `experiments.log` (JSONL) com timestamp, hipótese, delta métrico, ação (KEEP/REVERT) |
| **4 — Planejamento** | Define o que fazer no próximo beat e registra em `MEMORY.md` |
| **5 — Relatório** | Gera resumo estruturado (o que fez, estado atual, aprovações pendentes, próximos passos), salva como `human-gate-summary.json` e envia via Telegram |

**Controles de custo e segurança:**
- Preflight é bash puro (zero tokens de LLM)
- Skill usa Claude Sonnet com máximo de 30 turns e limite de $2/ciclo
- Lock file previne ciclos sobrepostos
- Human gate garante que o agente nunca roda dois ciclos sem supervisão humana
- Timeout de 45 minutos no systemd

### Revisão Adversarial
O agente nunca avalia seu próprio output. Antes de publicar, submete conclusões a um modelo diferente (GPT) via `edge-consult` para revisão adversarial. Isso cria um loop de checks-and-balances.

### Clusters de Conhecimento
Conhecimento persistente organizado como texto que muda comportamento. Regras em `rules-core.md`, clusters temáticos em `memory/topics/`. O teste: "se eu deletar este arquivo e o comportamento não mudar, era lixo."

### Pipeline (consolidar-estado)
Pipeline de publicação atômica de 8 fases: snapshot de estado, revisão adversarial, quality gate, publicação no blog, relatório HTML, meta-relatório, commit de estado, commit git estruturado.

<!-- AGENT-TEMPLATE-START -->
## Catálogo de Skills & Ferramentas

### Skills de Marketing (33)

| Skill | Descrição |
|-------|-----------|
| **ab-test-setup** | Planejamento, design e implementação de testes A/B com rigor estatístico |
| **ad-creative** | Geração e iteração de criativos de anúncio (headlines, descrições) para plataformas de mídia paga |
| **ai-seo** | Otimização de conteúdo para motores de busca IA (ChatGPT, Perplexity, Google AI Overviews) |
| **analytics-tracking** | Setup, melhoria e auditoria de tracking analítico (GA4, GTM, eventos, UTM) |
| **churn-prevention** | Redução de churn via cancel flows, save offers, recuperação de pagamento e retenção |
| **cold-email** | Escrita de cold emails B2B e sequências de follow-up que geram respostas |
| **competitor-alternatives** | Criação de páginas de comparação com concorrentes e alternativas para SEO e sales |
| **content-strategy** | Planejamento de estratégia de conteúdo, identificação de tópicos, pilares e clusters |
| **copy-editing** | Edição, revisão e melhoria de copy de marketing existente |
| **copywriting** | Escrita de copy de marketing para páginas — clara, persuasiva e orientada à ação |
| **email-sequence** | Criação e otimização de sequências de email, drip campaigns e programas de lifecycle |
| **form-cro** | Otimização de formulários não-signup (lead capture, contato, demo request) |
| **free-tool-strategy** | Planejamento e construção de ferramentas gratuitas para geração de leads e SEO |
| **launch-strategy** | Planejamento de lançamentos de produto, anúncios de features e estratégias go-to-market |
| **lead-magnets** | Criação e otimização de conteúdo gated para captura de emails e geração de leads |
| **marketing-ideas** | Brainstorm e recomendação de estratégias de marketing a partir de 139 táticas comprovadas |
| **marketing-psychology** | Aplicação de princípios psicológicos e modelos mentais ao marketing |
| **onboarding-cro** | Otimização de onboarding pós-signup, ativação de usuários e time-to-value |
| **page-cro** | Otimização de páginas de marketing para conversão (homepage, landing, pricing, feature) |
| **paid-ads** | Criação e otimização de campanhas de mídia paga (Google, Meta, LinkedIn) |
| **paywall-upgrade-cro** | Criação e otimização de paywalls in-app, telas de upgrade e upsell modals |
| **popup-cro** | Criação e otimização de popups, modais e overlays para conversão |
| **pricing-strategy** | Design de pricing, tiers e estratégia de monetização alinhada ao willingness-to-pay |
| **product-marketing-context** | Criação de documento base de posicionamento e messaging usado por todas as skills |
| **programmatic-seo** | Construção de páginas SEO em escala usando templates e dados estruturados |
| **referral-program** | Criação e otimização de programas de indicação, afiliados e word-of-mouth |
| **revops** | Design de revenue operations (lead lifecycle, scoring, routing, pipeline management) |
| **sales-enablement** | Criação de material de vendas (decks, one-pagers, objection docs, demo scripts) |
| **schema-markup** | Adição e otimização de schema markup e dados estruturados (JSON-LD, rich snippets) |
| **seo-audit** | Auditoria e diagnóstico de problemas de SEO técnico e on-page |
| **signup-flow-cro** | Otimização de fluxos de signup, registro e criação de conta |
| **site-architecture** | Planejamento de hierarquia de páginas, navegação, URL structure e internal linking |
| **social-content** | Criação e otimização de conteúdo para redes sociais (LinkedIn, X, Instagram, TikTok) |

### Skills de Operações (6)

| Skill | Descrição |
|-------|-----------|
| **deep-research** | Pesquisa profunda com validação adversarial cruzada via OpenAI e Gemini (até 5 iterações de refinamento) |
| **dns-config** | Configuração de DNS no registro.br via Playwright (A, CNAME, MX, TXT, verificação de propagação) |
| **domain-registration** | Pesquisa e registro de domínios no registro.br via Playwright (preferência .ia.br) |
| **netlify-deploy** | Deploy de landing pages na Netlify via Playwright (criação de site, upload, domínio customizado, SSL) |
| **prd** | Geração de Product Requirements Documents (PRDs) para novas features |
| **ralph** | Conversão de PRDs para formato prd.json do sistema autônomo Ralph |

### Ferramentas (tools/)

#### Pesquisa e Validação

| Ferramenta | Descrição |
|------------|-----------|
| `edge-deepresearch.py` | Pesquisa profunda via OpenAI + Gemini com web search |
| `edge-adversarial-research.py` | Validação adversarial cruzada entre provedores (até 5 iterações de convergência) |
| `edge-consult.py` | Deliberação cross-model Claude vs GPT para revisão adversarial |
| `edge-fontes` | Busca unificada de fontes externas |
| `edge-hn` | Busca inteligente no Hacker News via Algolia |
| `edge-x` | Busca no X/Twitter por insights de praticantes |
| `edge-claims` | Extração e listagem de claims para verificação |

#### Estado e Observabilidade

| Ferramenta | Descrição |
|------------|-----------|
| `edge-event` | Log e consulta de eventos de estado |
| `edge-ledger` | Telemetria operacional (registro e consulta de métricas) |
| `edge-state-audit` | Snapshot e auditoria de mudanças de estado (before/after) |
| `edge-state-lint` | Linter de consistência de estado |
| `edge-skill-step` | Rastreamento de execução de steps de skills |
| `edge-scratch` | Scratchpad de sessão para observações temporárias |
| `edge-digest` | Geração de briefing.md a partir de dados estruturados |

#### Publicação e Relatórios

| Ferramenta | Descrição |
|------------|-----------|
| `review-gate.py` | Quality gate automático para specs YAML (47KB de regras) |
| `edge-meta-report` | Geração de meta-relatórios analíticos |
| `generate_report.py` | Geração de relatórios HTML |
| `yaml_to_html.py` | Conversão de YAML para HTML com templates |
| `validate_svg.py` | Validação de SVG embutido em relatórios HTML |

#### Integração e Utilitários

| Ferramenta | Descrição |
|------------|-----------|
| `edge-task` | Gerenciamento de tarefas event-sourced |
| `edge-dialogue.py` | Diálogo multi-turno com GPT via Responses API |
| `stripe_helper.py` | Wrapper Stripe com metadata por business |
| `heartbeat-preflight.sh` | Checagem determinística antes de invocar LLM |
| `git_signals.py` | Sinais estruturados extraídos do git log |
| `curadoria_compute.py` | Motor de curadoria e scoring de corpus |
| `feedback.sh` | Coleta de feedback humano via blog chat |
| `ledger_rollup.py` | Agregação de ledger em ops-hotspots.json |

#### Ralph — Loop de Desenvolvimento Autônomo

| Ferramenta | Descrição |
|------------|-----------|
| `ralph/ralph.sh` | Orquestrador do loop autônomo de desenvolvimento |
| `ralph/CLAUDE.md` | Instruções do agente Ralph |
| `ralph/prompt.md` | Prompt template para iterações |
| `ralph/prd.json.example` | Exemplo de PRD no formato JSON |
<!-- AGENT-TEMPLATE-END -->

## Documentação

Veja [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md) para o guia detalhado de setup e operação.

## Arquitetura

Veja [REPLICATION_BLUEPRINT.md](REPLICATION_BLUEPRINT.md) para o blueprint arquitetural completo.
