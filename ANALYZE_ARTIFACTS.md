# ANALYZE_ARTIFACTS — Sub-Prompt: Gerar business.md a partir de Artefatos

> **Quando é chamado:** Pelo Prompt D (pré-instalação), modo B, quando o usuário aponta
> um diretório contendo artefatos do negócio em vez de colar texto.
>
> **Inputs:**
>   - `$ARTIFACTS_DIR` — caminho do diretório com os artefatos
>   - `$SLUG`          — slug do experimento (snake_case)
>   - `$OUTPUT_FILE`   — caminho de saída (experiments/$SLUG/business.md)
>
> **Output:** `experiments/$SLUG/business.md` preenchido com o schema canônico,
> seguido de uma lista de campos que ficaram em branco e precisam de complemento humano.
>
> **Como rodar (chamado pelo Prompt D, não diretamente):**
> ```bash
> ARTIFACTS_DIR="/caminho/para/artefatos" \
> SLUG="meu_negocio" \
> OUTPUT_FILE="experiments/meu_negocio/business.md" \
> claude --dangerously-skip-permissions -p "$(cat ANALYZE_ARTIFACTS.md)"
> ```

---

## FASE 0 — Inventário do Diretório

```bash
echo "=== INVENTÁRIO: $ARTIFACTS_DIR ==="

# Listar todos os arquivos com tamanho e tipo
find "$ARTIFACTS_DIR" -type f \
  ! -path '*/.git/*' \
  ! -path '*/node_modules/*' \
  ! -name '.DS_Store' \
  ! -name 'Thumbs.db' \
  -exec ls -lh {} \; 2>/dev/null | \
  awk '{print $5, $9}' | sort -rh

echo ""
echo "=== TOTAL DE ARQUIVOS ==="
find "$ARTIFACTS_DIR" -type f ! -path '*/.git/*' | wc -l

echo ""
echo "=== EXTENSÕES ENCONTRADAS ==="
find "$ARTIFACTS_DIR" -type f ! -path '*/.git/*' | \
  sed 's/.*\.//' | sort | uniq -c | sort -rn
```

Com base no inventário, classifique cada arquivo em uma das categorias abaixo
e monte um **plano de leitura priorizado** antes de ler qualquer conteúdo:

### Categorias de Prioridade

| Prioridade | Tipo de arquivo | Por que importa |
|---|---|---|
| P1 — Ler completo | pitch deck (.pdf, .pptx), one-pager, landing page (.html, .md), README, proposta | Visão completa do negócio |
| P1 — Ler completo | business plan, modelo de negócio, canvas | Estrutura completa |
| P2 — Ler primeiros 100 linhas | planilhas financeiras (.xlsx, .csv), projeções | Preços, CAC, LTV, MRR |
| P2 — Ler primeiros 100 linhas | briefing de marketing, copy de anúncios | Canais, público, proposta de valor |
| P3 — Extrair metadados | apresentações grandes (>5MB), vídeos, imagens | Nome, logo, cores apenas |
| P4 — Ignorar | arquivos de sistema, binários, código-fonte sem doc | Ruído |

Apresente o plano ao humano:
```
Encontrei N arquivos em $ARTIFACTS_DIR.
Plano de leitura:

  P1 (leitura completa):
    - arquivo1.pdf (2.3MB) — pitch deck
    - README.md (8KB) — descrição do produto

  P2 (leitura parcial):
    - projecoes.xlsx (450KB) — dados financeiros
    - copy_ads.txt (12KB) — textos de campanha

  P3 (metadados):
    - demo_video.mp4 (45MB) — extraindo apenas nome e duração

  P4 (ignorando):
    - .env, node_modules/, etc.

Estimativa: ~3 minutos de análise.
Posso prosseguir? [s/n]
```

---

## FASE 1 — Leitura dos Artefatos P1

Para cada arquivo P1, leia o conteúdo usando a estratégia adequada ao tipo:

