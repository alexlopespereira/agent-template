#!/bin/bash
# =============================================================================
# feedback.sh — Relaya feedback humano para um agente via blog chat
# Uso:
#   feedback.sh AGENT_DIR "mensagem de feedback"
#   feedback.sh /home/alex/Projects/business-experiments/parceiro_ai "ok, foca em SEO"
#
# O feedback e postado no blog chat do agente. O proximo heartbeat
# detecta a mensagem e libera o gate automaticamente.
# =============================================================================

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Uso: feedback.sh AGENT_DIR \"mensagem\""
  echo ""
  echo "Exemplo:"
  echo "  feedback.sh /home/alex/Projects/business-experiments/parceiro_ai \"aprovado\""
  exit 1
fi

AGENT_DIR="$1"
MESSAGE="$2"

if [ ! -d "$AGENT_DIR" ]; then
  echo "Erro: diretorio '$AGENT_DIR' nao existe"
  exit 1
fi

# Load blog config
BRANDING_FILE="$HOME/edge/config/branding.yaml"
BLOG_PORT=8766
BLOG_AUTH_USER=""
BLOG_AUTH_PASS=""
BLOG_AUTH_ENABLED=false

# Try agent-specific branding first, then global
for bf in "$AGENT_DIR/config/branding.yaml" "$BRANDING_FILE"; do
  if [ -f "$bf" ]; then
    BLOG_PORT=$(grep '^  port:' "$bf" 2>/dev/null | head -1 | awk '{print $2}')
    BLOG_AUTH_ENABLED=$(grep '^  auth_enabled:' "$bf" 2>/dev/null | head -1 | awk '{print $2}')
    BLOG_AUTH_USER=$(grep '^  auth_user:' "$bf" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"')
    BLOG_AUTH_PASS=$(grep '^  auth_pass:' "$bf" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"')
    break
  fi
done
BLOG_PORT=${BLOG_PORT:-8766}

# Build curl auth
CURL_AUTH=""
if [ "$BLOG_AUTH_ENABLED" = "true" ] && [ -n "$BLOG_AUTH_USER" ]; then
  CURL_AUTH="-u ${BLOG_AUTH_USER}:${BLOG_AUTH_PASS}"
fi

# Post to blog chat
PAYLOAD=$(MESSAGE="$MESSAGE" python3 -c "
import json, os
print(json.dumps({'from': 'operator', 'message': os.environ['MESSAGE']}))
" 2>/dev/null)

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "http://localhost:${BLOG_PORT}/api/chat" \
  $CURL_AUTH \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" 2>/dev/null)

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "201" ]; then
  echo "Feedback enviado para blog chat (porta $BLOG_PORT)"

  # Show gate status
  GATE_FILE="$AGENT_DIR/state/human-gate.json"
  if [ -f "$GATE_FILE" ]; then
    echo "Gate ativo — sera liberado no proximo heartbeat timer"
  fi
else
  echo "Erro ao enviar feedback (HTTP $HTTP_CODE)"
  echo "  Blog server rodando em localhost:$BLOG_PORT?"
  echo "  Resposta: $BODY"
  exit 1
fi
