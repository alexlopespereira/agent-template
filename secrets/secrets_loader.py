#!/usr/bin/env python3
"""
secrets_loader.py — Carregador de credenciais por experimento.

Localização dos arquivos:
    repo_root/
    ├── secrets/
    │   └── _shared.yaml                ← LLMs, busca, infra
    └── experiments/
        ├── negocia_ai/
        │   ├── business.md
        │   └── secrets.yaml            ← credenciais deste negócio
        └── recruta_ai/
            ├── business.md
            └── secrets.yaml

Resolução de chave: busca em <experiment_dir>/secrets.yaml → fallback para secrets/_shared.yaml.

Uso pelos agentes:

    from tools.secrets_loader import SecretsLoader

    # A partir do diretório do experimento
    s = SecretsLoader.from_dir("experiments/negocia_ai")
    account = s.get("ads.meta.ad_account_id")   # lê de experiments/negocia_ai/secrets.yaml
    key     = s.get("llm.anthropic.api_key")    # fallback para secrets/_shared.yaml

    # Ou passando o caminho absoluto
    s = SecretsLoader.from_dir("/home/user/edge/experiments/negocia_ai")

    # Modo shared apenas (sem experimento)
    s = SecretsLoader()
    key = s.get("llm.anthropic.api_key")

    # Verificar antes de gastar
    s.require_active()
    s.check_budget("ads.meta", cost_brl=30.0)
    # ... executar operação ...
    s.record_spend("ads.meta", cost_brl=28.50, description="campanha copy-v2")

CLI:
    python tools/secrets_loader.py list
    python tools/secrets_loader.py status
    python tools/secrets_loader.py status experiments/negocia_ai
    python tools/secrets_loader.py status-all
"""

import json
import logging
import sys
from datetime import date, datetime, timezone
from functools import reduce
from pathlib import Path
from typing import Any, Optional

import yaml

log = logging.getLogger("secrets_loader")

# A raiz do repo é dois níveis acima de tools/secrets_loader.py
_TOOLS_DIR  = Path(__file__).parent.resolve()
_REPO_ROOT  = _TOOLS_DIR.parent.resolve()
_SHARED_FILE = _REPO_ROOT / "secrets" / "_shared.yaml"
_EXP_ROOT   = _REPO_ROOT / "experiments"
_AUDIT_LOG  = _REPO_ROOT / "logs" / "secrets_audit.log"
_SPEND_LOG  = _REPO_ROOT / "logs" / "budget_spend.log"
_SECRETS_FILENAME = "secrets.yaml"


# ─────────────────────────────────────────────
# EXCEÇÕES
# ─────────────────────────────────────────────

class SecretNotFoundError(KeyError):
    pass

class SecretNotConfiguredError(ValueError):
    pass

class BudgetExceededError(RuntimeError):
    pass

class ExperimentInactiveError(RuntimeError):
    pass

class SecretsFileNotFoundError(FileNotFoundError):
    pass


# ─────────────────────────────────────────────
# MASKED VALUE
# ─────────────────────────────────────────────

class _MaskedValue(str):
    """
    Subclasse de str — funciona diretamente em chamadas de API,
    mas mascara o valor em repr/str para evitar vazamento em logs.
    """
    def __new__(cls, value: str, path: str):
        obj = str.__new__(cls, value)
        obj._path = path
        obj._prefix = value[:6] if len(value) >= 6 else value
        return obj

    def __repr__(self):
        return f"***MASKED:{self._path}({self._prefix}...)***"

    def __str__(self):
        return f"***MASKED:{self._path}***"


# ─────────────────────────────────────────────
# LOADER
# ─────────────────────────────────────────────

