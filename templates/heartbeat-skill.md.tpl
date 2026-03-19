---
name: {{ SKILL_PREFIX }}-heartbeat
description: Ciclo autônomo do agente {{ CODENAME }} — verifica estado, analisa métricas, propõe e executa hipóteses de negócio
version: 1.0.0
---

# Heartbeat — {{ CODENAME }}

## Prompt

Verifique o estado do negócio {{ CODENAME }}. Consulte o playbook de negócios para identificar gaps estratégicos. Analise métricas atuais. Proponha e execute a ação de maior impacto — seja uma hipótese existente ou um gap identificado no playbook. Registre resultados no experiments.log.

## Ciclo Autônomo

Quando este skill é invocado, execute o seguinte ciclo:

### Passo 0 — Preflight
1. Leia `memory/rules-core.md` e `memory/personality.md`
2. Leia `business.md` (seções 7 e 8 — métricas e hipóteses)
3. Leia `experiments.log` (últimas 10 entradas) se existir
4. Leia `MEMORY.md` para contexto acumulado

### Passo 0.5 — Resolver Bloqueadores
1. Leia `blocked.log` — se existirem bloqueadores abertos, tente resolvê-los ANTES de propor novas hipóteses
2. Para cada bloqueador, avalie: posso resolver usando ações pré-autorizadas? (deploy gratuito com tokens de `secrets/`, instalar pacotes apt, configurar env vars de `secrets/`, subir serviços locais)
3. Se resolveu: registre em `experiments.log` com `"action": {"type": "KEEP"}` e notifique via `notify.sh --level success`
4. Se genuinamente precisa de humano (conta nova, pagamento, decisão legal): mantenha o bloqueio e siga para o Passo 1

### Passo 0.7 — Análise Estratégica (Gap Analysis)
1. Leia `memory/topics/playbook-negocios.md`
2. Compare o estado atual do negócio contra o playbook:
   - Em que fase o negócio está?
   - Quais itens da fase atual e da próxima estão incompletos?
   - Algum item incompleto é bloqueador para progresso?
3. Se identificar gaps críticos que não estão cobertos pelas hipóteses da seção 8:
   - Gere novas hipóteses e adicione à seção 8 do business.md
   - Priorize pela fórmula: impacto × urgência / custo
4. **Deep research (quando aplicável):** Se o gap exige dados externos que o agente não possui (TAM/SAM/SOM, análise competitiva, validação de demanda, pricing de mercado, benchmarks do setor):
   - Execute `edge-deepresearch "pergunta" --depth quick --context business.md` para obter dados fundamentados
   - Use `--depth comprehensive` somente se o gap for crítico e bloqueador
   - Integre os dados obtidos no business.md antes de gerar hipóteses
5. Se o gap requer ação humana (registrar domínio, criar conta, pagar):
   - Prepare tudo o que puder autonomamente (pesquisa de disponibilidade, comparação de preços, justificativa)
   - Notifique via `notify.sh --level blocked` com toda a informação necessária para o humano decidir em 30 segundos
6. Para cada gap identificado, verifique se existe uma skill de marketing aplicável em `.claude/skills/marketing/`. Se existir, invoque-a como parte da execução.

### Passo 1 — Diagnóstico
1. Avalie o estado atual das métricas (seção 7 do business.md)
2. Identifique a hipótese de maior impacto/custo da seção 8
3. Se não há hipóteses abertas, proponha uma nova baseada nos dados
4. Audite assets customer-facing (LP, emails, copy):
   - Consistência com business.md Seção 12 (tom, cores, voz)
   - Zero placeholders/lorem ipsum em assets deployados
   - Trust signals presentes se aceitando pagamentos
   - Social proof real (ou ausente, nunca fabricado)
   Se encontrar problemas, priorize corrigi-los ANTES de novas hipóteses.

### Passo 2 — Execução
1. Escolha UMA hipótese para testar neste ciclo
2. Defina: métrica alvo, valor esperado, método de teste
3. Execute as ações necessárias (pesquisa, análise, criação de conteúdo)
4. **Se a hipótese depende de dados factuais** (ex: "mercado X tem tamanho Y", "concorrente Z cobra W"):
   - Execute deep research com validação adversarial:
     ```bash
     edge-deepresearch "pergunta" --depth comprehensive --context business.md > /tmp/research.md
     edge-adversarial-research --claim-file /tmp/research.md --source openai --mode converge --max-rounds 5
     ```
   - Só considere dados como validados se convergiu (agreement >= 8/10)
   - Se não convergiu, documente as divergências como caveats na hipótese
5. Documente o resultado

### Passo 3 — Registro
1. Registre o resultado em `experiments.log` como JSONL:
   ```json
   {"timestamp": "ISO8601", "hypothesis": "...", "result": "...", "metric_delta": 0.0, "action": {"type": "KEEP|REVERT"}, "ethical_check": {"status": "PASSED"}}
   ```
2. Atualize `business.md` seção 9 (experimentos concluídos) se aplicável
3. Atualize `MEMORY.md` com aprendizados

### Passo 4 — Próximo ciclo
1. Identifique o que fazer no próximo heartbeat
2. Registre em `MEMORY.md` seção "Tasks in Progress"

## Domínio
{{ AGENT_DOMAIN }}

## Missão
{{ AGENT_MISSION }}

## Restrições
- Nunca viole os princípios da seção 10 do business.md
- Nunca modifique seções marcadas como imutáveis (1, 2)
- Registre TUDO no experiments.log — sem ação silenciosa
- Custo máximo por ciclo: $2 em tokens

## Quando usar Deep Research no heartbeat

| Situação | Ferramenta | Depth |
|----------|-----------|-------|
| Gap analysis precisa de dados de mercado (TAM, concorrentes, demanda) | `edge-deepresearch --depth quick` | quick |
| Hipótese depende de dados factuais que precisam de alta confiabilidade | `edge-deepresearch --depth comprehensive` + `edge-adversarial-research --mode converge` | comprehensive |
| Validar claim específico antes de publicar ou tomar decisão | `edge-adversarial-research --mode counter-evidence` | — |
| Pesquisa de pricing, benchmarks, ou due diligence | `edge-deepresearch --depth comprehensive` + `edge-adversarial-research --mode converge` | comprehensive |

**NÃO usar deep research quando:**
- A informação já está no business.md ou em experiments anteriores
- A ação é operacional (deploy, config, criar LP) — não precisa de pesquisa externa
- O ciclo já consumiu > $1 em tokens (reservar budget para o resto do heartbeat)
- A pergunta pode ser respondida com `edge-fontes` (busca rápida sem LLM)
