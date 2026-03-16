# ANALYZE_ARTIFACTS.md — Sub-Prompt de Análise de Artefatos

> **Objetivo:** Ler artefatos de um diretório fornecido pelo humano,
> sintetizar as informações e gerar um `business.md` completo seguindo
> o schema canônico em `docs/business.template.md`.
>
> **Variáveis de ambiente esperadas:**
>   - `ARTIFACTS_DIR` — caminho absoluto do diretório com artefatos
>   - `SLUG` — slug do experimento (snake_case)
>   - `OUTPUT_FILE` — caminho do business.md de saída
>
> **Execução:**
> ```bash
> ARTIFACTS_DIR="/path/to/dir" SLUG="meu_negocio" OUTPUT_FILE="experiments/meu_negocio/business.md" \
>   claude --dangerously-skip-permissions -p "$(cat ANALYZE_ARTIFACTS.md)"
> ```

---

## FASE 1 — Inventário do Diretório

```bash
ARTIFACTS_DIR="${ARTIFACTS_DIR:?Defina ARTIFACTS_DIR}"
SLUG="${SLUG:?Defina SLUG}"
OUTPUT_FILE="${OUTPUT_FILE:-experiments/$SLUG/business.md}"

echo "━━━  Inventário de artefatos  ━━━"
echo "Diretório: $ARTIFACTS_DIR"
echo ""

# Listar arquivos com tipo e tamanho
find "$ARTIFACTS_DIR" -type f ! -path '*/.git/*' ! -name '.DS_Store' \
  -exec sh -c 'for f; do
    size=$(du -h "$f" 2>/dev/null | cut -f1)
    ext="${f##*.}"
    echo "  $size  [$ext]  $f"
  done' _ {} + | sort -k3

echo ""
TOTAL=$(find "$ARTIFACTS_DIR" -type f ! -path '*/.git/*' ! -name '.DS_Store' | wc -l | tr -d ' ')
TOTAL_SIZE=$(du -sh "$ARTIFACTS_DIR" 2>/dev/null | cut -f1)
echo "Total: $TOTAL arquivos, $TOTAL_SIZE"
```

### Priorização de Leitura

Classifique os arquivos em duas prioridades:

**P1 — Ler primeiro** (alta densidade de informação):
- `.md`, `.txt`, `.yaml`, `.yml`, `.json` (config/manifest)
- `README*`, `pitch*`, `business*`, `canvas*`, `plan*`
- Primeiros 2 PDFs por tamanho (menores primeiro)
- `.html` de landing pages

**P2 — Ler se necessário** (contexto complementar):
- Planilhas (`.xlsx`, `.csv`) — ler apenas headers + primeiras 10 linhas
- PDFs grandes (>5MB) — ler apenas primeiras 5 páginas
- Imagens — ignorar (não extrair OCR)
- Código fonte — ler apenas `package.json`, `requirements.txt`, `Dockerfile`

**Ignorar:**
- `node_modules/`, `venv/`, `.git/`, `__pycache__/`
- Binários (`.zip`, `.tar`, `.exe`, `.dmg`)
- Mídia (`.mp4`, `.mp3`, `.mov`, `.wav`)

---

## FASE 2 — Leitura e Extração

Para cada arquivo P1, leia o conteúdo e extraia informações relevantes para as
10 seções do schema `docs/business.template.md`:

1. **Identidade** — nome, tagline, descrição, problema, público, diferencial
2. **Mercado** — setor, geografia, tamanho, concorrentes
3. **Modelo de Negócio** — tipo, preço, planos, trial
4. **Produto / MVP** — funcionalidades, status
5. **Canais de Aquisição** — quais canais mencionados
6. **Pagamentos** — processador, moeda, budget
7. **Stack Técnico** — tecnologias mencionadas
8. **Equipe** — fundadores, papel do agente
9. **Cronograma** — prazos, marcos
10. **Notas** — contexto adicional

Para cada trecho relevante encontrado, anote:
- Seção de destino (1-10)
- Conteúdo extraído
- Fonte (nome do arquivo)

Se um arquivo P1 não contiver informações relevantes, registre e avance.