class SecretsLoader:
    """
    Carrega credenciais para um experimento.

    Instanciar via:
        SecretsLoader.from_dir("experiments/negocia_ai")
        SecretsLoader.from_dir(Path("/abs/path/to/negocia_ai"))
        SecretsLoader()   # somente _shared
    """

    _cache: dict[Path, dict] = {}

    def __init__(
        self,
        exp_dir: Optional[Path] = None,
        shared_file: Optional[Path] = None,
    ):
        self._exp_dir    = exp_dir
        self._shared_file = shared_file or _SHARED_FILE
        self._shared     = self._load_file(self._shared_file)
        self._exp        = {}

        if exp_dir is not None:
            secrets_path = exp_dir / _SECRETS_FILENAME
            if not secrets_path.exists():
                raise SecretsFileNotFoundError(
                    f"Arquivo não encontrado: {secrets_path}\n"
                    f"Crie com:\n"
                    f"  cp secrets.template.yaml {secrets_path}\n"
                    f"  chmod 600 {secrets_path}\n"
                    f"Ou use: bash secrets_setup.sh new {exp_dir.name}"
                )
            self._exp = self._load_file(secrets_path)

    @classmethod
    def from_dir(cls, path: "str | Path", **kwargs) -> "SecretsLoader":
        """
        Instancia a partir do caminho do diretório do experimento.
        Aceita caminho relativo (à raiz do repo) ou absoluto.
        """
        p = Path(path)
        if not p.is_absolute():
            p = _REPO_ROOT / p
        if not p.is_dir():
            raise SecretsFileNotFoundError(
                f"Diretório do experimento não encontrado: {p}\n"
                f"Crie com: bash secrets_setup.sh new {p.name}"
            )
        return cls(exp_dir=p, **kwargs)

    # ── leitura ──────────────────────────────

    def get(self, path: str, mask: bool = True) -> Any:
        """
        Retorna o valor pelo caminho dot-notation.
        Busca em <exp_dir>/secrets.yaml → fallback para secrets/_shared.yaml.

        Raises:
            SecretNotFoundError: caminho não existe em nenhum arquivo.
            SecretNotConfiguredError: campo existe mas está vazio.
        """
        value, source = None, None

        for data, label in [
            (self._exp,    str(self._exp_dir / _SECRETS_FILENAME) if self._exp_dir else None),
            (self._shared, str(self._shared_file)),
        ]:
            if not data or not label:
                continue
            try:
                v = _nested_get(data, path)
                value, source = v, label
                break
            except (KeyError, TypeError):
                continue

        if value is None:
            locs = []
            if self._exp_dir:
                locs.append(str(self._exp_dir / _SECRETS_FILENAME))
            locs.append(str(self._shared_file))
            raise SecretNotFoundError(
                f"Secret '{path}' não encontrado em:\n" +
                "\n".join(f"  - {l}" for l in locs)
            )

        if value == "" or (isinstance(value, str) and not value.strip()):
            raise SecretNotConfiguredError(
                f"Secret '{path}' existe em {source} mas está vazio.\n"
                f"Preencha antes de rodar experimentos reais."
            )

        # Não mascarar valores não-sensitivos
        if isinstance(value, (bool, int, float)):
            return value
        if isinstance(value, str) and _is_non_sensitive(path, value):
            return value

        _audit(path, str(self._exp_dir.name) if self._exp_dir else "_shared")

        return _MaskedValue(value, path) if (mask and isinstance(value, str)) else value

    def raw(self, path: str) -> str:
        """Retorna valor sem máscara. Usar quando a API exige str pura."""
        return self.get(path, mask=False)

    # ── estado ───────────────────────────────

    def is_active(self) -> bool:
        if not self._exp_dir:
            return True
        try:
            return bool(_nested_get(self._exp, "experiment.active"))
        except (KeyError, TypeError):
            return False

    def require_active(self):
        """Levanta ExperimentInactiveError se active: false."""
        if not self.is_active():
            name = self._exp_dir.name if self._exp_dir else "?"
            raise ExperimentInactiveError(
                f"Experimento '{name}' está inativo (active: false).\n"
                f"Edite {self._exp_dir / _SECRETS_FILENAME} → active: true para habilitar gastos reais."
            )

    # ── budget ────────────────────────────────

    def check_budget(self, service_path: str, cost_brl: float):
        """Levanta BudgetExceededError se spent_hoje + cost_brl > daily_budget_brl."""
        try:
            limit = float(self.get(f"{service_path}.daily_budget_brl", mask=False))
        except (SecretNotFoundError, SecretNotConfiguredError):
            log.warning(f"check_budget: '{service_path}.daily_budget_brl' não configurado — pulando.")
            return

        slug  = self._exp_dir.name if self._exp_dir else "_shared"
        key   = f"{slug}.{service_path}"
        spent = _today_spend(key)

        if spent + cost_brl > limit:
            raise BudgetExceededError(
                f"Budget '{service_path}' excedido — '{slug}':\n"
                f"  Gasto hoje:    R${spent:.2f}\n"
                f"  Esta operação: R${cost_brl:.2f}\n"
                f"  Limite diário: R${limit:.2f}"
            )

    def record_spend(self, service_path: str, cost_brl: float, description: str = ""):
        """Registra gasto real. Chamar APÓS a operação ser executada."""
        slug = self._exp_dir.name if self._exp_dir else "_shared"
        _SPEND_LOG.parent.mkdir(exist_ok=True)
        entry = {
            "ts":          datetime.now(timezone.utc).isoformat(),
            "date":        date.today().isoformat(),
            "experiment":  slug,
            "service":     service_path,
            "budget_key":  f"{slug}.{service_path}",
            "cost_brl":    cost_brl,
            "description": description,
        }
        with open(_SPEND_LOG, "a") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    def budget_status(self) -> dict:
        """Status de budget de todos os serviços com daily_budget_brl configurado."""
        merged = {**self._shared}
        _deep_update(merged, self._exp)
        slug = self._exp_dir.name if self._exp_dir else "_shared"
        result = {}
        for svc_path, limit in _find_budget_paths(merged):
            key   = f"{slug}.{svc_path}"
            spent = _today_spend(key)
            pct   = spent / limit * 100 if limit > 0 else 0
            result[svc_path] = {
                "limit_brl":       limit,
                "spent_brl":       round(spent, 2),
                "remaining_brl":   round(limit - spent, 2),
                "utilization_pct": round(pct, 1),
                "status":          "OK" if pct <= 80 else ("WARNING" if pct <= 100 else "EXCEEDED"),
            }
        return result

    # ── validação ────────────────────────────

    def validate(self) -> tuple[bool, list[str]]:
        required = ["llm.anthropic.api_key", "llm.openai.api_key"]
        if self._exp_dir:
            required += ["experiment.name", "experiment.slug"]
        missing = []
        for p in required:
            try:
                self.get(p, mask=False)
            except (SecretNotFoundError, SecretNotConfiguredError):
                missing.append(p)
        return len(missing) == 0, missing

    # ── internos ─────────────────────────────

    @classmethod
    def _load_file(cls, path: Path) -> dict:
        if path in cls._cache:
            return cls._cache[path]
        if not path.exists():
            return {}
        with open(path) as f:
            data = yaml.safe_load(f) or {}
        cls._cache[path] = data
        return data

    @classmethod
    def invalidate_cache(cls):
        cls._cache.clear()


