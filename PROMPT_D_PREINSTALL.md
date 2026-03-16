# PROMPT D — Pré-Instalação: Geração do business.md e Setup de Contas

> **Objetivo:** Preparar tudo que o `install.sh` precisa antes de rodar.
> Gerar o `business.md` do experimento, inferir contas necessárias a partir dele,
> e guiar o humano por um checklist de configuração.
>
> **Pré-requisitos:**
>   - Repositório do agente clonado (`~/agent-template/` ou equivalente)
>   - `secrets_setup.sh` funcional (`bash secrets/secrets_setup.sh help`)
>   - `docs/business.template.md` presente (schema canônico)
>
> **Fluxo:**
> ```
> Passo 0: Gerar/validar business.md (3 modos de entrada)
> Passo 1: Confirmar experimento + verificar contas existentes
> Passo 2: Analisar business.md e mapear contas necessárias
> Passo 3: Checklist guiado (criar contas faltantes)
> Passo 4: Salvar e verificar
> ```

---

## PASSO 0 — Gerar ou Validar o business.md

> O `business.md` é o documento central do experimento. Ele define o negócio,
> e o próximo passo (inferência de contas) depende inteiramente do seu conteúdo.
> Esta etapa garante que o arquivo existe e está bem preenchido antes de prosseguir.

### 0.1 — Identificar o slug do experimento

Pergunte ao humano:
```
Qual é o slug do experimento que vamos configurar?
(Ex: negocia_ai, recruta_ai, minha_startup)
```

Valide o formato (snake_case minúsculo: apenas letras minúsculas, números e underscores).
Armazene como `$SLUG`.

```bash
# Verificar se o diretório do experimento já existe
ls experiments/$SLUG/ 2>/dev/null && echo "DIR_EXISTS" || echo "DIR_NOT_EXISTS"
```

Se o diretório não existir, criá-lo antes de continuar:
```bash
bash secrets/secrets_setup.sh new $SLUG
echo "Diretório criado: experiments/$SLUG/"
```

### 0.2 — Verificar se business.md já existe

```bash
if [ -f "experiments/$SLUG/business.md" ]; then
  LINES=$(wc -l < "experiments/$SLUG/business.md")
  EMPTY=$(grep -c "NÃO ENCONTRADO\|PREENCHER" "experiments/$SLUG/business.md" 2>/dev/null || echo 0)
  echo "EXISTE — $LINES linhas — $EMPTY campos pendentes"
else
  echo "NÃO EXISTE"
fi
```

**Se business.md já existe e parece completo** (menos de 5 campos pendentes):
```
business.md encontrado com $LINES linhas e $EMPTY campos pendentes.
Quer:
  1. Usar como está e continuar
  2. Revisar no editor antes de continuar
  3. Regenerar do zero (sobrescreve o atual)
```
Processar a escolha e avançar para o Passo 1.

**Se business.md existe mas está incompleto** (5+ campos pendentes) **ou não existe**:
apresentar o menu de modos abaixo.

### 0.3 — Menu de Modos de Entrada

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GERAR business.md — $SLUG
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Como você quer fornecer as informações do negócio?

  1. Colar texto agora
     (pitch, descrição, resumo — qualquer formato)

  2. Apontar um diretório com artefatos
     (PDFs, planilhas, apresentações, landing pages, etc.)
     A IA vai ler e sintetizar automaticamente.

  3. Preencher o template interativamente
     (responder perguntas uma a uma — mais demorado, mais completo)

Escolha [1/2/3]:
```

---

### MODO 1 — Colar Texto

```
Cole tudo que você tem sobre o negócio.
Pode ser: um pitch, uma descrição informal, o texto da landing page,
um resumo de uma reunião, ou qualquer mistura desses.
Não precisa ter formato — a IA vai estruturar.

Cole o texto e digite FIM em uma linha separada para finalizar:
```

```bash
echo "Cole o texto sobre o negócio. Quando terminar, digite FIM em uma linha separada:"
PASTED_TEXT=""
while IFS= read -r line; do
  [[ "$line" == "FIM" ]] && break
  PASTED_TEXT="$PASTED_TEXT
