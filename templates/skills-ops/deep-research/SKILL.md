---
name: deep-research
description: Pesquisa profunda com validação adversarial cruzada. Usa OpenAI (web_search) e Gemini (google_search) para pesquisar um tópico, depois executa até 5 iterações de refinamento adversarial até que ambos os provedores concordem (agreement >= 8/10) que o relatório está correto. Use quando o negócio precisa de dados de mercado, análise competitiva, validação de hipóteses, ou qualquer pesquisa que exija alta confiabilidade.
metadata:
  version: 1.0.0
  tools_required:
    - edge-deepresearch.py
    - edge-adversarial-research.py
  api_keys_required:
    - OPENAI_API_KEY
    - GEMINI_API_KEY
---

# Deep Research com Validação Adversarial

Pesquisa profunda e validada por dois provedores independentes (OpenAI + Gemini),
com iterações de refinamento até convergência.

## Quando usar

- Pesquisa de mercado (TAM, SAM, SOM)
- Análise competitiva
- Validação de hipóteses de negócio
- Due diligence sobre fornecedores, parceiros ou tecnologias
- Qualquer pesquisa onde dados incorretos teriam impacto significativo

## Processo

### Passo 1 — Definir escopo da pesquisa

Antes de pesquisar, defina claramente:
1. **Pergunta principal** — o que exatamente precisa ser respondido?
2. **Sub-perguntas** — quais aspectos específicos importam?
3. **Critérios de qualidade** — o que torna a pesquisa "boa o suficiente"?
4. **Contexto** — que informações do business.md são relevantes?

Salve o escopo em um arquivo temporário para referência:
```bash
cat > /tmp/research_scope.md << 'EOF'
# Escopo da Pesquisa
Pergunta: ...
Sub-perguntas: ...
Contexto relevante: ...
EOF
```

### Passo 2 — Pesquisa profunda inicial

Execute a pesquisa usando ambos os provedores:

```bash
edge-deepresearch "PERGUNTA AQUI" \
  --depth comprehensive \
  --context business.md /tmp/research_scope.md \
  > /tmp/research_initial.md
```

Parâmetros:
- `--depth quick` — para perguntas simples (3-5 fontes)
- `--depth comprehensive` — para pesquisa detalhada (multi-ângulo, 10+ fontes)
- `--provider openai` ou `--provider gemini` — se quiser um provider específico
- `--context` — arquivos de contexto (business.md, specs, etc.)

### Passo 3 — Validação adversarial com convergência

Submeta o resultado para validação adversarial iterativa:

```bash
edge-adversarial-research \
  --claim-file /tmp/research_initial.md \
  --source openai \
  --mode converge \
  --max-rounds 5 \
  --threshold 8 \
  > /tmp/research_validated.md
```

O modo `converge`:
1. **Gemini critica** o relatório do OpenAI (busca contra-evidências)
2. Se agreement < 8/10 → **OpenAI refina** endereçando as críticas
3. **Gemini re-avalia** a versão refinada
4. Repete até agreement >= 8/10 ou 5 iterações

Se `--source gemini`, os papéis se invertem (OpenAI valida Gemini).

### Passo 4 — Verificar convergência

Leia o output e verifique:
- **Converged: true** → ambos provedores concordam, relatório confiável
- **Converged: false** → ainda há divergências após max rounds
  - Neste caso, leia as issues restantes e documente como caveats

### Passo 5 — Integrar no business.md

Com o relatório validado:
1. Extraia dados relevantes para business.md (seções 2, 4, 7, 8)
2. Cite as fontes no texto
3. Registre a pesquisa em experiments.log:
   ```json
   {"timestamp": "...", "hypothesis": "deep-research: [tema]", "result": "converged: true/false, agreement: X/10", "metric_delta": null, "action": {"type": "KEEP"}, "ethical_check": {"status": "PASSED"}}
   ```

## Modos alternativos

### Counter-evidence (rápido, 1 round)
```bash
edge-adversarial-research --claim "afirmação" --source openai --mode counter-evidence
```

### Full tribunal (3 rounds: acusação → defesa → veredicto)
```bash
edge-adversarial-research --claim-file report.md --source openai --mode full-tribunal
```

### Cross-validation (ambos provedores como validadores)
```bash
edge-adversarial-research --claim-file report.md --source both --mode counter-evidence
```

## Custos estimados

| Operação | Custo aproximado |
|----------|-----------------|
| Deep research (quick, both) | $0.01 - $0.05 |
| Deep research (comprehensive, both) | $0.05 - $0.20 |
| Adversarial converge (3 rounds) | $0.10 - $0.40 |
| Adversarial converge (5 rounds) | $0.15 - $0.60 |
| Full tribunal | $0.10 - $0.30 |

Total para pesquisa completa validada: **$0.20 - $0.80** (dentro do limite de $2/ciclo).

## Restrições

- Máximo 5 iterações de convergência (configurável via `--max-rounds`)
- Threshold de convergência: 8/10 (configurável via `--threshold`)
- Contexto máximo por provider: 12K chars (truncado automaticamente)
- Logs salvos em `~/edge/logs/deepresearch/` e `~/edge/logs/adversarial-research/`
- **Nunca publique dados de pesquisa sem passar pelo pipeline de convergência adversarial**