# ─────────────────────────────────────────────
# FUNÇÕES DE MÓDULO
# ─────────────────────────────────────────────

def list_experiments() -> list[dict]:
    """Lista todos os experimentos com secrets.yaml em experiments/."""
    result = []
    if not _EXP_ROOT.is_dir():
        return result
    for exp_dir in sorted(_EXP_ROOT.iterdir()):
        if not exp_dir.is_dir():
            continue
        secrets_path = exp_dir / _SECRETS_FILENAME
        if not secrets_path.exists():
            result.append({"dir": str(exp_dir), "slug": exp_dir.name, "no_secrets": True})
            continue
        try:
            with open(secrets_path) as f:
                data = yaml.safe_load(f) or {}
            exp = data.get("experiment", {})
            result.append({
                "dir":    str(exp_dir),
                "slug":   exp.get("slug", exp_dir.name),
                "name":   exp.get("name", ""),
                "active": exp.get("active", False),
                "url":    exp.get("landing_page_url", ""),
            })
        except Exception as e:
            result.append({"dir": str(exp_dir), "slug": exp_dir.name, "error": str(e)})
    return result


# ─────────────────────────────────────────────
# UTILITÁRIOS PRIVADOS
# ─────────────────────────────────────────────

def _nested_get(data: dict, path: str) -> Any:
    return reduce(lambda d, k: d[k], path.split("."), data)

def _deep_update(base: dict, override: dict):
    for k, v in override.items():
        if isinstance(v, dict) and isinstance(base.get(k), dict):
            _deep_update(base[k], v)
        else:
            base[k] = v

def _is_non_sensitive(path: str, value: str) -> bool:
    safe_keys = {
        "environment", "host", "endpoint", "default_model",
        "from_email", "from_name", "version", "owner", "slug", "name",
        "landing_page_url", "started_at",
    }
    return (
        path.split(".")[-1] in safe_keys or
        value.startswith(("http://", "https://")) or
        value in ("sandbox", "test", "production", "live")
    )