$line"
done
echo "Texto recebido: $(echo "$PASTED_TEXT" | wc -w) palavras"
```

Com o texto recebido, preencha o schema do `docs/business.template.md`,
aplicando as mesmas regras de síntese do `ANALYZE_ARTIFACTS.md` (Fase 2):

- Campos cobertos pelo texto → preencher com conteúdo extraído
- Campos inferíveis → preencher com `(inferido do texto colado)` ao final
- Campos não cobertos (obrigatórios) → `[NÃO ENCONTRADO — preencher]`
- Campos não cobertos (opcionais) → `[não definido — ajustar depois]`
- Seções 5 e 7: usar `[x]` / `[ ]` conforme mencionado no texto

Após gerar, verificar campos essenciais faltantes e perguntar ao humano:

```
━━━  Campos pendentes — preciso da sua ajuda  ━━━

O texto cobriu X de Y campos. Faltam estes obrigatórios:

1. [Seção X] Pergunta?
2. [Seção Y] Pergunta?

Responda inline (1. resposta, 2. resposta, ...) ou "pular".
```

Salvar em `experiments/$SLUG/business.md`.

---

### MODO 2 — Diretório de Artefatos

```
Informe o caminho completo do diretório com os artefatos do negócio.
Exemplo: /Users/joao/Dropbox/negocia_ai/pitch
         ~/Desktop/materiais_recruta
         /tmp/artefatos
```

```bash
read -r -p "Caminho do diretório: " ARTIFACTS_DIR

# Expandir ~ se presente
ARTIFACTS_DIR="${ARTIFACTS_DIR/#\~/$HOME}"

# Validar existência
if [ ! -d "$ARTIFACTS_DIR" ]; then
  echo "✗ Diretório não encontrado: $ARTIFACTS_DIR"
  echo "  Verifique o caminho e tente novamente."
  # Voltar ao menu
else
  echo "✓ Diretório encontrado"
  echo "  Arquivos: $(find "$ARTIFACTS_DIR" -type f ! -path '*/.git/*' | wc -l)"
  echo "  Tamanho:  $(du -sh "$ARTIFACTS_DIR" 2>/dev/null | cut -f1)"
fi
```

Após confirmar o diretório, executar o sub-prompt `ANALYZE_ARTIFACTS.md`:

```bash
ARTIFACTS_DIR="$ARTIFACTS_DIR" \
SLUG="$SLUG" \
OUTPUT_FILE="experiments/$SLUG/business.md" \
claude --dangerously-skip-permissions \
       -p "$(cat ANALYZE_ARTIFACTS.md)" \
       --output-format text
```

Se o Claude Code não suportar execução aninhada diretamente:
```
Abra uma nova sessão do Claude Code e rode:

  ARTIFACTS_DIR="$ARTIFACTS_DIR" SLUG="$SLUG" OUTPUT_FILE="experiments/$SLUG/business.md" \
    claude --dangerously-skip-permissions -p "$(cat ANALYZE_ARTIFACTS.md)"

Quando terminar, volte aqui e pressione Enter para continuar.
```

Após conclusão, verificar o output:
```bash
[ -f "experiments/$SLUG/business.md" ] && \
  echo "✓ business.md gerado: $(wc -l < experiments/$SLUG/business.md) linhas" || \
  echo "✗ business.md não foi gerado — verificar erros acima"
```

---

### MODO 3 — Preenchimento Interativo

Conduza uma entrevista estruturada cobrindo cada seção do schema.

**Perguntas mínimas obrigatórias:**

```
1. Qual é o nome do negócio?
   › ___

2. Em uma frase: o que o produto faz e para quem?
   › ___

3. Qual é o preço? (Ex: R$ 97/mês, R$ 497 único, gratuito + comissão)
   › ___

4. Como você vai atrair clientes? (pode marcar mais de um)
   a) Anúncios no Instagram/Facebook (Meta Ads)
   b) Anúncios no Google
   c) WhatsApp (atendimento ou campanha ativa)
   d) Email marketing
   e) Orgânico / SEO / Conteúdo
   f) Outro: ___
   › ___

