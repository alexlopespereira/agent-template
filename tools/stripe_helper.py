#!/usr/bin/env python3
"""
stripe_helper.py — Wrapper Stripe com metadata automatica por business.

Usa uma conta Stripe unica para todos os experimentos, injetando
metadata.business e metadata.codename em cada objeto criado.

Uso:
    from tools.stripe_helper import StripeHelper

    helper = StripeHelper.from_experiment("experiments/negocia_ai")
    session = helper.create_checkout_session(
        price_id="price_XXXXX",
        success_url="https://negocia.ai/obrigado",
        cancel_url="https://negocia.ai/pricing",
    )
"""

import sys
from pathlib import Path
from typing import Optional

# Garante que tools/ esta no path para importar secrets_loader
_TOOLS_DIR = Path(__file__).parent.resolve()
if str(_TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(_TOOLS_DIR))

try:
    import stripe
except ImportError:
    stripe = None  # type: ignore[assignment]

from secrets_loader import SecretsLoader


class StripeHelper:
    """Wrapper fino sobre a SDK do Stripe com auto-inject de metadata."""

    def __init__(self, loader: SecretsLoader, business: str, codename: str):
        if stripe is None:
            raise ImportError(
                "stripe package not installed. Run: pip install stripe"
            )
        self._loader = loader
        self._business = business
        self._codename = codename

        secret_key = loader.raw("payments.stripe.secret_key")
        stripe.api_key = secret_key

    @classmethod
    def from_experiment(cls, exp_path: "str | Path") -> "StripeHelper":
        """Instancia a partir do diretorio do experimento."""
        loader = SecretsLoader.from_dir(exp_path)
        business = loader.get("experiment.slug", mask=False)
        codename = loader.get("experiment.name", mask=False)
        return cls(loader, business, codename)

    @property
    def business(self) -> str:
        return self._business

    @property
    def codename(self) -> str:
        return self._codename

    def _base_metadata(self, extra: Optional[dict] = None) -> dict:
        meta = {"business": self._business, "codename": self._codename}
        if extra:
            meta.update(extra)
        return meta

    # ── Checkout ──────────────────────────────

    def create_checkout_session(
        self,
        price_id: str,
        success_url: str,
        cancel_url: str,
        mode: str = "subscription",
        metadata: Optional[dict] = None,
        **kwargs,
    ) -> "stripe.checkout.Session":
        return stripe.checkout.Session.create(
            line_items=[{"price": price_id, "quantity": 1}],
            mode=mode,
            success_url=success_url,
            cancel_url=cancel_url,
            metadata=self._base_metadata(metadata),
            **kwargs,
        )

    # ── Payment Links ────────────────────────

    def create_payment_link(
        self,
        price_id: str,
        metadata: Optional[dict] = None,
        **kwargs,
    ) -> "stripe.PaymentLink":
        return stripe.PaymentLink.create(
            line_items=[{"price": price_id, "quantity": 1}],
            metadata=self._base_metadata(metadata),
            **kwargs,
        )

    # ── Customers ─────────────────────────────

    def list_customers(
        self,
        limit: int = 100,
        **kwargs,
    ) -> list:
        """Lista customers filtrados por metadata.business."""
        result = []
        customers = stripe.Customer.search(
            query=f"metadata['business']:'{self._business}'",
            limit=limit,
            **kwargs,
        )
        result.extend(customers.data)
        return result

    def create_customer(
        self,
        email: str,
        name: Optional[str] = None,
        metadata: Optional[dict] = None,
        **kwargs,
    ) -> "stripe.Customer":
        return stripe.Customer.create(
            email=email,
            name=name,
            metadata=self._base_metadata(metadata),
            **kwargs,
        )

    # ── Subscriptions ─────────────────────────

    def list_subscriptions(
        self,
        status: str = "active",
        limit: int = 100,
        **kwargs,
    ) -> list:
        """Lista subscriptions filtradas por metadata.business."""
        result = []
        subs = stripe.Subscription.search(
            query=f"metadata['business']:'{self._business}' AND status:'{status}'",
            limit=limit,
            **kwargs,
        )
        result.extend(subs.data)
        return result
