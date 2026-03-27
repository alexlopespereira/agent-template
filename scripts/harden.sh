#!/usr/bin/env bash
# =============================================================================
# harden.sh — Security hardening para agentes autonomos baseados em Claude Code
# =============================================================================
# Uso:
#   bash scripts/harden.sh              # executar todas as verificacoes
#   bash scripts/harden.sh --fix        # corrigir automaticamente o que for possivel
#   bash scripts/harden.sh --check      # apenas relatorio (sem modificar nada)
#
# Este script pode ser executado a qualquer momento apos o install.sh.
# Ele tambem e chamado automaticamente durante a instalacao.
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIX_MODE=false
CHECK_ONLY=false
ISSUES=0
FIXED=0
WARNINGS=0

# Cores
if [[ -t 1 ]] && tput colors &>/dev/null && [[ $(tput colors) -ge 8 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; DIM=''; RESET=''
fi

ok()   { echo -e "  ${GREEN}PASS${RESET}  $*"; }
fail() { echo -e "  ${RED}FAIL${RESET}  $*"; ((ISSUES++)); }
fix()  { echo -e "  ${GREEN}FIX ${RESET}  $*"; ((FIXED++)); }
warn() { echo -e "  ${YELLOW}WARN${RESET}  $*"; ((WARNINGS++)); }
info() { echo -e "  ${DIM}INFO${RESET}  $*"; }
header() { echo -e "\n${BOLD}[$1]${RESET}\n"; }

case "${1:-}" in
  --fix)       FIX_MODE=true ;;
  --check)     CHECK_ONLY=true ;;
  --help|-h)
    echo "Uso: bash scripts/harden.sh [--fix | --check]"
    echo "  --fix    Corrigir automaticamente o que for possivel"
    echo "  --check  Apenas relatorio, sem modificar nada"
    echo "  (sem flag) Relatorio + perguntar antes de corrigir"
    exit 0
    ;;
esac

echo -e "\n${BOLD}Security Hardening — Agent Template${RESET}"
echo -e "${DIM}$(date -u +"%Y-%m-%dT%H:%M:%SZ")  repo: $REPO_ROOT${RESET}\n"

# =============================================================================
# 1. PERMISSOES DE ARQUIVOS SENSIVEIS
# =============================================================================
header "1/7 Permissoes de arquivos sensiveis"

check_perm() {
  local file="$1" expected="$2" label="${3:-$1}"
  # Expandir ~ se presente
  file="${file/#\~/$HOME}"

  if [[ ! -e "$file" ]]; then
    info "$label: arquivo nao existe (ok se ainda nao foi criado)"
    return
  fi

  local mode
  mode=$(stat -c '%a' "$file" 2>/dev/null || stat -f '%OLp' "$file" 2>/dev/null || echo "?")

  if [[ "$mode" == "$expected" ]]; then
    ok "$label ($mode)"
  else
    fail "$label: permissao $mode (esperado $expected)"
    if $FIX_MODE; then
      chmod "$expected" "$file"
      fix "$label: corrigido para $expected"
    elif ! $CHECK_ONLY; then
      echo -e "       ${DIM}Corrigir: chmod $expected \"$file\"${RESET}"
    fi
  fi
}

# Secrets e credenciais
check_perm "$REPO_ROOT/secrets/_shared.yaml"           600 "secrets/_shared.yaml"
check_perm "$REPO_ROOT/.install-answers.env"            600 ".install-answers.env"
check_perm "$REPO_ROOT/secrets/keys.env"                600 "secrets/keys.env"

# Todos os secrets.yaml em experiments/
if [[ -d "$REPO_ROOT/experiments" ]]; then
  while IFS= read -r f; do
    local_label="${f#"$REPO_ROOT"/}"
    check_perm "$f" 600 "$local_label"
  done < <(find "$REPO_ROOT/experiments" -name "secrets.yaml" -type f 2>/dev/null)
fi

# Todos os .env em secrets/
while IFS= read -r f; do
  local_label="${f#"$REPO_ROOT"/}"
  check_perm "$f" 600 "$local_label"
done < <(find "$REPO_ROOT/secrets" -name "*.env" -type f 2>/dev/null)

# Diretorio secrets/ deve ser 700
if [[ -d "$REPO_ROOT/secrets" ]]; then
  local_mode=$(stat -c '%a' "$REPO_ROOT/secrets" 2>/dev/null || stat -f '%OLp' "$REPO_ROOT/secrets" 2>/dev/null)
  if [[ "$local_mode" == "700" ]]; then
    ok "secrets/ (dir $local_mode)"
  else
    fail "secrets/ dir: permissao $local_mode (esperado 700)"
    if $FIX_MODE; then
      chmod 700 "$REPO_ROOT/secrets"
      fix "secrets/: corrigido para 700"
    fi
  fi
fi