5. Tem preferência de plataforma para o site/app?
   (Vercel, Webflow, WordPress, não sei ainda)
   › ___

6. Qual o prazo para ter os primeiros clientes pagantes?
   › ___
```

Para cada resposta, preencher a seção correspondente do template.
Campos não cobertos → `[não definido — ajustar depois]`.

Após as 6 perguntas, oferecer:
```
Quer detalhar mais alguma seção? (equipe, concorrentes, funcionalidades, etc.)
Ou Enter para continuar com o que temos.
```

Salvar em `experiments/$SLUG/business.md`.

---

### 0.4 — Validação Final do business.md

Independente do modo usado, executar validação antes de avançar:

```bash
BIZ="experiments/$SLUG/business.md"

echo "=== VALIDAÇÃO DO business.md ==="

check_field() {
  local label="$1" pattern="$2"
  if grep -q "$pattern" "$BIZ" 2>/dev/null; then
    echo "  ✓ $label"
  else
    echo "  ⚠ $label — não encontrado"
  fi
}

check_field "Canais de aquisição"     "\[x\]"
check_field "Modelo de precificação"  "Tipo:"
check_field "Stack — hospedagem"      "Hospedagem:"
check_field "Email configurado"       "from_email\|Email transacional"

PENDING=$(grep -c "NÃO ENCONTRADO\|PREENCHER" "$BIZ" 2>/dev/null || echo 0)
echo ""
echo "  Campos ainda pendentes: $PENDING"

if [ "$PENDING" -gt 5 ]; then
  echo ""
  echo "  Há $PENDING campos pendentes. Recomendo revisar antes de continuar:"
  echo "    nano experiments/$SLUG/business.md"
  echo ""
  read -r -p "  Continuar mesmo assim? [s/n]: " CONFIRM
  [[ "$CONFIRM" != "s" ]] && { echo "Revise o business.md e rode novamente."; exit 0; }
fi

echo ""
echo "  ✓ business.md validado. Avançando para inferência de contas..."
```

### 0.5 — Adicionar Metadados ao business.md

```bash
python3 - << 'METAEOF'
import re
from pathlib import Path
from datetime import datetime, timezone

slug = "$SLUG"
path = Path(f'experiments/{slug}/business.md')
content = path.read_text()

now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
meta_block = f"""---
slug: "{slug}"
version: "1.0"
created_at: "{now}"
last_updated: "{now}"
generated_by: "prompt_d_preinstall"
---

"""

# Remover bloco YAML anterior se existir
content = re.sub(r'^---.*?---\n\n', '', content, flags=re.DOTALL)
path.write_text(meta_block + content)
print(f"✓ Metadados atualizados em {path}")
METAEOF
```

---

## PASSO 1 — Confirmar Experimento e Verificar Contas Existentes

> O business.md já foi validado no Passo 0. Este passo confirma o contexto
> e verifica quais credenciais já existem no `secrets.yaml` do experimento.

### 1.1 — Confirmar contexto

```bash
echo "━━━  Experimento: $SLUG  ━━━"
echo ""
echo "Diretório: experiments/$SLUG/"
echo "business.md: $(wc -l < experiments/$SLUG/business.md) linhas"
echo ""

# Resumo do negócio (primeiras linhas úteis)
grep -A1 "Nome do negócio:" "experiments/$SLUG/business.md" | head -2
grep -A1 "Descrição" "experiments/$SLUG/business.md" | head -2
echo ""
```

### 1.2 — Verificar secrets.yaml existente

```bash
SECRETS_FILE="experiments/$SLUG/secrets.yaml"

if [ -f "$SECRETS_FILE" ]; then
  echo "secrets.yaml encontrado."
  echo ""

  # Contar campos já preenchidos vs vazios
  python3 - << 'PYEOF'
import yaml, sys
from pathlib import Path

path = Path("$SECRETS_FILE")
with open(path) as f:
    data = yaml.safe_load(f) or {}

