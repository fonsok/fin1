#!/bin/bash
# ============================================================================
# FIN1 Security Hardening Checklist
# ============================================================================
#
# Dieses Script prüft kritische Sicherheitskonfigurationen.
# Sollte regelmäßig (vor Prod-Deploys) ausgeführt werden.
#
# Dokumentation: Documentation/FIN1_APP_DOCS/09_ADMIN_ROLES_SEPARATION.md
#
# Nutzung:
#   ./scripts/security-hardening-checklist.sh        # Lokale Prüfung
#   ./scripts/security-hardening-checklist.sh remote # Prüfung auf Server
#
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    FAILED=$((FAILED + 1))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ============================================================================
header "FIN1 Security Hardening Checklist"
# ============================================================================

echo "Datum: $(date)"
echo "Host: $(hostname)"
echo ""

# ============================================================================
header "1. Git & Secrets"
# ============================================================================

# Check if .env is in .gitignore
if grep -q "\.env" .gitignore 2>/dev/null; then
    pass ".env ist in .gitignore"
else
    fail ".env fehlt in .gitignore!"
fi

# Check if backend/.env exists locally (should NOT in repo)
if [ -f "backend/.env" ]; then
    warn "backend/.env existiert lokal - sicherstellen, dass nicht committed!"
else
    pass "backend/.env nicht im lokalen Repo vorhanden"
fi

# Check for secrets in code
echo ""
info "Prüfe auf hartcodierte Secrets..."
FOUND_SECRETS=$(grep -r "masterKey\s*=" --include="*.swift" --include="*.js" . 2>/dev/null | grep -v "node_modules" | grep -v ".git" | grep -v "// " | head -5)
if [ -n "$FOUND_SECRETS" ]; then
    echo "$FOUND_SECRETS"
    warn "Mögliche hartcodierte Master Keys gefunden - bitte prüfen!"
else
    pass "Keine hartcodierten Master Keys in Swift/JS Code"
fi

# ============================================================================
header "2. Parse Dashboard Sicherheit"
# ============================================================================

# Check env.example for default passwords
if [ -f "backend/env.example" ]; then
    if grep -q "admin123" backend/env.example; then
        warn "env.example enthält Default-Passwort 'admin123' - OK für Template, aber in Prod ändern!"
    fi

    if grep -q "CHANGE-THIS" backend/env.example; then
        pass "env.example enthält 'CHANGE-THIS' Hinweise"
    fi
fi

# Check documentation for SSH tunnel requirement
if grep -q "SSH.*Tunnel\|SSH-Tunnel" Documentation/FIN1_APP_DOCS/09_ADMIN_ROLES_SEPARATION.md 2>/dev/null; then
    pass "SSH-Tunnel Dokumentation vorhanden"
else
    warn "SSH-Tunnel Anforderung sollte dokumentiert sein"
fi

# ============================================================================
header "3. Docker & Container Sicherheit"
# ============================================================================

if [ -f "docker-compose.yml" ]; then
    # Check if ports are bound to localhost
    if grep -q "127.0.0.1:" docker-compose.yml; then
        pass "Einige Ports sind auf localhost beschränkt"
    else
        warn "Prüfen: Sind alle internen Ports auf localhost gebunden?"
    fi

    # Check for exposed MongoDB port (only check ports: section, not environment variables)
    MONGO_PORT_LINE=$(grep -A1 "mongodb:" docker-compose.yml | grep -A5 "ports:" | grep -E "27017|27018" | head -1)
    if [ -n "$MONGO_PORT_LINE" ]; then
        if echo "$MONGO_PORT_LINE" | grep -q "127.0.0.1"; then
            pass "MongoDB Port-Binding sicher (localhost only)"
        elif echo "$MONGO_PORT_LINE" | grep -q "0.0.0.0"; then
            fail "MongoDB Port ist ÖFFENTLICH (0.0.0.0) - Sicherheitsrisiko!"
        else
            # Check if it's just "port:port" without IP binding (also public)
            if echo "$MONGO_PORT_LINE" | grep -qE '^\s*-\s*"[0-9]+:[0-9]+"'; then
                warn "MongoDB Port könnte öffentlich sein (kein IP-Binding)"
            else
                pass "MongoDB Port-Binding OK"
            fi
        fi
    fi