# Arquivos do usuario
check_perm "$HOME/.claude/settings.json"  600 "~/.claude/settings.json"
check_perm "$HOME/.gitconfig"             644 "~/.gitconfig"

# Logs sensiveis (contem audit trail)
check_perm "$REPO_ROOT/logs/secrets_audit.log" 600 "logs/secrets_audit.log"
check_perm "$REPO_ROOT/logs/budget_spend.log"  600 "logs/budget_spend.log"

# branding.yaml (contem credenciais do blog)
for branding in "$REPO_ROOT/config/branding.yaml" "$HOME/edge/config/branding.yaml"; do
  if [[ -f "$branding" ]]; then
    check_perm "$branding" 600 "$(basename "$(dirname "$branding")")/branding.yaml"
  fi
done

# =============================================================================
# 2. GITIGNORE COMPLETUDE
# =============================================================================
header "2/7 .gitignore — protecao contra commit acidental de secrets"

GITIGNORE="$REPO_ROOT/.gitignore"
if [[ ! -f "$GITIGNORE" ]]; then
  fail ".gitignore nao encontrado!"
else
  required_patterns=(
    "*.env"
    "secrets/_shared.yaml"
    "experiments/*/secrets.yaml"
    ".install-answers.env"
    "logs/secrets_audit.log"
    "logs/budget_spend.log"
  )
  for pattern in "${required_patterns[@]}"; do
    if grep -qF "$pattern" "$GITIGNORE" 2>/dev/null; then
      ok ".gitignore contem: $pattern"
    else
      fail ".gitignore falta: $pattern"
      if $FIX_MODE; then
        echo "$pattern" >> "$GITIGNORE"
        fix "Adicionado '$pattern' ao .gitignore"
      fi
    fi
  done
fi

# =============================================================================
# 3. VAZAMENTO DE SECRETS EM ARQUIVOS COMMITAVEIS
# =============================================================================
header "3/7 Scan de secrets em arquivos commitaveis"

LEAK_PATTERNS='sk-ant-|sk-proj-|sk-[a-zA-Z0-9]{20,}|xai-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|github_pat_|AIzaSy[a-zA-Z0-9_-]{33}'
LEAK_COUNT=0

