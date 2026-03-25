#!/usr/bin/env bash
# shellcheck disable=SC2154
# SC2154: Variables assigned dynamically via printf -v in prompt_choice/prompt_with_default
# =============================================================================
# install.sh — Instalador Interativo do Agente Autônomo Claude
# Repositório template: https://github.com/alexlopespereira/agent-template
# =============================================================================
# USO:
#   curl -fsSL https://raw.githubusercontent.com/alexlopespereira/agent-template/main/install.sh | bash
#   ou: git clone ... && cd repo && bash install.sh
# =============================================================================

set -euo pipefail


# ─────────────────────────────────────────────────────────────────────────────
# SEÇÃO 1 — CONSTANTES E HELPERS
# ─────────────────────────────────────────────────────────────────────────────

TEMPLATE_REPO="alexlopespereira/agent-template"
INSTALL_DIR=""
ANSWERS_FILE=""
LOG=""

# Cores (degradam graciosamente se terminal não suportar)
if [[ -t 1 ]] && tput colors &>/dev/null && [[ $(tput colors) -ge 8 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; RESET=''
fi

info()    { echo -e "${BLUE}ℹ${RESET}  $*"; }
success() { echo -e "${GREEN}✓${RESET}  $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET}  $*"; }
error()   { echo -e "${RED}✗${RESET}  $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}━━━  $*  ━━━${RESET}\n"; }
ask()     { echo -e "${BOLD}?${RESET}  $1"; }

# Lê resposta com default
prompt_with_default() {
  local var_name="$1" prompt="$2" default="$3"
  ask "$prompt"
  [[ -n "$default" ]] && echo -e "    ${YELLOW}[default: $default]${RESET}"
  read -r -p "    › " value
  value="${value:-$default}"
  printf -v "$var_name" '%s' "$value"
}

# Lê secret (sem echo)
prompt_secret() {
  local var_name="$1" prompt="$2"
  ask "$prompt"
  read -r -s -p "    › " value
  echo ""
  printf -v "$var_name" '%s' "$value"
}

# Lê texto longo via $EDITOR
prompt_multiline() {
  local var_name="$1" prompt="$2" tmpfile
  tmpfile=$(mktemp /tmp/agent-prompt.XXXXXX.md)
  ask "$prompt"
  echo -e "    ${YELLOW}(o editor abrirá — salve e feche para continuar)${RESET}"
  cat > "$tmpfile" << 'EDITOREOF'
# Escreva o prompt do heartbeat abaixo desta linha.
# Linhas começando com # serão ignoradas.
# Exemplo: "Verifique tarefas pendentes, atualize estado e execute a próxima ação prioritária."

EDITOREOF
  ${EDITOR:-nano} "$tmpfile"
  local content
  content=$(grep -v '^#' "$tmpfile" | sed '/./,$!d' | head -100)
  printf -v "$var_name" '%s' "$content"
  rm -f "$tmpfile"
}

# Menu de seleção numerada
prompt_choice() {
  local var_name="$1" prompt="$2"; shift 2
  local options=("$@")
  ask "$prompt"
  for i in "${!options[@]}"; do
    echo -e "    ${BOLD}$((i+1)).${RESET} ${options[$i]}"
  done
  local choice
  while true; do
    read -r -p "    › " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      printf -v "$var_name" '%s' "${options[$((choice-1))]}"
      break
    fi
    warn "Escolha um número entre 1 e ${#options[@]}"
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# SEÇÃO 2 — VERIFICAÇÃO DE PRÉ-REQUISITOS
# ─────────────────────────────────────────────────────────────────────────────

check_prerequisites() {
  header "Verificando pré-requisitos"

  local missing=()

  # Claude Code
  if command -v claude &>/dev/null; then
    success "Claude Code: $(claude --version 2>/dev/null | head -1)"
  else
    missing+=("Claude Code (npm install -g @anthropic-ai/claude-code)")
  fi

  # GitHub CLI
  GITHUB_USER=""
  if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    GITHUB_USER=$(gh api user --jq .login 2>/dev/null || echo "")
    success "GitHub CLI: autenticado como $GITHUB_USER"
  else
    warn "GitHub CLI não autenticado — algumas funcionalidades serão limitadas"
  fi

  # Python
  if command -v python3 &>/dev/null; then
    success "Python: $(python3 --version)"
  else
    missing+=("Python 3 (https://python.org)")
  fi

  # git
  if command -v git &>/dev/null; then
    success "Git: $(git --version)"
  else
    missing+=("git")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Pré-requisitos faltando:\n$(printf '  - %s\n' "${missing[@]}")"
  fi

  # Detectar OS
  OS="linux"
  if [[ "$OSTYPE" == "darwin"* ]]; then OS="macos"
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then OS="windows"
  fi
  success "Sistema operacional: $OS"
}

# ─────────────────────────────────────────────────────────────────────────────
# SEÇÃO 3 — CLONE OU USO LOCAL
# ─────────────────────────────────────────────────────────────────────────────

clone_or_use_local() {
  # Se já estamos dentro do repo clonado, usar o diretório atual
  if [[ -f "./PLACEHOLDER_MANIFEST.md" ]] || [[ -f "./templates/CLAUDE.md.tpl" ]]; then
    INSTALL_DIR="$(cd . && pwd)"
    info "Usando repositório local: $INSTALL_DIR"
  else
    header "Destino da instalação"

    prompt_choice install_mode "Onde instalar o agente?" \
      "Criar novo repositório (clone do template)" \
      "Instalar em um repositório local existente"

    if [[ "$install_mode" == *"existente"* ]]; then
      # ── Instalar em repo existente ──────────────────────────────────────
      local target_dir
      prompt_with_default target_dir \
        "Caminho absoluto do repositório existente:" \
        ""
      [[ -z "$target_dir" ]] && error "Caminho não pode ser vazio."
      target_dir="${target_dir%/}"  # remove trailing slash

      # Expandir ~ se presente
      target_dir="${target_dir/#\~/$HOME}"

      [[ -d "$target_dir" ]] || error "Diretório não encontrado: $target_dir"

      INSTALL_DIR="$target_dir"
      info "Destino: $INSTALL_DIR"

      # Detectar localização do template (onde está este install.sh)
      local template_dir
      template_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

      if [[ ! -f "$template_dir/PLACEHOLDER_MANIFEST.md" ]]; then
        error "Não foi possível localizar o diretório do template em: $template_dir"
      fi

      info "Copiando arquivos do template para o repositório existente..."

      # Copiar estrutura do template, sem sobrescrever .git e preservando
      # arquivos que já existem no destino (com opção de merge)
      local items_to_copy=(
        templates config scripts tools docs blog memory systemd secrets tasks
        .claude models.env.example .env.example
        PLACEHOLDER_MANIFEST.md ANALYZE_ARTIFACTS.md REPLICATION_BLUEPRINT.md
        PROMPT_D_PREINSTALL.md autoresearch_config.yaml autoresearch.md
      )

      local copied=0 skipped=0
      for item in "${items_to_copy[@]}"; do
        local src="$template_dir/$item"
        [[ -e "$src" ]] || continue

        if [[ -d "$src" ]]; then
          # Diretórios: copiar conteúdo recursivamente sem sobrescrever
          # rsync -a --ignore-existing preserva arquivos existentes
          if command -v rsync &>/dev/null; then
            rsync -a --ignore-existing "$src/" "$INSTALL_DIR/$item/"
          else
            cp -rn "$src" "$INSTALL_DIR/$item" 2>/dev/null || \
              cp -r "$src" "$INSTALL_DIR/$item"
          fi
          ((copied++))
        else
          # Arquivos: copiar apenas se não existir no destino
          if [[ ! -f "$INSTALL_DIR/$item" ]]; then
            cp "$src" "$INSTALL_DIR/$item"
            ((copied++))
          else
            ((skipped++))
          fi
        fi
      done

      success "$copied itens copiados, $skipped já existentes (preservados)"

    else
      # ── Criar novo repositório (comportamento original) ─────────────────
      local repo_dir_name
      prompt_with_default repo_dir_name \
        "Nome do diretório de instalação:" \
        "meu-agente"

      INSTALL_DIR="$(pwd)/$repo_dir_name"

      if [[ -n "$GITHUB_USER" ]] && gh auth status &>/dev/null 2>&1; then
        info "Criando repositório no GitHub via template..."
        gh repo create "$repo_dir_name" \
          --template "$TEMPLATE_REPO" \
          --private \
          --clone \
          --description "Agente autônomo baseado em Claude Code"
        INSTALL_DIR="$(pwd)/$repo_dir_name"
      else
        info "Clonando template diretamente..."
        git clone "https://github.com/$TEMPLATE_REPO.git" "$INSTALL_DIR"
      fi

      cd "$INSTALL_DIR"
      success "Repositório em: $INSTALL_DIR"
    fi
  fi

  ANSWERS_FILE="$INSTALL_DIR/.install-answers.env"
  LOG="$INSTALL_DIR/install.log"
}

# ─────────────────────────────────────────────────────────────────────────────
# SEÇÃO 4 — INTERROGAÇÃO DO INSTALADOR
# ─────────────────────────────────────────────────────────────────────────────

collect_answers() {
  # Carrega respostas anteriores se houver (permite re-executar)
  if [[ -f "$ANSWERS_FILE" ]]; then
    warn "Arquivo de respostas anterior encontrado."
    prompt_choice reuse_mode "O que fazer?" \
      "Usar respostas anteriores (pular perguntas já respondidas)" \
      "Começar do zero (responder todas novamente)"
    if [[ "$reuse_mode" == *"Usar"* ]]; then
      # shellcheck disable=SC1090
      source "$ANSWERS_FILE"
      return 0
    fi
  fi

  # ── Grupo 1: Identidade do Agente ────────────────────────────────────────
  header "1 / 6  ·  Identidade do Agente"

  prompt_with_default AGENT_NAME \
    "Qual o nome/codinome do seu agente? (letras minúsculas, números e hífens)" \
    ""
  [[ "$AGENT_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || \
    error "Nome inválido. Use apenas letras minúsculas, números e hífens (ex: meu-agente)."

  echo ""
  prompt_with_default CODENAME \
    "Codinome do agente? (Enter para usar '$AGENT_NAME')" \
    "$AGENT_NAME"

  echo ""
  ask "Qual a missão do agente? (1-2 frases que descrevem o que ele deve fazer)"
  read -r -p "    › " AGENT_MISSION
  [[ -z "$AGENT_MISSION" ]] && error "A missão não pode ser vazia."

  echo ""
  prompt_with_default AGENT_BIO \
    "Bio/tagline curta do agente (1 linha, Enter para derivar da missão):" \
    ""
  [[ -z "$AGENT_BIO" ]] && AGENT_BIO="$AGENT_MISSION"

  echo ""
  prompt_with_default AGENT_PERSONA \
    "Tom de voz/persona do agente:" \
    "Direto, técnico e detalhista. Prefere dados concretos a especulação."

  echo ""
  prompt_with_default AGENT_COGNITIVE_PROFILE \
    "Perfil cognitivo do agente:" \
    "Analytical. Decomposes problems, seeks underlying structure."

  echo ""
  prompt_with_default AGENT_DOMAIN \
    "Domínio do negócio? (ex: edtech, fintech, saúde, varejo, governo)" \
    ""
  [[ -z "$AGENT_DOMAIN" ]] && error "O domínio é obrigatório."

  echo ""
  prompt_with_default LANGUAGE \
    "Idioma principal do agente:" \
    "pt-BR"

  # ── Grupo 2: Repositório e Acesso ────────────────────────────────────────
  header "2 / 6  ·  Repositório e Acesso"

  prompt_with_default REPO_OWNER \
    "Usuário/organização no GitHub:" \
    "${GITHUB_USER:-}"
  [[ -z "$REPO_OWNER" ]] && error "REPO_OWNER é obrigatório."

  echo ""
  prompt_with_default REPO_NAME \
    "Nome do repositório (será criado se não existir):" \
    "$AGENT_NAME"
  [[ "$REPO_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || \
    error "Nome de repositório inválido."

  echo ""
  prompt_with_default SKILL_PREFIX \
    "Prefixo dos slash commands? (ex: 'aeita' → /aeita-heartbeat)" \
    "$AGENT_NAME"

  echo ""
  prompt_with_default TOOL_PREFIX \
    "Prefixo das ferramentas CLI? (ex: 'edge' → edge-fontes)" \
    "edge"

  # ── Grupo 3: APIs e Credenciais ───────────────────────────────────────────
  header "3 / 6  ·  APIs e Credenciais"

  info "As chaves serão salvas em secrets/keys.env (gitignored)."
  echo ""

  prompt_secret ANTHROPIC_API_KEY \
    "ANTHROPIC_API_KEY (sk-ant-...):"
  [[ "$ANTHROPIC_API_KEY" =~ ^sk-ant- ]] || \
    error "API key inválida. Deve começar com 'sk-ant-'."

  echo ""
  prompt_secret OPENAI_API_KEY \
    "OPENAI_API_KEY (sk-...) — usada para edge-consult/review-gate:"
  [[ "$OPENAI_API_KEY" =~ ^sk- ]] || \
    error "API key inválida. Deve começar com 'sk-'."

  echo ""
  ask "EXA_API_KEY (deixe vazio para pular):"
  read -r -s -p "    › " EXA_API_KEY
  echo ""
  if [[ -n "$EXA_API_KEY" ]]; then
    success "EXA_API_KEY configurada."
  else
    info "EXA_API_KEY não configurada — funcionalidades de busca Exa desabilitadas."
  fi

  # ── Grupo 4: Heartbeat ────────────────────────────────────────────────────
  header "4 / 6  ·  Heartbeat (Ciclo Autônomo)"

  prompt_choice hb_choice "Com que frequência o agente deve ser ativado automaticamente?" \
    "A cada 30 minutos" \
    "A cada hora (recomendado)" \
    "A cada 2 horas" \
    "Uma vez por dia"

  case "$hb_choice" in
    *"30 minutos"*) HEARTBEAT_INTERVAL="*:0/30";  HEARTBEAT_SECONDS=1800;  SYSTEMD_INTERVAL="30min" ;;
    *"2 horas"*)    HEARTBEAT_INTERVAL="*:0/120";  HEARTBEAT_SECONDS=7200;  SYSTEMD_INTERVAL="2h"    ;;
    *"hora"*)       HEARTBEAT_INTERVAL="hourly";   HEARTBEAT_SECONDS=3600;  SYSTEMD_INTERVAL="1h"    ;;
    *"dia"*)        HEARTBEAT_INTERVAL="daily";    HEARTBEAT_SECONDS=86400; SYSTEMD_INTERVAL="24h"   ;;
  esac

  echo ""
  info "Agora você definirá o prompt enviado ao agente em cada ciclo."
  info "Este é o coração do agente — descreva o que ele deve fazer quando 'acordar'."
  echo ""
  prompt_multiline HEARTBEAT_PROMPT \
    "Prompt do heartbeat (editor abrirá):"

  [[ -z "$HEARTBEAT_PROMPT" ]] && error "O prompt do heartbeat não pode ser vazio."

  # ── Grupo 5: Knowledge Base ───────────────────────────────────────────────
  header "5 / 6  ·  Knowledge Base do Negócio"

  echo -e "  A knowledge base é onde o agente encontra documentos, políticas,"
  echo -e "  vocabulário e contexto específico do seu negócio.\n"
  echo -e "  Exemplos:"
  echo -e "    - Pasta local:   /Users/joao/empresa/docs"
  echo -e "    - Repositório:   https://github.com/empresa/docs.git"
  echo -e "    - URL web:       https://docs.empresa.com\n"

  local kb_valid=false
  while ! $kb_valid; do
    ask "Onde está a knowledge base? (caminho local, URL git ou URL https)"
    read -r -p "    › " KB_PATH

    if [[ "$KB_PATH" =~ ^https?://.*\.git$ ]] || [[ "$KB_PATH" =~ ^git@ ]]; then
      KB_TYPE="git"
      info "Tipo detectado: repositório git. Verificando acesso..."
      if git ls-remote "$KB_PATH" &>/dev/null; then
        success "Repositório git acessível."
        kb_valid=true
      else
        warn "Não foi possível acessar o repositório."
        prompt_choice try_again "O que fazer?" \
          "Tentar outro endereço" \
          "Pular e configurar manualmente depois"
        [[ "$try_again" == *"Pular"* ]] && KB_PATH="CONFIGURE_LATER" && KB_TYPE="manual" && kb_valid=true
      fi

    elif [[ "$KB_PATH" =~ ^https?:// ]]; then
      KB_TYPE="url"
      info "Tipo detectado: URL web. Verificando acesso..."
      if curl -sI --max-time 5 "$KB_PATH" 2>/dev/null | grep -qE "HTTP/[0-9.]+ [23]"; then
        success "URL acessível."
        kb_valid=true
      else
        warn "URL pode não estar acessível."
        prompt_choice try_again "O que fazer?" \
          "Usar mesmo assim" \
          "Tentar outro endereço"
        [[ "$try_again" == *"Usar"* ]] && kb_valid=true
      fi

    elif [[ -d "$KB_PATH" ]] || [[ -f "$KB_PATH" ]]; then
      KB_TYPE="local"
      success "Tipo detectado: caminho local. Existe e é acessível."
      kb_valid=true

    else
      warn "Caminho '$KB_PATH' não encontrado localmente e não parece ser uma URL."
      prompt_choice try_again "O que fazer?" \
        "Tentar outro endereço" \
        "Criar o diretório agora" \
        "Pular e configurar manualmente depois"
      case "$try_again" in
        *"Criar"*)
          mkdir -p "$KB_PATH" && success "Diretório criado: $KB_PATH"
          KB_TYPE="local"; kb_valid=true ;;
        *"Pular"*)
          KB_PATH="CONFIGURE_LATER"; KB_TYPE="manual"; kb_valid=true ;;
      esac
    fi
  done

  echo ""
  prompt_choice kb_refresh_choice "Quando atualizar a knowledge base?" \
    "A cada início de sessão (recomendado para git)" \
    "Uma vez por dia" \
    "Manualmente (eu mesmo atualizo)"

  case "$kb_refresh_choice" in
    *"início"*) KB_REFRESH="on-start" ;;
    *"dia"*)    KB_REFRESH="daily"    ;;
    *"Manual"*) KB_REFRESH="manual"   ;;
  esac

  # ── Grupo 6: Sistema (opcionais com defaults) ─────────────────────────────
  header "6 / 6  ·  Configurações de Sistema"

  prompt_with_default USER_TIMEZONE \
    "Fuso horário:" \
    "America/Sao_Paulo"

  echo ""
  prompt_with_default BLOG_PORT \
    "Porta do servidor web/blog (Enter para 8080, vazio para desativar):" \
    "8080"

  if [[ -n "$BLOG_PORT" ]] && [[ "$BLOG_PORT" != "0" ]]; then
    if ! [[ "$BLOG_PORT" =~ ^[0-9]+$ ]] || (( BLOG_PORT < 1024 || BLOG_PORT > 65535 )); then
      error "Porta inválida. Use um número entre 1024 e 65535."
    fi
    echo ""
    prompt_with_default BLOG_AUTH_USER \
      "Usuário do blog (autenticação básica):" \
      "admin"
    echo ""
    prompt_secret BLOG_AUTH_PASS \
      "Senha do blog:"
  else
    BLOG_AUTH_USER=""
    BLOG_AUTH_PASS=""
  fi

  # ── Valores computados ────────────────────────────────────────────────────
  WORK_DIR="$INSTALL_DIR"
  USER_HOME="$HOME"

  # ── Salvar respostas ──────────────────────────────────────────────────────
  save_answers
}

save_answers() {
  cat > "$ANSWERS_FILE" << ENVEOF
# Respostas do instalador — gerado em $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# NÃO commitar este arquivo (contém secrets)
AGENT_NAME="$AGENT_NAME"
CODENAME="$CODENAME"
AGENT_MISSION=$(printf '%q' "$AGENT_MISSION")
AGENT_BIO=$(printf '%q' "$AGENT_BIO")
AGENT_PERSONA=$(printf '%q' "$AGENT_PERSONA")
AGENT_COGNITIVE_PROFILE=$(printf '%q' "$AGENT_COGNITIVE_PROFILE")
AGENT_DOMAIN="$AGENT_DOMAIN"
LANGUAGE="$LANGUAGE"
REPO_NAME="$REPO_NAME"
REPO_OWNER="$REPO_OWNER"
SKILL_PREFIX="$SKILL_PREFIX"
TOOL_PREFIX="$TOOL_PREFIX"
ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"
OPENAI_API_KEY="$OPENAI_API_KEY"
EXA_API_KEY="$EXA_API_KEY"
HEARTBEAT_INTERVAL="$HEARTBEAT_INTERVAL"
HEARTBEAT_SECONDS="$HEARTBEAT_SECONDS"
SYSTEMD_INTERVAL="$SYSTEMD_INTERVAL"
HEARTBEAT_PROMPT=$(printf '%q' "$HEARTBEAT_PROMPT")
KB_PATH="$KB_PATH"
KB_TYPE="$KB_TYPE"
KB_REFRESH="$KB_REFRESH"
USER_TIMEZONE="$USER_TIMEZONE"
BLOG_PORT="$BLOG_PORT"
BLOG_AUTH_USER="$BLOG_AUTH_USER"
BLOG_AUTH_PASS="$BLOG_AUTH_PASS"
GITHUB_USER="$GITHUB_USER"
WORK_DIR="$WORK_DIR"
USER_HOME="$USER_HOME"
ENVEOF

  chmod 600 "$ANSWERS_FILE"

  # Garantir que .gitignore exclui o arquivo de respostas
  local gitignore="$INSTALL_DIR/.gitignore"
  grep -qxF ".install-answers.env" "$gitignore" 2>/dev/null || \
    echo ".install-answers.env" >> "$gitignore"
}

# ─────────────────────────────────────────────────────────────────────────────
# SEÇÃO 5 — SUBSTITUIÇÃO DE PLACEHOLDERS
# ─────────────────────────────────────────────────────────────────────────────

apply_templates() {
  header "Aplicando configuração"

  local failed=0

  # Processar cada .tpl — incluindo os em subdiretórios (memory/, systemd/)
  while IFS= read -r tpl_file; do
    # Determinar caminho de saída: remove .tpl e faz relativo ao INSTALL_DIR
    local rel_path="${tpl_file#"$INSTALL_DIR"/}"
    local out_rel="${rel_path%.tpl}"
    local out_file="$INSTALL_DIR/$out_rel"

    # Criar diretório se necessário
    mkdir -p "$(dirname "$out_file")"

    # Usar python para substituição segura (HEARTBEAT_PROMPT pode ter newlines)
    if python3 << PYEOF
import os, sys

tpl_path = '''$tpl_file'''
out_path = '''$out_file'''

with open(tpl_path, 'r') as f:
    content = f.read()

placeholders = {
    'AGENT_NAME':              os.environ.get('AGENT_NAME', ''),
    'CODENAME':                os.environ.get('CODENAME', ''),
    'AGENT_MISSION':           os.environ.get('AGENT_MISSION', ''),
    'AGENT_BIO':               os.environ.get('AGENT_BIO', ''),
    'AGENT_PERSONA':           os.environ.get('AGENT_PERSONA', ''),
    'AGENT_COGNITIVE_PROFILE': os.environ.get('AGENT_COGNITIVE_PROFILE', ''),
    'AGENT_DOMAIN':            os.environ.get('AGENT_DOMAIN', ''),
    'LANGUAGE':                os.environ.get('LANGUAGE', 'pt-BR'),
    'REPO_NAME':               os.environ.get('REPO_NAME', ''),
    'REPO_OWNER':              os.environ.get('REPO_OWNER', ''),
    'WORK_DIR':                os.environ.get('WORK_DIR', ''),
    'USER_HOME':               os.environ.get('USER_HOME', ''),
    'SKILL_PREFIX':            os.environ.get('SKILL_PREFIX', ''),
    'TOOL_PREFIX':             os.environ.get('TOOL_PREFIX', 'edge'),
    'ANTHROPIC_API_KEY':       os.environ.get('ANTHROPIC_API_KEY', ''),
    'OPENAI_API_KEY':          os.environ.get('OPENAI_API_KEY', ''),
    'EXA_API_KEY':             os.environ.get('EXA_API_KEY', ''),
    'HEARTBEAT_INTERVAL':      os.environ.get('HEARTBEAT_INTERVAL', 'hourly'),
    'HEARTBEAT_SECONDS':       os.environ.get('HEARTBEAT_SECONDS', '3600'),
    'SYSTEMD_INTERVAL':        os.environ.get('SYSTEMD_INTERVAL', '1h'),
    'HEARTBEAT_PROMPT':        os.environ.get('HEARTBEAT_PROMPT', ''),
    'KB_PATH':                 os.environ.get('KB_PATH', ''),
    'KB_TYPE':                 os.environ.get('KB_TYPE', 'local'),
    'KB_REFRESH':              os.environ.get('KB_REFRESH', 'on-start'),
    'USER_TIMEZONE':           os.environ.get('USER_TIMEZONE', 'America/Sao_Paulo'),
    'BLOG_PORT':               os.environ.get('BLOG_PORT', '8080'),
    'BLOG_AUTH_USER':          os.environ.get('BLOG_AUTH_USER', 'admin'),
    'BLOG_AUTH_PASS':          os.environ.get('BLOG_AUTH_PASS', ''),
    'GITHUB_USER':             os.environ.get('GITHUB_USER', ''),
    'REPO_DIR':                os.environ.get('WORK_DIR', ''),  # alias
}

for key, value in placeholders.items():
    content = content.replace('{{ ' + key + ' }}', value)

with open(out_path, 'w') as f:
    f.write(content)
PYEOF
    then
      success "${out_rel/templates\//}"
    else
      warn "Erro ao processar: $rel_path"
      ((failed++))
    fi
  done < <(find "$INSTALL_DIR" -name "*.tpl" -not -path "*/node_modules/*" -not -name "heartbeat-skill.md.tpl")

  [[ $failed -gt 0 ]] && error "$failed templates falharam."

  # Exportar variáveis para subprocessos
  export AGENT_NAME CODENAME AGENT_MISSION AGENT_BIO AGENT_PERSONA
  export AGENT_COGNITIVE_PROFILE AGENT_DOMAIN LANGUAGE
  export REPO_NAME REPO_OWNER WORK_DIR USER_HOME
  export SKILL_PREFIX TOOL_PREFIX
  export ANTHROPIC_API_KEY OPENAI_API_KEY EXA_API_KEY
  export HEARTBEAT_INTERVAL HEARTBEAT_SECONDS SYSTEMD_INTERVAL HEARTBEAT_PROMPT
  export KB_PATH KB_TYPE KB_REFRESH
  export USER_TIMEZONE BLOG_PORT BLOG_AUTH_USER BLOG_AUTH_PASS GITHUB_USER

  # Tornar scripts executáveis
  chmod +x "$INSTALL_DIR/heartbeat.sh" 2>/dev/null || true
  chmod +x "$INSTALL_DIR/tools/"* 2>/dev/null || true

  # Criar heartbeat skill (heartbeat.sh invoca /{SKILL_PREFIX}-heartbeat)
  # O diretório da skill depende de SKILL_PREFIX, então não pode ser
  # gerado pelo loop genérico de .tpl (que preserva caminhos relativos).
  local skill_dir="$INSTALL_DIR/.claude/skills/${SKILL_PREFIX}-heartbeat"
  local skill_tpl="$INSTALL_DIR/templates/heartbeat-skill.md.tpl"
  if [[ -f "$skill_tpl" ]]; then
    mkdir -p "$skill_dir"
    python3 << PYEOF
import os
with open('$skill_tpl') as f:
    content = f.read()
placeholders = {
    'SKILL_PREFIX': '$SKILL_PREFIX', 'CODENAME': os.environ.get('CODENAME',''),
    'AGENT_DOMAIN': os.environ.get('AGENT_DOMAIN',''),
    'AGENT_MISSION': os.environ.get('AGENT_MISSION',''),
}
for k, v in placeholders.items():
    content = content.replace('{{ ' + k + ' }}', v)
with open('$skill_dir/SKILL.md', 'w') as f:
    f.write(content)
PYEOF
    success "Heartbeat skill criada: .claude/skills/${SKILL_PREFIX}-heartbeat/SKILL.md"
  else
    warn "Template heartbeat-skill.md.tpl não encontrado — skill não criada"
  fi

  # Criar secrets/keys.env
  mkdir -p "$INSTALL_DIR/secrets"
  cat > "$INSTALL_DIR/secrets/keys.env" << KEYSEOF
# API keys — gerado pelo instalador em $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# NÃO commitar este arquivo
ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"
OPENAI_API_KEY="$OPENAI_API_KEY"
EXA_API_KEY="$EXA_API_KEY"
BLOG_AUTH_USER="$BLOG_AUTH_USER"
BLOG_AUTH_PASS="$BLOG_AUTH_PASS"
KEYSEOF
  chmod 600 "$INSTALL_DIR/secrets/keys.env"
  success "secrets/keys.env criado (chmod 600)"

  # Criar diretórios esperados
  mkdir -p "$INSTALL_DIR/logs" "$INSTALL_DIR/reports" "$INSTALL_DIR/blog/entries"
  success "Diretórios criados: logs/, reports/, blog/entries/"
}

# ─────────────────────────────────────────────────────────────────────────────
# SEÇÃO 6 — CONFIGURAR KNOWLEDGE BASE
# ─────────────────────────────────────────────────────────────────────────────

setup_knowledge_base() {
  [[ "$KB_PATH" == "CONFIGURE_LATER" ]] && {
    warn "Knowledge base não configurada. Edite kb.config manualmente."
    return 0
  }

  header "Configurando Knowledge Base"

  if [[ "$KB_TYPE" == "git" ]]; then
    local kb_local_path="$INSTALL_DIR/knowledge-base"
    info "Clonando knowledge base em $kb_local_path..."
    git clone "$KB_PATH" "$kb_local_path" --depth=1 --quiet
    success "Knowledge base clonada em: $kb_local_path"

  elif [[ "$KB_TYPE" == "local" ]]; then
    success "Knowledge base local: $KB_PATH"
    local count
    count=$(find "$KB_PATH" -type f 2>/dev/null | wc -l | tr -d ' ')
    info "$count arquivos encontrados na knowledge base."
  elif [[ "$KB_TYPE" == "url" ]]; then
    success "Knowledge base URL: $KB_PATH"
    info "O agente acessará a URL em runtime."
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SEÇÃO 6b — SETUP DE CREDENCIAIS (SECRETS)
# ─────────────────────────────────────────────────────────────────────────────
#
# Arquitetura de duas camadas:
#   secrets/_shared.yaml          → LLMs, busca, infra (todos os experimentos)
#   experiments/<slug>/secrets.yaml → credenciais específicas do negócio
#
# O secrets_setup.sh orquestra a criação dos arquivos.
# Esta função coleta as credenciais interativamente e as injeta.
# ─────────────────────────────────────────────────────────────────────────────

setup_secrets() {
  header "Configurando Credenciais"

  # Verificar que secrets_setup.sh existe
  local setup_script="$INSTALL_DIR/secrets/secrets_setup.sh"
  if [[ ! -f "$setup_script" ]]; then
    warn "secrets_setup.sh não encontrado em $INSTALL_DIR/secrets/"
    warn "Pulando setup de credenciais. Configure manualmente depois:"
    warn "  bash secrets/secrets_setup.sh"
    return 0
  fi

  # Inicializar estrutura (cria secrets/_shared.yaml, .gitignore, logs/)
  info "Inicializando estrutura de secrets..."
  bash "$setup_script" setup 2>/dev/null || true

  # ── Grupo A: Credenciais de LLM ────────────────────────────────────────────
  header "Credenciais — LLMs"
  echo -e "  ${YELLOW}ANTHROPIC_API_KEY já configurada (coletada anteriormente).${RESET}"
  echo -e "  As demais são opcionais — deixe vazio para pular.\n"

  export ANTHROPIC_API_KEY

  echo ""
  ask "OPENAI_API_KEY (sk-... — deixe vazio para pular):"
  read -r -s -p "    › " OPENAI_API_KEY; echo ""
  export OPENAI_API_KEY

  echo ""
  ask "XAI_API_KEY (xai-... — Grok, para adversarial review — deixe vazio para pular):"
  read -r -s -p "    › " XAI_API_KEY; echo ""
  export XAI_API_KEY

  echo ""
  ask "GOOGLE_API_KEY (AIza... — Gemini — deixe vazio para pular):"
  read -r -s -p "    › " GOOGLE_API_KEY; echo ""
  export GOOGLE_API_KEY

  # ── Grupo B: Busca ──────────────────────────────────────────────────────────
  header "Credenciais — Busca"

  if [[ -z "${EXA_API_KEY:-}" ]]; then
    ask "EXA_API_KEY (exa-... — deixe vazio para pular):"
    read -r -s -p "    › " EXA_API_KEY; echo ""
  else
    echo -e "  ${YELLOW}EXA_API_KEY já configurada (coletada anteriormente).${RESET}"
  fi
  export EXA_API_KEY

  echo ""
  ask "SERPER_API_KEY (serper.dev — deixe vazio para pular):"
  read -r -s -p "    › " SERPER_API_KEY; echo ""
  export SERPER_API_KEY

  # ── Grupo C: Infraestrutura ─────────────────────────────────────────────────
  header "Credenciais — Infraestrutura"

  echo -e "  O agente pode precisar de um GitHub PAT para criar PRs, issues e push autônomo."
  echo ""
  ask "GITHUB_PAT (github_pat_... ou ghp_... — deixe vazio para pular):"
  read -r -s -p "    › " GITHUB_PAT; echo ""
  export GITHUB_PAT

  echo ""
  ask "CLOUDFLARE_API_TOKEN (deixe vazio para pular):"
  read -r -s -p "    › " CLOUDFLARE_API_TOKEN; echo ""
  ask "CLOUDFLARE_ACCOUNT_ID (deixe vazio para pular):"
  read -r -p "    › " CLOUDFLARE_ACCOUNT_ID
  export CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID

  # ── Grupo D: Comunicação ────────────────────────────────────────────────────
  header "Credenciais — Comunicação (Alertas do Agente)"
  echo -e "  Configure para receber notificações do agente no Telegram ou Slack.\n"

  ask "TELEGRAM_BOT_TOKEN (deixe vazio para pular):"
  read -r -s -p "    › " TELEGRAM_BOT_TOKEN; echo ""

  TELEGRAM_CHAT_ID=""
  if [[ -n "$TELEGRAM_BOT_TOKEN" ]]; then
    ask "TELEGRAM_CHAT_ID (ID do chat para receber alertas):"
    read -r -p "    › " TELEGRAM_CHAT_ID
  fi
  export TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID

  echo ""
  ask "SLACK_WEBHOOK_URL (https://hooks.slack.com/... — deixe vazio para pular):"
  read -r -p "    › " SLACK_WEBHOOK_URL
  export SLACK_WEBHOOK_URL

  # ── Injetar no _shared.yaml ─────────────────────────────────────────────────
  header "Injetando credenciais em secrets/_shared.yaml"

  local shared_file="$INSTALL_DIR/secrets/_shared.yaml"
  if [[ ! -f "$shared_file" ]]; then
    warn "_shared.yaml não encontrado após setup"
    warn "Credenciais salvas apenas nas variáveis de ambiente."
    return 0
  fi

  python3 - << 'PYEOF'
import yaml, os, sys
from pathlib import Path
from datetime import datetime, timezone

path = Path(os.environ.get('INSTALL_DIR', '.')) / 'secrets' / '_shared.yaml'
if not path.exists():
    print("  ⚠ _shared.yaml não encontrado")
    sys.exit(0)

with open(path) as f:
    data = yaml.safe_load(f) or {}

def set_if(d, keys, value):
    if not value:
        return
    obj = d
    for k in keys[:-1]:
        obj = obj.setdefault(k, {})
    obj[keys[-1]] = value

env = os.environ
set_if(data, ['llm', 'anthropic',  'api_key'],          env.get('ANTHROPIC_API_KEY', ''))
set_if(data, ['llm', 'openai',     'api_key'],          env.get('OPENAI_API_KEY', ''))
set_if(data, ['llm', 'xai',        'api_key'],          env.get('XAI_API_KEY', ''))
set_if(data, ['llm', 'google',     'api_key'],          env.get('GOOGLE_API_KEY', ''))
set_if(data, ['search', 'exa',     'api_key'],          env.get('EXA_API_KEY', ''))
set_if(data, ['search', 'serper',  'api_key'],          env.get('SERPER_API_KEY', ''))
set_if(data, ['infra', 'github',   'personal_access_token'], env.get('GITHUB_PAT', ''))
set_if(data, ['infra', 'github',   'username'],         env.get('GITHUB_USER', ''))
set_if(data, ['infra', 'cloudflare', 'api_token'],      env.get('CLOUDFLARE_API_TOKEN', ''))
set_if(data, ['infra', 'cloudflare', 'account_id'],     env.get('CLOUDFLARE_ACCOUNT_ID', ''))
set_if(data, ['communication', 'telegram', 'bot_token'],env.get('TELEGRAM_BOT_TOKEN', ''))
set_if(data, ['communication', 'telegram', 'chat_id'],  env.get('TELEGRAM_CHAT_ID', ''))
set_if(data, ['communication', 'slack', 'webhook_url'], env.get('SLACK_WEBHOOK_URL', ''))

data.setdefault('_meta', {})
data['_meta']['last_updated'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
data['_meta']['owner'] = env.get('GITHUB_USER', env.get('REPO_OWNER', ''))

with open(path, 'w') as f:
    yaml.dump(data, f, allow_unicode=True, default_flow_style=False, sort_keys=False)

print("  ✓ _shared.yaml atualizado com as credenciais fornecidas")
PYEOF

  chmod 600 "$shared_file"
  success "secrets/_shared.yaml configurado (600)"

  # ── Experimento inicial (opcional) ──────────────────────────────────────────
  header "Criar Primeiro Experimento? (opcional)"
  echo -e "  Experimentos são projetos de negócio individuais com suas próprias"
  echo -e "  credenciais (Meta Ads, Stripe, Supabase, etc.).\n"
  echo -e "  Você pode criar depois com:  bash secrets/secrets_setup.sh new meu_negocio\n"

  prompt_choice create_exp \
    "Deseja criar um experimento agora?" \
    "Sim — criar experimento inicial" \
    "Não — configurar depois"

  if [[ "$create_exp" == *"Sim"* ]]; then
    echo ""
    ask "Slug do experimento (snake_case, ex: negocia_ai, recruta_ai):"
    read -r -p "    › " EXP_SLUG

    if ! echo "$EXP_SLUG" | grep -qE '^[a-z][a-z0-9_]*$'; then
      warn "Slug inválido. Use snake_case minúsculo. Experimento não criado."
      warn "Crie depois com: bash secrets/secrets_setup.sh new <slug>"
    else
      bash "$setup_script" new "$EXP_SLUG"

      local biz_file="$INSTALL_DIR/experiments/$EXP_SLUG/business.md"
      echo ""
      prompt_choice edit_biz \
        "Abrir business.md para descrever o negócio agora?" \
        "Sim — abrir editor" \
        "Não — preencher depois"

      [[ "$edit_biz" == *"Sim"* ]] && ${EDITOR:-nano} "$biz_file"

      success "Experimento '$EXP_SLUG' criado em experiments/$EXP_SLUG/"
      info "Preencha as credenciais específicas depois:"
      info "  nano experiments/$EXP_SLUG/secrets.yaml"
    fi
  fi

  # ── Verificação final ───────────────────────────────────────────────────────
  echo ""
  info "Verificando secrets..."
  if command -v python3 &>/dev/null && [[ -f "$INSTALL_DIR/secrets/secrets_loader.py" ]]; then
    python3 "$INSTALL_DIR/secrets/secrets_loader.py" status 2>/dev/null || true
  else
    bash "$setup_script" status 2>/dev/null || true
  fi

  success "Setup de secrets concluído"
}

# ─────────────────────────────────────────────────────────────────────────────
# SEÇÃO 7 — ATIVAR HEARTBEAT
# ─────────────────────────────────────────────────────────────────────────────

activate_heartbeat() {
  header "Ativando ciclo autônomo ($OS)"

  prompt_choice activate_now "Ativar o heartbeat automático agora?" \
    "Sim — ativar agora (recomendado)" \
    "Não — ativarei manualmente depois"

  if [[ "$activate_now" == *"Não"* ]]; then
    info "Heartbeat não ativado. Para ativar manualmente:"
    case "$OS" in
      linux)  info "  systemctl --user enable --now agent-heartbeat.timer" ;;
      macos)  info "  launchctl load ~/Library/LaunchAgents/$REPO_OWNER.$AGENT_NAME.heartbeat.plist" ;;
      windows) info "  powershell -File heartbeat.ps1 -Install" ;;
    esac
    return 0
  fi

  case "$OS" in
    linux)
      local service_dir="$HOME/.config/systemd/user"
      mkdir -p "$service_dir"

      if [[ -f "$INSTALL_DIR/systemd/agent-heartbeat.service" ]]; then
        cp "$INSTALL_DIR/systemd/agent-heartbeat.service" "$service_dir/"
        cp "$INSTALL_DIR/systemd/agent-heartbeat.timer" "$service_dir/"
        systemctl --user daemon-reload
        systemctl --user enable --now agent-heartbeat.timer
        success "Heartbeat ativo via systemd"
        info "Status: systemctl --user status agent-heartbeat.timer"
      else
        warn "Arquivos systemd não encontrados. Verifique systemd/"
      fi
      ;;

    macos)
      local plist_dir="$HOME/Library/LaunchAgents"
      mkdir -p "$plist_dir"
      local plist_name="$REPO_OWNER.$AGENT_NAME.heartbeat.plist"
      local plist_src="$INSTALL_DIR/heartbeat.plist"

      if [[ -f "$plist_src" ]]; then
        cp "$plist_src" "$plist_dir/$plist_name"
        if launchctl load "$plist_dir/$plist_name" 2>/dev/null; then
          success "Heartbeat ativo via launchd"
        else
          warn "launchctl load falhou — verifique o plist manualmente"
        fi
      else
        warn "heartbeat.plist não encontrado."
      fi
      ;;

    windows)
      warn "Windows: execute manualmente o PowerShell como administrador:"
      echo "    powershell -File $INSTALL_DIR\\heartbeat.ps1 -Install"
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# SEÇÃO 8 — PUBLICAR NO GITHUB
# ─────────────────────────────────────────────────────────────────────────────