fi

# ============================================================================
header "4. Code-Qualität & Linting"
# ============================================================================

# Check if SwiftLint config exists
if [ -f ".swiftlint.yml" ]; then
    pass "SwiftLint Konfiguration vorhanden"
else
    warn "SwiftLint Konfiguration fehlt"
fi

# Check if pre-commit hook exists
if [ -f ".git/hooks/pre-commit" ] || [ -f ".githooks/pre-commit" ]; then
    pass "Pre-commit Hook vorhanden"
else
    warn "Pre-commit Hook fehlt - './scripts/install-githooks.sh' ausführen"
fi

# ============================================================================
header "5. Compliance & Audit"
# ============================================================================

# Check for audit logging in cloud functions
if grep -q "AuditLog" backend/parse-server/cloud/functions/*.js 2>/dev/null; then
    pass "Audit Logging in Cloud Functions implementiert"
else
    warn "Audit Logging in Cloud Functions prüfen"
fi

# Check for 4-eyes principle
if grep -q "FourEyes\|four.?eyes\|4.?eyes" backend/parse-server/cloud/functions/*.js 2>/dev/null; then
    pass "4-Augen-Prinzip in Cloud Functions implementiert"
else
    warn "4-Augen-Prinzip prüfen"
fi

# Check for delete protection
if grep -q "cannot be deleted\|delete.*forbidden" backend/parse-server/cloud/triggers/*.js 2>/dev/null; then
    pass "Delete-Protection für Audit-Klassen vorhanden"
else
    warn "Delete-Protection für ComplianceEvent, LegalConsent etc. prüfen"
fi

# ============================================================================
header "6. Role-Based Access Control"
# ============================================================================

# Check for permissions module
if [ -f "backend/parse-server/cloud/utils/permissions.js" ]; then
    pass "Permissions-Modul vorhanden"

    # Check for role differentiation
    if grep -q "customer_service\|compliance" backend/parse-server/cloud/utils/permissions.js; then
        pass "Rollen-Differenzierung implementiert"
    else
        warn "Rollen-Differenzierung prüfen"
    fi
else
    fail "Permissions-Modul fehlt!"
fi

# ============================================================================
header "7. Dokumentation"
# ============================================================================

# Check for admin roles documentation
if [ -f "Documentation/FIN1_APP_DOCS/09_ADMIN_ROLES_SEPARATION.md" ]; then
    pass "Admin-Rollen Dokumentation vorhanden"
else
    warn "Admin-Rollen Dokumentation sollte erstellt werden"
fi

# Check for RACI matrix
if grep -q "RACI" Documentation/FIN1_APP_DOCS/09_ADMIN_ROLES_SEPARATION.md 2>/dev/null; then
    pass "RACI-Matrix dokumentiert"
else
    warn "RACI-Matrix sollte dokumentiert werden"
fi

# ============================================================================
header "Zusammenfassung"
# ============================================================================

echo ""
echo -e "Ergebnis:"
echo -e "  ${GREEN}Bestanden:${NC}  $PASSED"
echo -e "  ${RED}Fehler:${NC}     $FAILED"
echo -e "  ${YELLOW}Warnungen:${NC} $WARNINGS"
echo ""

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ACHTUNG: $FAILED kritische Probleme gefunden!                      ║${NC}"
    echo -e "${RED}║  Diese sollten vor einem Production-Deploy behoben werden.     ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    exit 1
elif [ $WARNINGS -gt 3 ]; then
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  Mehrere Warnungen - bitte prüfen vor Production-Deploy.       ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Security Check bestanden!                                      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    exit 0
fi