def _audit(path: str, scope: str):
    try:
        _AUDIT_LOG.parent.mkdir(exist_ok=True)
        with open(_AUDIT_LOG, "a") as f:
            f.write(json.dumps({
                "ts": datetime.now(timezone.utc).isoformat(),
                "scope": scope, "path": path,
            }) + "\n")
    except Exception:
        pass

def _today_spend(budget_key: str) -> float:
    if not _SPEND_LOG.exists():
        return 0.0
    today = date.today().isoformat()
    total = 0.0
    with open(_SPEND_LOG) as f:
        for line in f:
            try:
                e = json.loads(line.strip())
                if e.get("date") == today and e.get("budget_key") == budget_key:
                    total += e.get("cost_brl", 0.0)
            except Exception:
                pass
    return total

def _find_budget_paths(data: dict, prefix: str = "") -> list[tuple[str, float]]:
    result = []
    for k, v in data.items():
        if k.startswith("_"):
            continue
        full = f"{prefix}{k}" if prefix else k
        if isinstance(v, dict):
            if "daily_budget_brl" in v:
                result.append((full, float(v["daily_budget_brl"])))
            result.extend(_find_budget_paths(v, full + "."))
    return result


# ─────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────

def _print_status(exp_dir_str: Optional[str]):
    if exp_dir_str:
        p = Path(exp_dir_str)
        if not p.is_absolute():
            p = _REPO_ROOT / p
        label = p.name
        print(f"\n  Experimento: {label}  ({p})")
        try:
            s = SecretsLoader.from_dir(p)
        except SecretsFileNotFoundError as e:
            print(f"  ERRO: {e}\n")
            return
    else:
        print(f"\n  Escopo: _shared  ({_SHARED_FILE})")
        s = SecretsLoader()

    valid, missing = s.validate()
    mark = "✓" if valid else "✗"
    print(f"  {mark} Campos obrigatórios: {'OK' if valid else f'{len(missing)} faltando'}")
    for m in missing:
        print(f"      - {m}")

    if exp_dir_str:
        print(f"  {'✓ ATIVO' if s.is_active() else '○ inativo'}  (experiment.active)")

    budgets = s.budget_status()
    if budgets:
        print("\n  Budget hoje:")
        for svc, info in budgets.items():
            bar  = "█" * int(info["utilization_pct"] / 10) + "░" * (10 - int(info["utilization_pct"] / 10))
            icon = {"OK": "✓", "WARNING": "⚠", "EXCEEDED": "✗"}.get(info["status"], "?")
            print(f"  {icon} {svc:<32} [{bar}]  R${info['spent_brl']:6.2f} / R${info['limit_brl']:6.2f}")


if __name__ == "__main__":
    logging.basicConfig(level=logging.WARNING)
    cmd  = sys.argv[1] if len(sys.argv) > 1 else "status"
    arg2 = sys.argv[2] if len(sys.argv) > 2 else None

    print("╔══════════════════════════════════════════════════╗")
    print("║  Secrets Loader                                   ║")
    print("╚══════════════════════════════════════════════════╝")

    if cmd == "list":
        exps = list_experiments()
        if not exps:
            print(f"\n  Nenhum experimento encontrado em {_EXP_ROOT}")
            print("  Crie com: bash secrets_setup.sh new negocia_ai")
        else:
            print(f"\n  {'SLUG':<20} {'NOME':<24} {'ATIVO':<7} SECRETS")
            print("  " + "─" * 65)
            for e in exps:
                if e.get("no_secrets"):
                    print(f"  {e['slug']:<20} {'—':<24} {'—':<7} ⚠ sem secrets.yaml")
                    continue
                if e.get("error"):
                    print(f"  {e['slug']:<20} erro: {e['error']}")
                    continue
                mark = "✓" if e["active"] else "○"
                print(f"  {e['slug']:<20} {e['name']:<24} {mark:<7} ✓")

    elif cmd == "status-all":
        _print_status(None)
        for exp in list_experiments():
            if not exp.get("no_secrets") and not exp.get("error"):
                print("\n  " + "─" * 50)
                _print_status(exp["dir"])

    elif cmd == "status":
        _print_status(arg2)

    elif cmd == "validate":
        s = SecretsLoader.from_dir(arg2) if arg2 else SecretsLoader()
        valid, _ = s.validate()
        sys.exit(0 if valid else 1)

    else:
        print("  Uso: python tools/secrets_loader.py [list | status [path] | status-all | validate [path]]")

    print()
