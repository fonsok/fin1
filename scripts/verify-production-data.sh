#!/bin/bash
# ============================================================================
# FIN1 Production Data Verification Script
# ============================================================================
#
# Purpose: Verify that all required data is present before going live.
#
# Usage: ./scripts/verify-production-data.sh [--tunnel]
#
# ============================================================================

# Configuration
if [[ "$1" == "--tunnel" ]]; then
    PARSE_URL="http://localhost:1338/parse"
    echo "🔗 Using SSH tunnel: $PARSE_URL"
else
    PARSE_URL="http://192.168.178.24/parse"
    echo "🔗 Using LAN: $PARSE_URL"
fi

APP_ID="fin1-app-id"
FAILED=0
PASSED=0

echo ""
echo "=============================================="
echo "🔍 FIN1 Production Data Verification"
echo "=============================================="
echo ""

# Helper function
check_pass() { echo "✅ $1"; ((PASSED++)); }
check_fail() { echo "❌ $1"; ((FAILED++)); }

# ============================================================================
# 1. Parse Server Health
# ============================================================================
echo "📡 1. Parse Server Health"
echo "----------------------------------------"

if curl -sS --connect-timeout 5 "$PARSE_URL/health" 2>/dev/null | grep -q '"status":"ok"'; then
    check_pass "Parse Server is healthy"
else
    check_fail "Parse Server is NOT healthy"
fi
echo ""

# ============================================================================
# 2. Legal Documents
# ============================================================================
echo "📜 2. Legal Documents (TermsContent)"
echo "----------------------------------------"

# Terms (DE)
TERMS=$(curl -sS --connect-timeout 5 "$PARSE_URL/classes/TermsContent" \
    -H "X-Parse-Application-Id: $APP_ID" 2>/dev/null)

if echo "$TERMS" | grep -q '"documentType":"terms"'; then
    check_pass "Terms exists"
else
    check_fail "Terms NOT found"
fi

if echo "$TERMS" | grep -q '"documentType":"privacy"'; then
    check_pass "Privacy Policy exists"
else
    check_fail "Privacy Policy NOT found"
fi

if echo "$TERMS" | grep -q '"documentType":"imprint"'; then
    check_pass "Imprint exists"
else
    check_fail "Imprint NOT found"
fi

if echo "$TERMS" | grep -q '"documentHash":"[a-f0-9]'; then
    check_pass "Documents have documentHash"
else
    check_fail "Documents missing documentHash"
fi
echo ""

# ============================================================================
# 3. FAQ Data
# ============================================================================
echo "❓ 3. FAQ Data"
echo "----------------------------------------"

FAQ_CAT=$(curl -sS --connect-timeout 5 "$PARSE_URL/classes/FAQCategory" \
    -H "X-Parse-Application-Id: $APP_ID" 2>/dev/null)

if echo "$FAQ_CAT" | grep -q '"showOnLanding":true'; then
    check_pass "FAQCategory (landing) exists"
else
    check_fail "FAQCategory (landing) NOT found"
fi

FAQ_ITEMS=$(curl -sS --connect-timeout 5 "$PARSE_URL/classes/FAQItem" \
    -H "X-Parse-Application-Id: $APP_ID" 2>/dev/null)

if echo "$FAQ_ITEMS" | grep -q '"showOnLanding":true'; then
    check_pass "FAQItem (landing) exists"
else
    check_fail "FAQItem (landing) NOT found"
fi
echo ""

# ============================================================================
# 4. Security (CLPs)
# ============================================================================
echo "🔒 4. Security (CLP Verification)"
echo "----------------------------------------"

CONSENT=$(curl -sS --connect-timeout 5 "$PARSE_URL/classes/LegalConsent?limit=1" \
    -H "X-Parse-Application-Id: $APP_ID" 2>/dev/null)

if echo "$CONSENT" | grep -q '"error"'; then
    check_pass "LegalConsent is protected (not public)"
else
    check_fail "LegalConsent is PUBLIC (security risk!)"
fi

COMPLIANCE=$(curl -sS --connect-timeout 5 "$PARSE_URL/classes/ComplianceEvent?limit=1" \
    -H "X-Parse-Application-Id: $APP_ID" 2>/dev/null)

if echo "$COMPLIANCE" | grep -q '"error"'; then
    check_pass "ComplianceEvent is protected (not public)"
else
    check_fail "ComplianceEvent is PUBLIC (security risk!)"
fi
echo ""

# ============================================================================
# Summary
# ============================================================================
echo "=============================================="
echo "📊 Summary: $PASSED passed, $FAILED failed"
echo "=============================================="

if [[ $FAILED -gt 0 ]]; then
    echo "❌ VERIFICATION FAILED - Fix issues before production!"
    exit 1
else
    echo "✅ ALL CHECKS PASSED - Ready for production!"
    exit 0
fi