while IFS= read -r f; do
  rel="${f#"$REPO_ROOT"/}"
  # Pular arquivos binarios, .git, secrets/, logs/, node_modules
  [[ "$rel" == .git/* ]] && continue
  [[ "$rel" == secrets/* ]] && continue
  [[ "$rel" == logs/* ]] && continue
  [[ "$rel" == node_modules/* ]] && continue
  [[ "$rel" == .install-answers.env ]] && continue

  if grep -qE "$LEAK_PATTERNS" "$f" 2>/dev/null; then
    fail "Possivel secret em: $rel"
    grep -nE "$LEAK_PATTERNS" "$f" 2>/dev/null | head -3 | while read -r line; do
      echo -e "       ${DIM}$line${RESET}"
    done
    ((LEAK_COUNT++))
  fi
done < <(find "$REPO_ROOT" -type f -name "*.sh" -o -name "*.py" -o -name "*.md" \
  -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.toml" \
  -o -name "*.cfg" -o -name "*.conf" -o -name "*.txt" 2>/dev/null)

[[ $LEAK_COUNT -eq 0 ]] && ok "Nenhum secret detectado em arquivos commitaveis"

# =============================================================================
# 4. SYSTEMD HARDENING
# =============================================================================
header "4/7 Systemd service hardening"

SERVICE_FILE="$HOME/.config/systemd/user/agent-heartbeat.service"
SERVICE_TPL="$REPO_ROOT/systemd/agent-heartbeat.service.tpl"

# Checar o service instalado ou o template
TARGET_SVC=""
if [[ -f "$SERVICE_FILE" ]]; then
  TARGET_SVC="$SERVICE_FILE"
elif [[ -f "$SERVICE_TPL" ]]; then
  TARGET_SVC="$SERVICE_TPL"
fi

if [[ -n "$TARGET_SVC" ]]; then
  svc_label="$(basename "$TARGET_SVC")"
  HARDENING_DIRECTIVES=(
    "PrivateTmp=yes"
    "NoNewPrivileges=yes"
    "ProtectSystem=strict"
    "UMask=0077"
  )

  for directive in "${HARDENING_DIRECTIVES[@]}"; do
    key="${directive%%=*}"
    if grep -q "$key" "$TARGET_SVC" 2>/dev/null; then
      ok "$svc_label: $directive"
    else
      warn "$svc_label: falta $directive"
      if $FIX_MODE && [[ "$TARGET_SVC" == "$SERVICE_TPL" ]]; then
        # Adicionar antes do ultimo TimeoutStartSec ou no final do [Service]
        if grep -q "TimeoutStartSec" "$TARGET_SVC"; then
          sed -i "/TimeoutStartSec/i $directive" "$TARGET_SVC"
        else
          echo "$directive" >> "$TARGET_SVC"
        fi
        fix "Adicionado $directive em $svc_label"
      fi
    fi
  done
else
  info "Nenhum service systemd encontrado (ok se nao e Linux ou nao instalou ainda)"
fi

# =============================================================================
# 5. SUPRESSAO DE HTTP LOGGERS
# =============================================================================
header "5/7 Supressao de HTTP loggers (prevencao de vazamento em logs)"

# Procurar arquivos Python que fazem HTTP requests mas nao suprimem loggers
PYTHON_FILES_WITH_HTTP=()
while IFS= read -r f; do
  if grep -qE 'import (httpx|requests|urllib3|httpcore)' "$f" 2>/dev/null || \
     grep -qE 'from (httpx|requests|urllib3|httpcore)' "$f" 2>/dev/null; then
    PYTHON_FILES_WITH_HTTP+=("$f")
  fi
done < <(find "$REPO_ROOT" -name "*.py" -not -path "*/venv/*" -not -path "*/.venv/*" \
  -not -path "*/node_modules/*" 2>/dev/null)

# Verificar tambem scripts que usam openai/anthropic SDK (que usam httpx internamente)
while IFS= read -r f; do
  if grep -qE 'import (openai|anthropic)' "$f" 2>/dev/null || \
     grep -qE 'from (openai|anthropic)' "$f" 2>/dev/null; then
    PYTHON_FILES_WITH_HTTP+=("$f")
  fi
done < <(find "$REPO_ROOT" -name "*.py" -not -path "*/venv/*" -not -path "*/.venv/*" \
  -not -path "*/node_modules/*" 2>/dev/null)

# Remover duplicatas
readarray -t PYTHON_FILES_WITH_HTTP < <(printf '%s\n' "${PYTHON_FILES_WITH_HTTP[@]}" | sort -u)

if [[ ${#PYTHON_FILES_WITH_HTTP[@]} -eq 0 ]]; then
  info "Nenhum arquivo Python com HTTP requests encontrado"
else
  for f in "${PYTHON_FILES_WITH_HTTP[@]}"; do
    rel="${f#"$REPO_ROOT"/}"
    if grep -q 'getLogger.*httpx\|getLogger.*httpcore\|getLogger.*urllib3\|HTTP_LOGGERS\|_suppress_http_loggers\|httpx.*WARNING\|httpcore.*WARNING' "$f" 2>/dev/null; then
      ok "$rel: HTTP loggers suprimidos"
    else
      warn "$rel: HTTP loggers NAO suprimidos — tokens podem vazar em URLs logadas"
      echo -e "       ${DIM}Adicione no inicio do arquivo:${RESET}"
      echo -e "       ${DIM}for _lib in ('httpx','httpcore','urllib3','requests'):${RESET}"
      echo -e "       ${DIM}    logging.getLogger(_lib).setLevel(logging.WARNING)${RESET}"
    fi
  done
fi

# =============================================================================
# 6. JOURNAL / LOG SANITIZATION
# =============================================================================
header "6/7 Verificacao de secrets em logs do sistema"

# Checar se journalctl tem tokens vazados
if command -v journalctl &>/dev/null; then
  JOURNAL_LEAKS=0
  for pattern in "sk-ant-" "sk-proj-" "xai-" "ghp_" "github_pat_"; do
    count=$(journalctl --user --no-pager -q 2>/dev/null | grep -c "$pattern" 2>/dev/null || echo 0)
    if [[ "$count" -gt 0 ]]; then
      fail "journalctl contem $count ocorrencias de '$pattern'"
      ((JOURNAL_LEAKS += count))
    fi
  done
  if [[ $JOURNAL_LEAKS -eq 0 ]]; then
    ok "Nenhum secret encontrado no journalctl do usuario"
  else
    warn "Total: $JOURNAL_LEAKS vazamentos no journal. Para limpar:"
    echo -e "       ${DIM}sudo journalctl --rotate && sudo journalctl --vacuum-time=1s${RESET}"
  fi
else
  info "journalctl nao disponivel (ok se nao e Linux)"
fi

# Checar logs locais
if [[ -d "$REPO_ROOT/logs" ]]; then
  LOG_LEAKS=0
  while IFS= read -r f; do
    rel="${f#"$REPO_ROOT"/}"
    for pattern in "sk-ant-" "sk-proj-" "xai-" "ghp_" "github_pat_" "Bearer sk-"; do
      count=$(grep -c "$pattern" "$f" 2>/dev/null || echo 0)
      if [[ "$count" -gt 0 ]]; then
        fail "$rel: contem $count ocorrencias de '$pattern'"
        ((LOG_LEAKS += count))
      fi
    done
  done < <(find "$REPO_ROOT/logs" -type f -name "*.log" 2>/dev/null)
  [[ $LOG_LEAKS -eq 0 ]] && ok "Nenhum secret encontrado em logs locais"
fi

# =============================================================================
# 7. UMASK E AMBIENTE
# =============================================================================
header "7/7 Ambiente de execucao"

# Verificar umask
CURRENT_UMASK=$(umask)
if [[ "$CURRENT_UMASK" == "0077" ]] || [[ "$CURRENT_UMASK" == "077" ]]; then
  ok "umask: $CURRENT_UMASK (restritivo)"
elif [[ "$CURRENT_UMASK" == "0022" ]] || [[ "$CURRENT_UMASK" == "022" ]]; then
  warn "umask: $CURRENT_UMASK (padrao — arquivos criados serao legiveis por outros usuarios)"
  echo -e "       ${DIM}Considere: umask 0077 no seu .bashrc/.zshrc${RESET}"
else
  info "umask: $CURRENT_UMASK"
fi

# Verificar se heartbeat.sh seta umask
HB_SCRIPT="$REPO_ROOT/heartbeat.sh"
[[ ! -f "$HB_SCRIPT" ]] && HB_SCRIPT="$REPO_ROOT/templates/heartbeat.sh.tpl"
if [[ -f "$HB_SCRIPT" ]]; then
  if grep -q 'umask 0077\|umask 077' "$HB_SCRIPT" 2>/dev/null; then
    ok "heartbeat.sh: define umask 0077"
  else
    warn "heartbeat.sh: nao define umask — arquivos criados durante heartbeat podem ficar expostos"
    if $FIX_MODE; then
      # Adicionar umask logo apos set -euo pipefail
      if grep -q 'set -euo pipefail' "$HB_SCRIPT"; then
        sed -i '/set -euo pipefail/a umask 0077' "$HB_SCRIPT"
        fix "Adicionado 'umask 0077' em heartbeat.sh"
      fi
    fi
  fi
fi

# SSH hardening (apenas informativo)
if [[ -f /etc/ssh/sshd_config ]]; then
  if grep -qE '^\s*PasswordAuthentication\s+no' /etc/ssh/sshd_config 2>/dev/null; then
    ok "SSH: PasswordAuthentication no"
  else
    warn "SSH: PasswordAuthentication pode estar habilitado"
    echo -e "       ${DIM}Recomendado: PasswordAuthentication no em /etc/ssh/sshd_config${RESET}"
  fi
fi

# Pre-commit hook para secrets
if [[ -d "$REPO_ROOT/.git" ]]; then
  HOOK="$REPO_ROOT/.git/hooks/pre-commit"
  if [[ -f "$HOOK" ]] && grep -q 'secret\|credential\|api.key\|sk-ant' "$HOOK" 2>/dev/null; then
    ok "Pre-commit hook: detecta secrets"
  else
    warn "Pre-commit hook: nao detecta secrets"
    if $FIX_MODE; then
      mkdir -p "$REPO_ROOT/.git/hooks"
      cat > "$HOOK" << 'HOOKEOF'
#!/usr/bin/env bash
# Pre-commit hook: bloqueia commit de secrets
PATTERNS='sk-ant-|sk-proj-|OPENAI_API_KEY=.sk-|xai-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|github_pat_'

if git diff --cached --diff-filter=ACMR -z --name-only | \
   xargs -0 grep -lE "$PATTERNS" 2>/dev/null | \
   grep -vE '^(secrets/|\.install-answers\.env|logs/)'; then
  echo ""
  echo "BLOQUEADO: Possivel secret detectado nos arquivos acima."
  echo "Se for intencional, use: git commit --no-verify"
  echo ""
  exit 1
fi
HOOKEOF
      chmod +x "$HOOK"
      fix "Pre-commit hook instalado"
    fi
  fi
fi

# =============================================================================
# RELATORIO FINAL
# =============================================================================
echo ""
echo -e "${BOLD}━━━  Relatorio  ━━━${RESET}"
echo ""
echo -e "  ${GREEN}PASS:${RESET}     verificacoes OK"
echo -e "  ${RED}FAIL:${RESET}     $ISSUES problemas encontrados"
echo -e "  ${YELLOW}WARN:${RESET}     $WARNINGS avisos"
if $FIX_MODE; then
  echo -e "  ${GREEN}FIX:${RESET}      $FIXED correcoes aplicadas"
fi
echo ""

if [[ $ISSUES -gt 0 ]] && ! $FIX_MODE && ! $CHECK_ONLY; then
  echo -e "  Para corrigir automaticamente: ${BOLD}bash scripts/harden.sh --fix${RESET}"
  echo ""
fi

if [[ $ISSUES -gt 0 ]]; then
  exit 1
else
  echo -e "  ${GREEN}Agente seguro.${RESET}"
  exit 0
fi
