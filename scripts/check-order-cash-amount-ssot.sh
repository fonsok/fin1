#!/usr/bin/env bash
# Fails if order cash / quantity-cap code reintroduces briefPrice/subscriptionRatio inflation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FORBIDDEN_RE='pricePerSecurity[[:space:]]*/[[:space:]]*(Double\([[:space:]]*)?subscriptionRatio'

SCAN_PATHS=(
  FIN1/Shared/Services/InvestmentQuantityCalculationService.swift
  FIN1/Shared/Services/InvestmentQuantityCalculation
  FIN1/Features/Trader/Services/SecuritiesValueCalculator.swift
  FIN1/Features/Trader/Services/BuyOrderPlacementService.swift
  FIN1/Features/Trader/Services/BuyOrderInvestmentCalculator.swift
)

echo "=== Order cash SSOT guard ==="

failed=0
for rel in "${SCAN_PATHS[@]}"; do
  if [[ ! -e "$rel" ]]; then
    continue
  fi
  if [[ -d "$rel" ]]; then
    while IFS= read -r hit; do
      [[ -z "$hit" ]] && continue
      echo "FORBIDDEN (brief/subscriptionRatio in cash path): $hit"
      failed=1
    done < <(grep -RInE "$FORBIDDEN_RE" "$rel" 2>/dev/null || true)
  else
    while IFS= read -r hit; do
      [[ -z "$hit" ]] && continue
      echo "FORBIDDEN (brief/subscriptionRatio in cash path): $hit"
      failed=1
    done < <(grep -nE "$FORBIDDEN_RE" "$rel" 2>/dev/null || true)
  fi
done

required=(
  FIN1/Shared/Services/InvestmentQuantityCalculationService.swift
  FIN1/Features/Trader/Services/SecuritiesValueCalculator.swift
  FIN1/Features/Trader/Services/BuyOrderPlacementService.swift
)
for rel in "${required[@]}"; do
  if ! grep -q 'OrderCashAmount' "$rel"; then
    echo "MISSING OrderCashAmount usage in $rel"
    failed=1
  fi
done

if [[ "$failed" -ne 0 ]]; then
  echo ""
  echo "See Documentation/ORDER_CASH_AMOUNT_SSOT.md and FIN1/Shared/Services/OrderCashAmount.swift"
  exit 1
fi

echo "OK: order cash paths use OrderCashAmount SSOT (no subscription-ratio price inflation)."
