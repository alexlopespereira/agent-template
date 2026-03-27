#!/bin/bash
# playwright-auth.sh — Autenticação delegada para browser automation
# O humano autentica UMA vez, o agente reutiliza a sessão indefinidamente.
#
# Uso: playwright-auth.sh <service-name> <url>
# Ex:  playwright-auth.sh shopify "https://admin.shopify.com"
#      playwright-auth.sh salesforce "https://login.salesforce.com"
#      playwright-auth.sh registrobr "https://registro.br"

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Uso: playwright-auth.sh <service-name> <url>"
  echo "Ex:  playwright-auth.sh shopify \"https://admin.shopify.com\""
  exit 1
fi

SERVICE="$1"
URL="$2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_DIR="$SCRIPT_DIR/../secrets/playwright-state"
STATE_FILE="$STATE_DIR/$SERVICE.json"

mkdir -p "$STATE_DIR"

# Garantir que o diretório está no .gitignore
GITIGNORE="$SCRIPT_DIR/../.gitignore"
if [[ -f "$GITIGNORE" ]] && ! grep -qF "secrets/playwright-state/" "$GITIGNORE" 2>/dev/null; then
  echo "secrets/playwright-state/" >> "$GITIGNORE"
fi

if [[ -f "$STATE_FILE" ]]; then
  echo "━━━  Sessão existente: $SERVICE  ━━━"
  echo ""
  echo "Sessão salva em: $STATE_FILE"
  echo "Última modificação: $(stat -c '%y' "$STATE_FILE" 2>/dev/null || stat -f '%Sm' "$STATE_FILE" 2>/dev/null)"
  echo ""
  echo "Opções:"
  echo "  --reauth    Deletar sessão e re-autenticar"
  echo "  (sem flag)  Abrir navegador com sessão existente"
  echo ""

  if [[ "${3:-}" == "--reauth" ]]; then
    rm -f "$STATE_FILE"
    echo "Sessão removida. Re-autenticando..."
  else
    echo "Abrindo $URL com sessão salva..."
    npx playwright open --load-storage="$STATE_FILE" "$URL"
    exit $?
  fi
fi

echo "━━━  Autenticação: $SERVICE  ━━━"
echo ""
echo "Um navegador será aberto em: $URL"
echo ""
echo "  1. Faça login normalmente (incluindo 2FA se necessário)"
echo "  2. Navegue até confirmar que está autenticado"
echo "  3. Feche o navegador para salvar a sessão"
echo ""
echo "A sessão (cookies, localStorage) será salva automaticamente."
echo ""

npx playwright open --save-storage="$STATE_FILE" "$URL"

if [[ -f "$STATE_FILE" ]]; then
  chmod 600 "$STATE_FILE"
  echo ""
  echo "✓  Sessão '$SERVICE' salva em $STATE_FILE"
  echo "   O agente pode agora operar autonomamente neste serviço."
else
  echo ""
  echo "✗  Falha ao salvar sessão. O navegador foi fechado antes de salvar?"
  exit 1
fi