### PDFs e Apresentações
```bash
# Tentar extração de texto nativa
if command -v pdftotext &>/dev/null; then
  pdftotext "$ARQUIVO" - 2>/dev/null | head -500
elif command -v python3 &>/dev/null; then
  python3 -c "
import sys
try:
    import PyPDF2
    with open('$ARQUIVO', 'rb') as f:
        r = PyPDF2.PdfReader(f)
        for page in r.pages[:15]:  # primeiras 15 páginas
            print(page.extract_text() or '')
except ImportError:
    print('[PyPDF2 não instalado — instalar: pip install PyPDF2]')
except Exception as e:
    print(f'[Erro: {e}]')
"
fi
```

Se a extração de texto falhar em um PDF/PPTX, informe o humano:
```
Não consegui ler o texto de [arquivo]. Por favor, abra o arquivo e cole
o conteúdo mais relevante aqui (pode ser um resumo em suas palavras):
```

### Arquivos de Texto (.md, .txt, .html, .csv)
```bash
# Ler diretamente, limitando a 300 linhas por arquivo
head -300 "$ARQUIVO"
```

### Planilhas (.xlsx)
```bash
python3 -c "
try:
    import openpyxl
    wb = openpyxl.load_workbook('$ARQUIVO', read_only=True, data_only=True)
    for sheet_name in wb.sheetnames[:3]:  # primeiras 3 abas
        ws = wb[sheet_name]
        print(f'=== Aba: {sheet_name} ===')
        for row in list(ws.iter_rows(values_only=True))[:50]:  # primeiras 50 linhas
            if any(v is not None for v in row):
                print('\t'.join(str(v) if v is not None else '' for v in row))
except ImportError:
    print('[openpyxl não instalado — instalar: pip install openpyxl]')
except Exception as e:
    print(f'[Erro ao ler planilha: {e}]')
" 2>/dev/null
```

### Imagens (.png, .jpg, .svg com logo ou wireframe)
Não tente ler imagens diretamente. Apenas registre:
```
[IMAGEM: $ARQUIVO — nome sugere: logo/wireframe/screenshot — analisar visualmente se necessário]
```

---

## FASE 2 — Síntese e Preenchimento do business.md

Com base em tudo que foi lido, preencha o schema do business.md.

**Regras de síntese:**

1. **Priorize evidências explícitas** — se o pitch deck diz "R$ 97/mês", use esse valor.
   Não invente preços ou métricas.

2. **Use linguagem do cliente** — se os artefatos usam termos específicos do nicho,
   preserve-os. Eles refletem como o ICP fala.

3. **Marque incertezas** — onde os artefatos não forneceram informação suficiente,
   use: `[NÃO ENCONTRADO NOS ARTEFATOS — preencher manualmente]`

4. **Seção de canais (*)** — crucial para inferência de contas. Marque como `[x]` apenas
   canais mencionados explicitamente nos artefatos. Use `[ ]` para os demais.

5. **Stack de produto** — infira do contexto (ex: "usamos Webflow" em apresentação).
   Se não mencionado: `[não definido]`

6. **Seção 13 (Infraestrutura)** — deixe com `[]` — será preenchida pelo Prompt D.

### Mapeamento: seções do schema ← fontes

Para cada seção do `docs/business.template.md`, extraia informações dos artefatos lidos:

| Seção do schema | O que extrair | Fontes típicas |
|---|---|---|
| 1. Identidade | nome, tagline, descrição, problema, público, diferencial | pitch, landing page, README |
| 2. Mercado | setor, geografia, tamanho, concorrentes | pitch, business plan, pesquisas |
| 3. Modelo de Negócio | tipo, preço, planos, trial, MRR alvo | pitch, projeções financeiras |
| 4. Produto / MVP | funcionalidades, status | README, wireframes, docs técnicos |
| 5. Canais de Aquisição (*) | quais canais marcados [x] | copy de ads, briefing marketing, pitch |
| 6. Pagamentos (*) | processador, moeda, budget ads | planilhas financeiras, config |
| 7. Stack Técnico (*) | hospedagem, backend, banco, auth, email, analytics | package.json, config, README |
| 8. Equipe e Operação | fundadores, papel do agente | pitch, proposta |
| 9. Cronograma | prazos, marcos | business plan, roadmap |
| 10. Notas | contexto adicional, ambiguidades | tudo |

