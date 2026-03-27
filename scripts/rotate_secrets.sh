#!/usr/bin/env bash
# =============================================================================
# rotate_secrets.sh — Guia interativo para rotacao de credenciais
# =============================================================================
# Uso:
#   bash scripts/rotate_secrets.sh              # guia completo
#   bash scripts/rotate_secrets.sh --status     # verificar idade das chaves
#   bash scripts/rotate_secrets.sh --service X  # rotacionar um servico especifico
#
# IMPORTANTE: Este script NAO rotaciona chaves automaticamente.
# Ele guia o humano pelo processo passo-a-passo, valida o resultado
# e registra a rotacao no audit log.
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHARED_FILE="$REPO_ROOT/secrets/_shared.yaml"
AUDIT_LOG="$REPO_ROOT/logs/secrets_rotation.log"

# Cores
if [[ -t 1 ]] && tput colors &>/dev/null && [[ $(tput colors) -ge 8 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BOLD=''; DIM=''; RESET=''
fi

ok()     { echo -e "  ${GREEN}OK${RESET}    $*"; }
warn()   { echo -e "  ${YELLOW}WARN${RESET}  $*"; }
fail()   { echo -e "  ${RED}FAIL${RESET}  $*"; }
header() { echo -e "\n${BOLD}━━━  $*  ━━━${RESET}\n"; }

log_rotation() {
  local service="$1" status="$2"
  mkdir -p "$(dirname "$AUDIT_LOG")"
  echo "{\"ts\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"service\":\"$service\",\"status\":\"$status\"}" >> "$AUDIT_LOG"
}

# =============================================================================
# CATALOGO DE SERVICOS
# =============================================================================
# Cada servico define: nome, URL de rotacao, campo no secrets, e teste de validacao

declare -A SVC_URL SVC_KEY SVC_TEST SVC_PREFIX SVC_WARN

# --- LLMs ---
SVC_URL[openai]="https://platform.openai.com/api-keys"
SVC_KEY[openai]="llm.openai.api_key"
SVC_TEST[openai]='curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer KEY" https://api.openai.com/v1/models'
SVC_PREFIX[openai]="sk-"

SVC_URL[xai]="https://console.x.ai/team/api-keys"
SVC_KEY[xai]="llm.xai.api_key"
SVC_TEST[xai]='curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer KEY" https://api.x.ai/v1/models'
SVC_PREFIX[xai]="xai-"

SVC_URL[google]="https://aistudio.google.com/apikey"
SVC_KEY[google]="llm.google.api_key"
SVC_PREFIX[google]="AIza"

# --- Busca ---
SVC_URL[exa]="https://dashboard.exa.ai/api-keys"
SVC_KEY[exa]="search.exa.api_key"

SVC_URL[serper]="https://serper.dev/api-key"
SVC_KEY[serper]="search.serper.api_key"

# --- Infra ---
SVC_URL[github]="https://github.com/settings/tokens"
SVC_KEY[github]="infra.github.personal_access_token"
SVC_PREFIX[github]="ghp_"
SVC_WARN[github]="Gere um token com escopo minimo: repo, workflow. Sem admin scopes."

SVC_URL[cloudflare]="https://dash.cloudflare.com/profile/api-tokens"
SVC_KEY[cloudflare]="infra.cloudflare.api_token"

# --- Comunicacao ---
SVC_URL[telegram]="https://t.me/BotFather (comando /token)"
SVC_KEY[telegram]="communication.telegram.bot_token"
SVC_WARN[telegram]="Apos rotacionar, atualize tambem o webhook se houver."

SVC_URL[slack]="https://api.slack.com/apps (seu app > Incoming Webhooks)"
SVC_KEY[slack]="communication.slack.webhook_url"

# Lista ordenada de servicos
SERVICES=(openai xai google exa serper github cloudflare telegram slack)

# =============================================================================
# FUNCOES
# =============================================================================

get_current_key() {
  local svc="$1"
  local key_path="${SVC_KEY[$svc]}"
  if command -v python3 &>/dev/null && [[ -f "$SHARED_FILE" ]]; then
    python3 -c "
import yaml
with open('$SHARED_FILE') as f:
    d = yaml.safe_load(f) or {}
keys = '$key_path'.split('.')
obj = d
for k in keys:
    obj = obj.get(k, {}) if isinstance(obj, dict) else {}
val = obj if isinstance(obj, str) else ''
print(val)
" 2>/dev/null
  fi
}

mask_key() {
  local key="$1"
  if [[ ${#key} -gt 8 ]]; then
    echo "${key:0:6}...${key: -4}"
  elif [[ ${#key} -gt 0 ]]; then
    echo "${key:0:3}..."
  else
    echo "(vazio)"
  fi
}

update_key() {
  local svc="$1" new_key="$2"
  local key_path="${SVC_KEY[$svc]}"

  if ! command -v python3 &>/dev/null || [[ ! -f "$SHARED_FILE" ]]; then
    fail "Python3 ou _shared.yaml nao encontrado"
    return 1
  fi

  python3 - "$SHARED_FILE" "$key_path" "$new_key" << 'PYEOF'
import yaml, sys
from pathlib import Path

path = Path(sys.argv[1])
key_path = sys.argv[2]
new_value = sys.argv[3]

with open(path) as f:
    data = yaml.safe_load(f) or {}

keys = key_path.split('.')
obj = data
for k in keys[:-1]:
    obj = obj.setdefault(k, {})
obj[keys[-1]] = new_value

with open(path, 'w') as f:
    yaml.dump(data, f, allow_unicode=True, default_flow_style=False, sort_keys=False)

print(f"  Atualizado: {key_path}")
PYEOF
}

test_key() {
  local svc="$1" key="$2"
  local test_cmd="${SVC_TEST[$svc]:-}"

  if [[ -z "$test_cmd" ]]; then
    warn "Sem teste automatico para $svc — verifique manualmente"
    return 0
  fi

  local cmd="${test_cmd//KEY/$key}"
  local status
  status=$(eval "$cmd" 2>/dev/null || echo "000")

  if [[ "$status" == "200" ]] || [[ "$status" == "201" ]]; then
    ok "API $svc respondeu: HTTP $status"
    return 0
  elif [[ "$status" == "401" ]] || [[ "$status" == "403" ]]; then
    fail "API $svc rejeitou a chave: HTTP $status"
    return 1
  else
    warn "API $svc retornou HTTP $status — verifique manualmente"
    return 0
  fi
}

rotate_service() {
  local svc="$1"
  local url="${SVC_URL[$svc]}"
  local prefix="${SVC_PREFIX[$svc]:-}"
  local warning="${SVC_WARN[$svc]:-}"
  local current
  current=$(get_current_key "$svc")

  header "Rotacao: $svc"

  if [[ -n "$current" ]]; then
    echo -e "  Chave atual: ${DIM}$(mask_key "$current")${RESET}"
  else
    echo -e "  Chave atual: ${YELLOW}(nao configurada)${RESET}"
  fi

  if [[ -n "$warning" ]]; then
    echo -e "  ${YELLOW}ATENCAO: $warning${RESET}"
  fi

  echo ""
  echo -e "  Passo 1: Acesse ${BOLD}$url${RESET}"
  echo -e "  Passo 2: Gere uma nova chave (NAO delete a antiga ainda)"
  echo -e "  Passo 3: Cole a nova chave abaixo"
  echo ""

  read -r -s -p "  Nova chave (ou Enter para pular): " new_key
  echo ""

  if [[ -z "$new_key" ]]; then
    warn "$svc: pulado"
    return
  fi

  # Validar prefixo
  if [[ -n "$prefix" ]] && [[ ! "$new_key" == "$prefix"* ]]; then
    fail "Chave nao comeca com '$prefix'. Verifique se copiou corretamente."
    read -r -p "  Usar mesmo assim? [s/N]: " confirm
    [[ "$confirm" != "s" ]] && return
  fi

  # Testar nova chave
  echo ""
  echo -e "  Testando nova chave..."
  if test_key "$svc" "$new_key"; then
    # Salvar
    update_key "$svc" "$new_key"
    chmod 600 "$SHARED_FILE"
    log_rotation "$svc" "rotated"

    echo ""
    ok "$svc rotacionado com sucesso"
    echo -e "  ${DIM}Passo 4: Agora delete a chave ANTIGA no painel do servico${RESET}"
    echo -e "  ${DIM}         URL: $url${RESET}"
  else
    fail "Teste falhou. Chave NAO foi salva."
    echo -e "  Verifique a chave e tente novamente."
    log_rotation "$svc" "failed"
  fi
}

# =============================================================================
# COMANDOS
# =============================================================================

cmd_status() {
  header "Status das credenciais"

  echo -e "  ${BOLD}Servico          Chave                    Ultima rotacao${RESET}"
  echo "  ──────────────────────────────────────────────────────────────────"

  for svc in "${SERVICES[@]}"; do
    local current
    current=$(get_current_key "$svc")
    local masked
    masked=$(mask_key "$current")

    # Buscar ultima rotacao no log
    local last_rotation="—"
    if [[ -f "$AUDIT_LOG" ]]; then
      last_rotation=$(grep "\"$svc\"" "$AUDIT_LOG" 2>/dev/null | tail -1 | \
        python3 -c "import json,sys; print(json.loads(sys.stdin.readline()).get('ts','—'))" 2>/dev/null || echo "—")
    fi

    local icon="  "
    if [[ -z "$current" ]]; then
      icon="${DIM}○${RESET} "
    else
      icon="${GREEN}●${RESET} "
    fi

    printf "  %b %-16s %-24s %s\n" "$icon" "$svc" "$masked" "$last_rotation"
  done

  echo ""
  echo -e "  ${DIM}● configurado  ○ vazio/ausente${RESET}"
  echo -e "  ${DIM}Recomendacao: rotacionar chaves a cada 90 dias${RESET}"
}

cmd_rotate_all() {
  header "Rotacao de todas as credenciais"
  echo -e "  Vamos percorrer cada servico. Pressione Enter para pular.\n"

  for svc in "${SERVICES[@]}"; do
    local current
    current=$(get_current_key "$svc")
    [[ -z "$current" ]] && continue  # Pular servicos nao configurados

    rotate_service "$svc"
    echo ""
  done

  header "Rotacao concluida"
  echo -e "  Lembre-se de:"
  echo -e "    1. Deletar as chaves ANTIGAS nos paineis dos servicos"
  echo -e "    2. Testar o heartbeat: bash heartbeat.sh"
  echo -e "    3. Limpar logs antigos que contenham chaves anteriores:"
  echo -e "       ${DIM}sudo journalctl --rotate && sudo journalctl --vacuum-time=1s${RESET}"
}

cmd_rotate_single() {
  local target="$1"
  local found=false

  for svc in "${SERVICES[@]}"; do
    if [[ "$svc" == "$target" ]]; then
      found=true
      rotate_service "$svc"
      break
    fi
  done

  if ! $found; then
    fail "Servico '$target' nao encontrado."
    echo -e "  Servicos disponiveis: ${SERVICES[*]}"
    exit 1
  fi
}

# =============================================================================
# MAIN
# =============================================================================

echo -e "\n${BOLD}Rotacao de Secrets — Agent Template${RESET}\n"

case "${1:-}" in
  --status|-s)
    cmd_status
    ;;
  --service)
    [[ -z "${2:-}" ]] && { fail "Informe o servico. Ex: --service anthropic"; exit 1; }
    cmd_rotate_single "$2"
    ;;
  --help|-h)
    echo "Uso:"
    echo "  bash scripts/rotate_secrets.sh              # rotacionar todas"
    echo "  bash scripts/rotate_secrets.sh --status     # ver status das chaves"
    echo "  bash scripts/rotate_secrets.sh --service X  # rotacionar servico especifico"
    echo ""
    echo "Servicos: ${SERVICES[*]}"
    ;;
  *)
    cmd_status
    echo ""
    read -r -p "  Iniciar rotacao? [s/N]: " confirm
    [[ "$confirm" == "s" ]] && cmd_rotate_all || echo "  Cancelado."
    ;;
esac