def count_keys(d, prefix=""):
    filled = 0
    empty = 0
    for k, v in d.items():
        if k.startswith('_'):
            continue
        full_key = f"{prefix}.{k}" if prefix else k
        if isinstance(v, dict):
            f, e = count_keys(v, full_key)
            filled += f
            empty += e
        elif isinstance(v, str):
            if v and v not in ('""', "''", 'sandbox', 'test'):
                filled += 1
            elif not v:
                empty += 1
    return filled, empty

filled, empty = count_keys(data)
print(f"  Credenciais preenchidas: {filled}")
print(f"  Credenciais vazias:      {empty}")
PYEOF

else
  echo "secrets.yaml não encontrado — será criado após inferência."
fi
```

---

## PASSO 2 — Analisar o business.md e Mapear Contas Necessárias

> Lê o business.md validado e determina quais contas/credenciais são necessárias
> com base nas seções 5 (canais), 6 (pagamentos) e 7 (stack).

### 2.1 — Extrair canais marcados (Seção 5)

```bash
echo "━━━  Canais de aquisição marcados  ━━━"
grep "\[x\]" "experiments/$SLUG/business.md" | while read -r line; do
  echo "  $line"
done
echo ""
```

### 2.2 — Mapear canais → contas necessárias

Tabela de inferência:

| Canal marcado [x] | Contas necessárias |
|---|---|
| Meta Ads | Meta Business Suite, Ad Account (act_), Meta Pixel, App (developers.facebook.com) |
| Google Ads | Google Ads account, billing, developer token |
| Google orgânico / SEO | Google Search Console, Google Analytics 4 |
| WhatsApp Business | WhatsApp Business API, número dedicado, webhook |
| Email marketing | SendGrid (ou equivalente), domínio verificado |
| Conteúdo / Blog | CMS ou gerador estático (já coberto pela stack) |

| Stack marcado [x] | Credenciais em secrets.yaml |
|---|---|
| Vercel | `product.vercel.token`, `team_id`, `project_id` |
| Supabase | `product.supabase.url`, `anon_key`, `service_role_key` |
| Stripe | `product.stripe.publishable_key`, `secret_key`, `webhook_secret` |
| SendGrid | `communication.sendgrid.api_key`, `from_email`, `from_name` |
| Google Analytics 4 | `analytics.google_analytics.measurement_id`, `api_secret` |
| PostHog | `analytics.posthog.api_key`, `project_id` |

### 2.3 — Gerar lista de ações

Para cada conta necessária, determinar:
1. A conta já tem credencial preenchida no secrets.yaml? → **OK, pular**
2. A conta precisa ser criada? → **Adicionar ao checklist (Passo 3)**
3. A conta existe mas falta preencher credencial? → **Adicionar ao checklist**

```
━━━  Contas necessárias para $SLUG  ━━━

  ✓ Anthropic API          — já configurada em _shared.yaml
  ✓ GitHub PAT             — já configurada em _shared.yaml
  ⚠ Meta Business Suite    — conta necessária (Meta Ads marcado)
  ⚠ Meta Ad Account        — criar em business.facebook.com
  ⚠ Stripe (test)          — criar em stripe.com/register
  ⚠ SendGrid               — criar em sendgrid.com
  ⚠ Google Analytics 4     — criar em analytics.google.com
  ─ Google Ads             — não marcado, pulando
  ─ WhatsApp Business API  — não marcado, pulando

  Total: X contas a configurar
```

---

## PASSO 3 — Checklist Guiado

> Para cada conta marcada como ⚠ no Passo 2, guiar o humano pelo setup.

### Formato de cada item do checklist

```
━━━  [N/Total]  Meta Business Suite  ━━━

Por que: Necessário para rodar Meta Ads (Instagram/Facebook).

Como criar:
  1. Acesse https://business.facebook.com
  2. Clique em "Criar conta" (use o Facebook pessoal para autenticar)
  3. Siga o wizard de configuração
  4. Após criar, vá em Configurações → Contas de Anúncio → Adicionar

Credenciais a coletar:
  - ad_account_id: Business Manager → Configurações → Contas de anúncio → ID (act_XXXXXXXXXX)
  - pixel_id: Gerenciador de Eventos → Fontes de Dados → Pixel → ID