Após todos os P1, avalie quais seções ainda têm menos de 50% dos campos.
Se P2 pode ajudar, leia os P2 relevantes. Caso contrário, pule.

---

## FASE 3 — Síntese e Geração

Com todas as informações extraídas, gere o `business.md` seguindo estas regras:

### Regras de Preenchimento

1. **Campos com informação encontrada** → preencher com o conteúdo extraído.
   Se houver informações conflitantes entre artefatos, usar a mais recente
   ou a mais detalhada, e anotar a ambiguidade em "Notas".

2. **Campos inferíveis** → preencher com inferência razoável, marcando com
   `(inferido de: <arquivo>)` ao final. Exemplos:
   - Se o pitch menciona "Instagram Ads", marcar `[x] Meta Ads` na seção 5
   - Se o código tem `package.json` com Stripe, marcar `[x] Stripe` na seção 6

3. **Campos não encontrados (obrigatórios)** → marcar como `[NÃO ENCONTRADO — preencher]`

4. **Campos não encontrados (opcionais)** → marcar como `[não definido — ajustar depois]`

5. **Seção 5 (Canais)** — usar `[x]` e `[ ]` exatamente como no template.
   Cada `[x]` dispara inferência de contas no Passo 2 do Prompt D.

6. **Seção 7 (Stack)** — usar `[x]` e `[ ]` exatamente como no template.
   Cada `[x]` dispara credenciais no secrets.yaml.

### Perguntas de Clarificação (Fase 3b)

Após gerar o rascunho, identifique os campos **obrigatórios** que ficaram como
`[NÃO ENCONTRADO — preencher]`. Para cada um, formule uma pergunta direta ao humano.

Agrupe as perguntas e apresente de uma vez:

```
━━━  Campos pendentes — preciso da sua ajuda  ━━━

Os artefatos fornecidos cobriram X de Y campos. Faltam:

1. [Seção 1] Qual é o público-alvo principal?
2. [Seção 3] Qual é o preço do produto?
3. [Seção 6] Qual processador de pagamento será usado?

Responda inline (1. resposta, 2. resposta, ...) ou digite "pular" para
deixar como pendente.
```

Incorporar as respostas no business.md.

---

## FASE 4 — Salvar e Validar

```bash
# Salvar o business.md gerado
cat > "$OUTPUT_FILE" << 'BIZEOF'
[conteúdo gerado na Fase 3]
BIZEOF

echo "✓ business.md gerado: $(wc -l < "$OUTPUT_FILE") linhas"

# Contagem de campos pendentes
PENDING=$(grep -c 'NÃO ENCONTRADO\|PREENCHER' "$OUTPUT_FILE" 2>/dev/null || echo 0)
OPTIONAL=$(grep -c 'não definido' "$OUTPUT_FILE" 2>/dev/null || echo 0)
FILLED=$(grep -cE '^\- \*\*.*\*\*: [^\[]' "$OUTPUT_FILE" 2>/dev/null || echo 0)

echo ""
echo "  Campos preenchidos:       $FILLED"
echo "  Campos pendentes (req.):  $PENDING"
echo "  Campos opcionais vazios:  $OPTIONAL"
echo ""

# Verificar campos críticos para inferência
echo "  Campos críticos para inferência de contas:"
for pattern in "\[x\]" "Tipo:" "Hospedagem:" "Processador:"; do
  if grep -q "$pattern" "$OUTPUT_FILE" 2>/dev/null; then
    echo "    ✓ $pattern encontrado"
  else
    echo "    ⚠ $pattern não encontrado"
  fi
done
```

---

## RESUMO DE FONTES

Ao final, apresente um resumo das fontes usadas:

```
━━━  Fontes consultadas  ━━━

  Arquivo                      Seções alimentadas
  ─────────────────────────────────────────────────
  pitch-deck.pdf               1, 2, 3, 4, 8
  landing-page.html            1, 5, 7
  config.yaml                  7
  notas-reuniao.md             3, 6, 9

  Não lidos (P2 desnecessários): planilha-metricas.xlsx, mockup.png
```