publish_to_github() {
  header "Publicando no GitHub"

  if [[ -z "$GITHUB_USER" ]] || ! gh auth status &>/dev/null 2>&1; then
    warn "GitHub CLI não disponível. Commit e push manual necessários."
    return 0
  fi

  prompt_choice do_publish "Publicar o repositório no GitHub agora?" \
    "Sim — criar repo e push (recomendado)" \
    "Não — farei push manualmente depois"

  if [[ "$do_publish" == *"Não"* ]]; then
    info "Para publicar manualmente:"
    info "  gh repo create $REPO_OWNER/$REPO_NAME --private --source=. --push"
    return 0
  fi

  # Garantir .gitignore seguro (merge se já existir)
  local gitignore_entries
  read -r -d '' gitignore_entries << 'GIEOF' || true
# Secrets e configurações locais — NUNCA commitar
.install-answers.env
.env
*.env
!.env.example
!models.env.example

# Sistema de secrets
secrets/_shared.yaml
experiments/*/secrets.yaml
!secrets/_shared.template.yaml
!secrets/secrets.template.yaml

# Logs
logs/
*.log
!logs/.gitkeep

# Knowledge base clonada localmente
knowledge-base/

# macOS / IDEs
.DS_Store
.idea/
.vscode/

# Python
__pycache__/
*.pyc
*.pyo
venv/
.venv/

# Reports gerados
reports/*.html
GIEOF

  if [[ -f "$INSTALL_DIR/.gitignore" ]]; then
    # Merge: adicionar apenas linhas que ainda não existem
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      grep -qxF "$line" "$INSTALL_DIR/.gitignore" 2>/dev/null || \
        echo "$line" >> "$INSTALL_DIR/.gitignore"
    done <<< "$gitignore_entries"
    info ".gitignore existente atualizado (merge)"
  else
    echo "$gitignore_entries" > "$INSTALL_DIR/.gitignore"
  fi

  # Inicializar git se necessário
  if [[ ! -d "$INSTALL_DIR/.git" ]]; then
    git -C "$INSTALL_DIR" init
    git -C "$INSTALL_DIR" checkout -b main
  fi

  # Verificar se repo já existe
  if gh repo view "$REPO_OWNER/$REPO_NAME" &>/dev/null 2>&1; then
    info "Repositório já existe: github.com/$REPO_OWNER/$REPO_NAME"
    # Garantir remote
    git -C "$INSTALL_DIR" remote get-url origin &>/dev/null 2>&1 || \
      git -C "$INSTALL_DIR" remote add origin "https://github.com/$REPO_OWNER/$REPO_NAME.git"
  else
    info "Criando repositório privado..."
    gh repo create "$REPO_OWNER/$REPO_NAME" --private \
      --description "Agente autônomo: $AGENT_NAME — $AGENT_DOMAIN" \
      --source="$INSTALL_DIR" 2>/dev/null || {
      # Fallback: criar sem --source e adicionar remote
      gh repo create "$REPO_OWNER/$REPO_NAME" --private \
        --description "Agente autônomo: $AGENT_NAME — $AGENT_DOMAIN"
      git -C "$INSTALL_DIR" remote add origin "https://github.com/$REPO_OWNER/$REPO_NAME.git"
    }
  fi

  git -C "$INSTALL_DIR" add -A
  git -C "$INSTALL_DIR" commit -m "feat: install $AGENT_NAME via install.sh

Agent: $AGENT_NAME
Domain: $AGENT_DOMAIN
Heartbeat: $HEARTBEAT_INTERVAL
KB type: $KB_TYPE
OS: $OS" 2>/dev/null || info "Nada a commitar."

  git -C "$INSTALL_DIR" push -u origin main 2>/dev/null || \
    git -C "$INSTALL_DIR" push -u origin master 2>/dev/null || \
    warn "Push falhou — verifique permissões."

  success "Publicado em: https://github.com/$REPO_OWNER/$REPO_NAME"
}

# ─────────────────────────────────────────────────────────────────────────────
# SEÇÃO 8b — SECURITY HARDENING
# ─────────────────────────────────────────────────────────────────────────────

security_hardening() {
  header "Security Hardening"

  info "Aplicando boas praticas de seguranca..."
  echo ""

  # 1. Permissoes restritivas em todos os arquivos sensiveis
  local sensitive_files=(
    "$INSTALL_DIR/secrets/_shared.yaml"
    "$INSTALL_DIR/secrets/keys.env"
    "$INSTALL_DIR/.install-answers.env"
  )
  # Incluir secrets.yaml de experimentos
  while IFS= read -r f; do
    sensitive_files+=("$f")
  done < <(find "$INSTALL_DIR/experiments" -name "secrets.yaml" -type f 2>/dev/null)
  # Incluir todos os .env em secrets/
  while IFS= read -r f; do
    sensitive_files+=("$f")
  done < <(find "$INSTALL_DIR/secrets" -name "*.env" -type f 2>/dev/null)

  for f in "${sensitive_files[@]}"; do
    if [[ -f "$f" ]]; then
      chmod 600 "$f"
    fi
  done
  [[ -d "$INSTALL_DIR/secrets" ]] && chmod 700 "$INSTALL_DIR/secrets"
  success "Permissoes 600 em arquivos de credenciais, 700 em secrets/"

  # 2. Umask no heartbeat
  if [[ -f "$INSTALL_DIR/heartbeat.sh" ]]; then
    if ! grep -q 'umask 0077' "$INSTALL_DIR/heartbeat.sh" 2>/dev/null; then
      sed -i '/set -euo pipefail/a umask 0077  # Security: restringir permissoes de arquivos criados pelo agente' \
        "$INSTALL_DIR/heartbeat.sh" 2>/dev/null || true
      success "umask 0077 adicionado ao heartbeat.sh"
    fi
  fi

  # 3. Pre-commit hook para detectar secrets
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    local hook="$INSTALL_DIR/.git/hooks/pre-commit"
    mkdir -p "$INSTALL_DIR/.git/hooks"
    cat > "$hook" << 'HOOKEOF'
#!/usr/bin/env bash
# Pre-commit hook: bloqueia commit acidental de secrets
PATTERNS='sk-ant-|sk-proj-|ANTHROPIC_API_KEY=.sk-|OPENAI_API_KEY=.sk-|xai-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|github_pat_'

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
    chmod +x "$hook"
    success "Pre-commit hook instalado (bloqueia commit de secrets)"
  fi

  # 4. Hardening de logs sensiveis
  for logfile in "$INSTALL_DIR/logs/secrets_audit.log" "$INSTALL_DIR/logs/budget_spend.log"; do
    if [[ -f "$logfile" ]]; then
      chmod 600 "$logfile"
    fi
  done

  # 5. Proteger branding.yaml se existir
  for branding in "$INSTALL_DIR/config/branding.yaml" "$HOME/edge/config/branding.yaml"; do
    if [[ -f "$branding" ]]; then
      chmod 600 "$branding"
      success "Permissao 600 em $(basename "$(dirname "$branding")")/branding.yaml"
    fi
  done

  # 6. Proteger ~/.claude/settings.json
  if [[ -f "$HOME/.claude/settings.json" ]]; then
    chmod 600 "$HOME/.claude/settings.json"
    success "Permissao 600 em ~/.claude/settings.json"
  fi

  # 7. Executar harden.sh completo se disponivel
  local harden_script="$INSTALL_DIR/scripts/harden.sh"
  if [[ -f "$harden_script" ]]; then
    chmod +x "$harden_script"
    echo ""
    info "Executando verificacao completa de seguranca..."
    bash "$harden_script" --fix 2>/dev/null || true
  fi

  echo ""
  success "Security hardening concluido"
  echo ""
  info "Para verificar seguranca a qualquer momento:"
  info "  bash scripts/harden.sh          # relatorio"
  info "  bash scripts/harden.sh --fix    # corrigir automaticamente"
  info ""
  info "Para rotacionar credenciais:"
  info "  bash scripts/rotate_secrets.sh"
}

# ─────────────────────────────────────────────────────────────────────────────
# SEÇÃO 9 — VALIDAÇÃO E PRIMEIRO HEARTBEAT
# ─────────────────────────────────────────────────────────────────────────────

validate_and_first_run() {
  header "Validação final"

  local ok=true

  # Verificar arquivos essenciais
  for f in CLAUDE.md MEMORY.md heartbeat.sh kb.config; do
    if [[ -f "$INSTALL_DIR/$f" ]]; then
      success "$f: presente"
    else
      warn "$f: AUSENTE"
      ok=false
    fi
  done

  # Verificar que não há placeholders residuais nos arquivos principais
  local residual=0
  for f in CLAUDE.md MEMORY.md heartbeat.sh kb.config; do
    local file="$INSTALL_DIR/$f"
    [[ -f "$file" ]] || continue
    local count
    count=$(grep -c '{{ ' "$file" 2>/dev/null || echo 0)
    residual=$((residual + count))
  done
  if [[ $residual -eq 0 ]]; then
    success "Sem placeholders residuais nos arquivos principais"
  else
    warn "$residual placeholders residuais encontrados (verifique manualmente)"
    grep -rn '{{ ' "$INSTALL_DIR/CLAUDE.md" "$INSTALL_DIR/MEMORY.md" 2>/dev/null | head -5
    ok=false
  fi

  # Verificar que secrets não estão nos arquivos commitáveis
  local leaked=0
  for f in CLAUDE.md MEMORY.md heartbeat.sh kb.config; do
    local file="$INSTALL_DIR/$f"
    [[ -f "$file" ]] || continue
    if grep -qE 'sk-ant-|sk-[a-zA-Z0-9]{20}' "$file" 2>/dev/null; then
      warn "Possível secret em $f!"
      leaked=$((leaked + 1))
    fi
  done
  if [[ $leaked -eq 0 ]]; then
    success "Nenhum secret detectado em arquivos commitáveis"
  fi

  # Testar ANTHROPIC_API_KEY
  info "Testando conexão com Anthropic API..."
  local test_result
  test_result=$(ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" claude -p "respond only: ok" \
    --output-format text 2>/dev/null || echo "FAILED")
  if [[ "$test_result" == *"ok"* ]] || [[ "$test_result" == *"OK"* ]] || [[ "$test_result" == *"Ok"* ]]; then
    success "Conexão Anthropic: OK"
  else
    warn "Teste de conexão Anthropic falhou. Verifique ANTHROPIC_API_KEY."
    ok=false
  fi

  if $ok; then
    echo ""
    prompt_choice run_now "Executar o primeiro ciclo do agente agora?" \
      "Sim — executar agora (recomendado)" \
      "Não — aguardar o próximo ciclo automático"

    if [[ "$run_now" == *"Sim"* ]]; then
      info "Executando primeiro heartbeat..."
      if bash "$INSTALL_DIR/heartbeat.sh" 2>>"$LOG"; then
        success "Primeiro ciclo concluído!"
      else
        warn "Primeiro ciclo falhou. Verifique: $LOG"
      fi
    fi
  else
    warn "Validação com avisos. Revise os itens acima antes de ativar o agente."
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SEÇÃO 10 — SUMÁRIO FINAL
# ─────────────────────────────────────────────────────────────────────────────

print_summary() {
  header "Instalação Concluída"

  echo -e "  ${BOLD}Agente:${RESET}        $AGENT_NAME"
  echo -e "  ${BOLD}Codinome:${RESET}      $CODENAME"
  echo -e "  ${BOLD}Domínio:${RESET}       $AGENT_DOMAIN"
  echo -e "  ${BOLD}Idioma:${RESET}        $LANGUAGE"
  echo -e "  ${BOLD}Repositório:${RESET}   https://github.com/$REPO_OWNER/$REPO_NAME"
  echo -e "  ${BOLD}Heartbeat:${RESET}     $HEARTBEAT_INTERVAL ($HEARTBEAT_SECONDS s)"
  echo -e "  ${BOLD}KB:${RESET}            $KB_PATH ($KB_TYPE, refresh: $KB_REFRESH)"
  echo -e "  ${BOLD}Secrets:${RESET}       secrets/_shared.yaml ($(grep -cE ': .+[a-zA-Z0-9]' "$INSTALL_DIR/secrets/_shared.yaml" 2>/dev/null || echo 0) chaves configuradas)"
  echo -e "  ${BOLD}Diretório:${RESET}     $INSTALL_DIR"
  echo ""
  echo -e "  ${BOLD}Comandos úteis:${RESET}"
  case "$OS" in
    linux)
      echo "    systemctl --user status agent-heartbeat.timer  # ver status"
      echo "    systemctl --user stop agent-heartbeat.timer    # pausar agente"
      echo "    journalctl --user -u agent-heartbeat -f        # logs ao vivo"
      ;;
    macos)
      echo "    launchctl list | grep $AGENT_NAME              # ver status"
      echo "    launchctl unload ~/Library/LaunchAgents/$REPO_OWNER.$AGENT_NAME.heartbeat.plist  # pausar"
      ;;
    windows)
      echo "    Get-ScheduledTask -TaskName '*$AGENT_NAME*'    # ver status"
      ;;
  esac
  echo "    bash $INSTALL_DIR/heartbeat.sh                 # heartbeat manual"
  echo "    cat $INSTALL_DIR/logs/heartbeat.log            # ver logs"
  echo "    cat $INSTALL_DIR/MEMORY.md                     # ver memória"
  echo "    python3 $INSTALL_DIR/secrets/secrets_loader.py status  # ver credenciais"
  echo "    bash $INSTALL_DIR/secrets/secrets_setup.sh new <slug>  # novo experimento"
  echo "    bash $INSTALL_DIR/secrets/secrets_setup.sh status      # status secrets"
  echo ""
  success "Agente $AGENT_NAME instalado e configurado."
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

main() {
  echo -e "\n${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║    Instalador de Agente Autônomo — Claude Code    ║${RESET}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════╝${RESET}\n"

  check_prerequisites
  clone_or_use_local
  collect_answers
  apply_templates
  setup_knowledge_base
  setup_secrets
  security_hardening
  activate_heartbeat
  publish_to_github
  validate_and_first_run
  print_summary
}

main "$@"