Quando tiver as credenciais, digite-as abaixo
(ou "pular" para configurar depois):
  ad_account_id › ___
  pixel_id      › ___
```

Após cada credencial coletada, salvar imediatamente no secrets.yaml:

```bash
python3 - << 'PYEOF'
import yaml
from pathlib import Path

path = Path("experiments/$SLUG/secrets.yaml")
with open(path) as f:
    data = yaml.safe_load(f) or {}

# Injetar credencial coletada
# (adaptar para cada campo — exemplo para Meta)
data.setdefault('ads', {}).setdefault('meta', {})
data['ads']['meta']['ad_account_id'] = "$AD_ACCOUNT_ID"
data['ads']['meta']['pixel_id'] = "$PIXEL_ID"

with open(path, 'w') as f:
    yaml.dump(data, f, allow_unicode=True, default_flow_style=False, sort_keys=False)

print("  ✓ Credenciais Meta salvas em secrets.yaml")
PYEOF
```

Repetir para cada conta do checklist.

---

## PASSO 4 — Salvar e Verificar

### 4.1 — Verificação final do secrets.yaml

```bash
echo "━━━  Verificação final — $SLUG  ━━━"
echo ""

python3 - << 'PYEOF'
import yaml
from pathlib import Path

path = Path("experiments/$SLUG/secrets.yaml")
with open(path) as f:
    data = yaml.safe_load(f) or {}

def check_section(d, section_name, keys):
    print(f"\n  {section_name}:")
    for key_path in keys:
        parts = key_path.split('.')
        obj = d
        for p in parts:
            obj = obj.get(p, {}) if isinstance(obj, dict) else {}
        value = obj if isinstance(obj, str) else ""
        status = "✓" if value else "⚠ vazio"
        masked = value[:4] + "..." if len(value) > 4 else value
        print(f"    {status}  {key_path}: {masked}")

# Verificar seções baseadas nos canais marcados no business.md
biz = Path("experiments/$SLUG/business.md").read_text()

if "[x] **Meta Ads**" in biz:
    check_section(data, "Meta Ads", [
        "ads.meta.ad_account_id",
        "ads.meta.access_token",
        "ads.meta.pixel_id"
    ])

if "[x] **Stripe" in biz or "Stripe" in str(data.get('product', {}).get('stripe', {})):
    check_section(data, "Stripe", [
        "product.stripe.publishable_key",
        "product.stripe.secret_key",
        "product.stripe.webhook_secret"
    ])

if "[x] **Google Analytics" in biz:
    check_section(data, "Google Analytics", [
        "analytics.google_analytics.measurement_id",
        "analytics.google_analytics.api_secret"
    ])

if "[x] **SendGrid" in biz or "[x] **Email" in biz:
    check_section(data, "SendGrid", [
        "communication.sendgrid.api_key",
        "communication.sendgrid.from_email"
    ])
PYEOF

echo ""
echo "━━━  Resumo  ━━━"
echo ""
echo "  Experimento:   $SLUG"
echo "  business.md:   experiments/$SLUG/business.md"
echo "  secrets.yaml:  experiments/$SLUG/secrets.yaml"
echo ""
echo "  Próximo passo: bash install.sh"
echo ""
echo "  Para revisar credenciais depois:"
echo "    nano experiments/$SLUG/secrets.yaml"
echo "    python3 secrets/secrets_loader.py status"
```

### 4.2 — Permissões e segurança

```bash
chmod 600 "experiments/$SLUG/secrets.yaml"
echo "✓ Permissões 600 em secrets.yaml"

# Garantir que .gitignore protege o arquivo
grep -q "experiments/\*/secrets.yaml" .gitignore 2>/dev/null || \
  echo "experiments/*/secrets.yaml" >> .gitignore
```

---

## ENTREGA

```
Após rodar o Prompt D completo, o diretório do experimento terá:

  experiments/$SLUG/
  ├── business.md       ← gerado e validado (Passo 0)
  └── secrets.yaml      ← credenciais preenchidas (Passos 2-4)

O install.sh pode ser rodado imediatamente após.
```