Para cada trecho relevante encontrado, anote internamente:
- Seção de destino (1-10)
- Conteúdo extraído
- Fonte (nome do arquivo)

Após todos os P1, avalie quais seções ainda têm menos de 50% dos campos preenchidos.
Se P2 pode ajudar, leia os P2 relevantes. Caso contrário, pule.

### Template de preenchimento

Gere o arquivo completo com o schema de `docs/business.template.md`,
substituindo cada campo com o conteúdo extraído dos artefatos.

**Importante:** escreva o arquivo diretamente usando a ferramenta de escrita
do Claude Code, não como bloco de código. O arquivo deve ser salvo em `$OUTPUT_FILE`.

---

## FASE 3 — Perguntas de Complemento

Após gerar o business.md, identifique os campos marcados como
`[NÃO ENCONTRADO NOS ARTEFATOS]` e agrupe-os por seção.

Apresente ao humano de forma concisa:

```
Business.md gerado com base em N artefatos.
Preenchi X de Y campos. Preciso de informação adicional para:

━━━ Campos essenciais (o instalador precisa destes) ━━━

  CANAIS DE AQUISIÇÃO — não ficou claro nos artefatos:
  → Você planeja usar Meta Ads (Facebook/Instagram)? [s/n]
  → Google Ads? [s/n]
  → WhatsApp para atendimento/campanha? [s/n]

  PAGAMENTOS:
  → Qual o preço do produto? [R$ X por mês / R$ X único]
  → Vai ter parcelamento? [s/n]

  STACK:
  → Já tem preferência de hospedagem? (Vercel / Railway / outro / não sei)

━━━ Campos opcionais (podem ser preenchidos depois) ━━━

  - Concorrentes (seção 2): não encontrados
  - Métricas de sucesso (seção 9): sem números definidos
  - Equipe (seção 8): não mencionado

Responda os campos essenciais — os opcionais podem ser atualizados a qualquer momento.
```

Processe as respostas e atualize o business.md gerado.

---

## FASE 4 — Validação e Confirmação

```bash
# Contar campos preenchidos vs. pendentes
PENDING=$(grep -c 'NÃO ENCONTRADO' "$OUTPUT_FILE" 2>/dev/null || echo 0)
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

Apresente o resumo final:

```
business.md gerado em: $OUTPUT_FILE

  Fontes lidas:    N artefatos
  Campos extraídos: X
  Campos pendentes: Y (marcados como [NÃO ENCONTRADO...])

  Seções críticas para o instalador:
    Canais (*):  [lista dos marcados como [x]]
    Pagamentos (*): [modelo, preço]
    Stack (*):   [hospedagem, banco, email]

O Prompt D agora usará este arquivo para inferir quais contas criar.
Quer revisar alguma seção antes de continuar? [s/n]
```

Se o humano quiser revisar, abra o editor:
```bash
${EDITOR:-nano} "$OUTPUT_FILE"
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

---

## INSTRUÇÕES OPERACIONAIS

- **Nunca invente dados** — se não está nos artefatos, marque como não encontrado.
- **Contexto limitado** — se o diretório tiver muitos arquivos grandes, leia os P1 primeiro
  e pergunte ao humano se precisa de mais antes de passar para P2.
- **Artefatos em inglês** — traduza o conteúdo para PT-BR no business.md, mas preserve
  termos técnicos e nomes próprios.
- **Pitch decks com pouco texto** — peça ao humano para descrever os slides principais
  com suas palavras. Um parágrafo de contexto vale mais que tentar OCR.
- **Confidencialidade** — nenhum conteúdo dos artefatos deve ser logado ou enviado
  para fora do ambiente local. O business.md é o único output persistido.
