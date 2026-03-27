#!/usr/bin/env bash
# secrets_setup.sh — Setup de credenciais para o agent-template
#
# Uso:
#   bash secrets_setup.sh                           # setup inicial (_shared)
#   bash secrets_setup.sh new negocia_ai            # criar experiments/negocia_ai/secrets.yaml
#   bash secrets_setup.sh new negocia_ai /caminho   # usar diretório customizado
#   bash secrets_setup.sh status                    # verificar estado geral
#   bash secrets_setup.sh status experiments/negocia_ai

set -e
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SECRETS_DIR="$REPO_ROOT/secrets"
TOOLS_DIR="$REPO_ROOT/tools"
EXP_ROOT="$REPO_ROOT/experiments"
SHARED_TEMPLATE="$SECRETS_DIR/_shared.template.yaml"
EXP_TEMPLATE="$REPO_ROOT/secrets.template.yaml"

ok()   { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*"; }
info() { echo "  · $*"; }
err()  { echo "  ✗ $*" >&2; }
sep()  { echo "  ──────────────────────────────────────────────────"; }
banner() {
    echo
    echo "  ┌──────────────────────────────────────────────────┐"
    printf "  │  %-48s│\n" "$1"
    echo "  └──────────────────────────────────────────────────┘"
}

check_perms() {
    local FILE="$1"
    local MODE
    MODE=$(stat -c '%a' "$FILE" 2>/dev/null || stat -f '%OLp' "$FILE" 2>/dev/null || echo "?")
    if [ "$MODE" = "600" ]; then
        ok "Permissão correta: $(basename $FILE) (600)"
    else
        warn "Permissão incorreta: $(basename $FILE) ($MODE) — execute: chmod 600 \"$FILE\""
    fi
}

ensure_gitignore() {
    local GI="$REPO_ROOT/.gitignore"
    local CHANGED=0
    [ -f "$GI" ] || touch "$GI"
    add() { grep -qF "$1" "$GI" || { printf '\n%s' "$1" >> "$GI"; CHANGED=1; }; }

    add "# Credenciais — NUNCA commitar"
    add "secrets/_shared.yaml"
    # Ignorar secrets.yaml em qualquer subdiretório de experiments/
    add "experiments/*/secrets.yaml"
    # Mas não ignorar o template na raiz
    add "!secrets.template.yaml"
    add "logs/secrets_audit.log"
    add "logs/budget_spend.log"

    [ $CHANGED -eq 1 ] && ok ".gitignore atualizado" || ok ".gitignore já correto"
}

# ─────────────────────────────────────────────
# SETUP INICIAL
# ─────────────────────────────────────────────

cmd_setup() {
    banner "Secrets Setup — agent-template"
    echo

    for f in "$SHARED_TEMPLATE" "$EXP_TEMPLATE"; do
        [ -f "$f" ] || { err "Template não encontrado: $f"; exit 1; }
    done

    mkdir -p "$SECRETS_DIR" "$EXP_ROOT" "$REPO_ROOT/logs"
    chmod 700 "$SECRETS_DIR"
    ok "Diretórios: secrets/ (700)  experiments/  logs/"

    ensure_gitignore

    # Instalar loader em tools/
    if [ -d "$TOOLS_DIR" ] && [ -f "$REPO_ROOT/secrets_loader.py" ]; then
        cp "$REPO_ROOT/secrets_loader.py" "$TOOLS_DIR/secrets_loader.py"
        ok "secrets_loader.py instalado em tools/"
    fi

    # Criar _shared.yaml
    local SHARED="$SECRETS_DIR/_shared.yaml"
    if [ -f "$SHARED" ]; then
        info "_shared.yaml já existe — preservado"
    else
        cp "$SHARED_TEMPLATE" "$SHARED"
        chmod 600 "$SHARED"
        ok "_shared.yaml criado"
    fi

    # Injetar variáveis de ambiente em _shared.yaml
    echo
    info "Verificando variáveis de ambiente..."
    _inject_env "$SHARED" "OPENAI_API_KEY"    "openai"    "api_key"
    _inject_env "$SHARED" "XAI_API_KEY"       "xai"       "api_key"
    _inject_env "$SHARED" "EXA_API_KEY"       "exa"       "api_key"

    check_perms "$SHARED"

    echo
    sep
    banner "Próximos passos"
    echo
    echo "  1. Preencha as chaves compartilhadas (LLMs, busca):"
    echo "       nano secrets/_shared.yaml"
    echo
    echo "  2. Crie o diretório de cada experimento com seu secrets.yaml:"
    echo "       bash secrets_setup.sh new negocia_ai"
    echo "       bash secrets_setup.sh new recruta_ai"
    echo
    echo "  3. Verifique:"
    echo "       bash secrets_setup.sh status"
    echo "       python tools/secrets_loader.py list"
    echo
}

_inject_env() {
    local FILE="$1" VAR="$2" SECTION="$3" KEY="$4"
    [ -z "${!VAR}" ] && { info "$VAR não encontrado no ambiente"; return; }
    # Substituição segura: só linha com o KEY vazio dentro da seção
    ESCAPED=$(printf '%s' "${!VAR}" | sed 's/[&/\]/\\&/g')
    sed -i.bak "/^\s*$KEY:\s*\"\"/{s|$KEY: \"\"|$KEY: \"$ESCAPED\"|}g" "$FILE" 2>/dev/null \
        && rm -f "$FILE.bak"
    ok "$VAR → injetado em $SECTION.$KEY"
}

# ─────────────────────────────────────────────
# NOVO EXPERIMENTO
# ─────────────────────────────────────────────

cmd_new() {
    local SLUG="$1"
    local CUSTOM_DIR="$2"   # opcional: diretório customizado

    [ -z "$SLUG" ] && {
        err "Informe o slug. Ex: bash secrets_setup.sh new negocia_ai"
        exit 1
    }

    # Validar slug
    echo "$SLUG" | grep -qE '^[a-z][a-z0-9_]*$' || {
        err "Slug inválido: '$SLUG'. Use snake_case minúsculo. Ex: negocia_ai"
        exit 1
    }

    # Determinar diretório do experimento
    if [ -n "$CUSTOM_DIR" ]; then
        EXP_DIR="$CUSTOM_DIR"
    else
        EXP_DIR="$EXP_ROOT/$SLUG"
    fi

    banner "Novo experimento: $SLUG"
    echo
    info "Diretório: $EXP_DIR"
    echo

    [ -f "$EXP_TEMPLATE" ] || { err "Template não encontrado: $EXP_TEMPLATE"; exit 1; }

    # Criar diretório do experimento
    mkdir -p "$EXP_DIR"
    ok "Diretório criado: $EXP_DIR"

    # Criar business.md vazio se não existir
    if [ ! -f "$EXP_DIR/business.md" ]; then
        cat > "$EXP_DIR/business.md" << EOF
# business.md — $SLUG

> Preencha este arquivo com as informações do negócio.
> Veja o template em docs/business.template.md para a estrutura completa.
EOF
        ok "business.md criado (esqueleto)"
    else
        info "business.md já existe — preservado"
    fi

    # Criar secrets.yaml
    local TARGET="$EXP_DIR/secrets.yaml"
    if [ -f "$TARGET" ]; then
        warn "secrets.yaml já existe em $EXP_DIR — não sobrescrevendo"
        info "Para recriar: rm \"$TARGET\" && bash secrets_setup.sh new $SLUG"
    else
        cp "$EXP_TEMPLATE" "$TARGET"
        # Preencher slug e started_at automaticamente
        STARTED=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")
        sed -i.bak \
            -e "s|slug: \"\"|slug: \"$SLUG\"|" \
            -e "s|started_at: \"\"|started_at: \"$STARTED\"|" \
            "$TARGET" && rm -f "$TARGET.bak"
        chmod 600 "$TARGET"
        ok "secrets.yaml criado em $EXP_DIR"
    fi

    check_perms "$TARGET"

    # Verificar .gitignore para este diretório
    _ensure_exp_gitignore "$EXP_DIR"

    echo
    sep
    echo
    echo "  Preencha as credenciais específicas deste negócio:"
    echo "    nano \"$TARGET\""
    echo
    echo "  Campos mínimos para começar:"
    echo "    experiment.name              ← Ex: \"Negocia.ai\""
    echo "    ads.meta.ad_account_id       ← act_XXXXXXXXXX"
    echo "    ads.meta.access_token        ← token de longa duração"
    echo "    ads.meta.pixel_id            ← ID do seu Meta Pixel"
    echo
    echo "  Quando pronto para gastos reais:"
    echo "    experiment.active: true"
    echo
    echo "  Verificar:"
    echo "    python tools/secrets_loader.py status experiments/$SLUG"
    echo
}

_ensure_exp_gitignore() {
    local EXP_DIR="$1"
    # O gitignore da raiz já cobre experiments/*/secrets.yaml
    # Adicionar .gitignore local no diretório do experimento como segunda linha de defesa
    local LOCAL_GI="$EXP_DIR/.gitignore"
    if [ ! -f "$LOCAL_GI" ]; then
        cat > "$LOCAL_GI" << 'EOF'
# Credenciais locais — NUNCA commitar
secrets.yaml
*.key
*.pem
.env
EOF
        ok ".gitignore local criado em $(basename $EXP_DIR)/"
    fi
}

# ─────────────────────────────────────────────
# STATUS
# ─────────────────────────────────────────────

cmd_status() {
    local TARGET="$1"
    local PY
    PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo "")

    if [ -n "$PY" ]; then
        LOADER=""
        [ -f "$TOOLS_DIR/secrets_loader.py" ] && LOADER="$TOOLS_DIR/secrets_loader.py"
        [ -z "$LOADER" ] && [ -f "$REPO_ROOT/secrets_loader.py" ] && LOADER="$REPO_ROOT/secrets_loader.py"

        if [ -n "$LOADER" ]; then
            if [ -n "$TARGET" ]; then
                $PY "$LOADER" status "$TARGET"
            else
                $PY "$LOADER" status-all
            fi
            return
        fi
    fi

    # Fallback sem Python
    warn "Python não encontrado — status simplificado:"
    echo
    echo "  Arquivo shared:"
    local SHARED="$SECRETS_DIR/_shared.yaml"
    if [ -f "$SHARED" ]; then
        MODE=$(stat -c '%a' "$SHARED" 2>/dev/null || stat -f '%OLp' "$SHARED" 2>/dev/null || echo "?")
        echo "  ✓ secrets/_shared.yaml  (perm: $MODE)"
    else
        echo "  ✗ secrets/_shared.yaml  (não encontrado)"
    fi
    echo
    echo "  Experimentos em experiments/:"
    if [ -d "$EXP_ROOT" ]; then
        for dir in "$EXP_ROOT"/*/; do
            [ -d "$dir" ] || continue
            SLUG="$(basename $dir)"
            SEC="$dir/secrets.yaml"
            if [ -f "$SEC" ]; then
                MODE=$(stat -c '%a' "$SEC" 2>/dev/null || stat -f '%OLp' "$SEC" 2>/dev/null || echo "?")
                ACTIVE=$(grep -o 'active: true' "$SEC" 2>/dev/null || echo "active: false")
                printf "  ✓ %-20s  secrets.yaml (perm: %s)  %s\n" "$SLUG" "$MODE" "$ACTIVE"
            else
                printf "  ⚠ %-20s  sem secrets.yaml\n" "$SLUG"
            fi
        done
    fi
}

# ─────────────────────────────────────────────
# DISPATCH
# ─────────────────────────────────────────────

CMD="${1:-setup}"
ARG1="${2:-}"
ARG2="${3:-}"

case "$CMD" in
    setup)  cmd_setup ;;
    new)    cmd_new    "$ARG1" "$ARG2" ;;
    status) cmd_status "$ARG1" ;;
    help|--help|-h)
        echo
        echo "  Uso: bash secrets_setup.sh [COMANDO] [ARGUMENTOS]"
        echo
        echo "  Comandos:"
        echo "    setup                           Setup inicial (_shared.yaml, .gitignore)"
        echo "    new <slug> [dir]                Cria experiments/<slug>/secrets.yaml"
        echo "    status                          Estado de todos os experimentos"
        echo "    status experiments/<slug>       Estado de um experimento específico"
        echo
        echo "  Exemplos:"
        echo "    bash secrets_setup.sh"
        echo "    bash secrets_setup.sh new negocia_ai"
        echo "    bash secrets_setup.sh new recruta_ai /custom/path/recruta_ai"
        echo "    bash secrets_setup.sh status experiments/negocia_ai"
        echo
        ;;
    *)
        err "Comando desconhecido: '$CMD'"
        echo "  Use: bash secrets_setup.sh help"
        exit 1
        ;;
esac
