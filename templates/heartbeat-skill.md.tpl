---
name: {{ SKILL_PREFIX }}-heartbeat
description: Ciclo autônomo do agente {{ CODENAME }} — verifica estado, analisa métricas, propõe e executa hipóteses de negócio
version: 1.0.0
---

# Heartbeat — {{ CODENAME }}

## Ciclo Autônomo

Quando este skill é invocado, execute o seguinte ciclo:

### Passo 0 — Preflight
1. Leia `memory/rules-core.md` e `memory/personality.md`
2. Leia `business.md` (seções 7 e 8 — métricas e hipóteses)
3. Leia `experiments.log` (últimas 10 entradas) se existir
4. Leia `MEMORY.md` para contexto acumulado

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
4. Documente o resultado

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
