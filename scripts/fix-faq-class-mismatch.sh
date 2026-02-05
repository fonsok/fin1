#!/bin/bash
# =============================================================================
# FIN1 FAQ Class Mismatch Fix Script
# =============================================================================
# Problem: Cloud Function used 'FAQ' class but schema/data is in 'FAQItem'
# This script diagnoses and fixes the issue.
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}  FIN1 FAQ Class Mismatch - Diagnosis & Fix          ${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo ""

# Configuration
PARSE_URL="${PARSE_URL:-http://192.168.178.24/parse}"
APP_ID="${APP_ID:-fin1-app-id}"

# Try to load master key from .env if available
if [ -f "/home/io/fin1-server/backend/.env" ]; then
    MASTER_KEY=$(grep -E "^PARSE_SERVER_MASTER_KEY=" /home/io/fin1-server/backend/.env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
elif [ -f "$HOME/fin1-server/backend/.env" ]; then
    MASTER_KEY=$(grep -E "^PARSE_SERVER_MASTER_KEY=" "$HOME/fin1-server/backend/.env" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
fi

if [ -z "$MASTER_KEY" ]; then
    echo -e "${RED}Error: MASTER_KEY not found. Set it via environment or .env file.${NC}"
    echo "Usage: MASTER_KEY=your_key ./fix-faq-class-mismatch.sh"
    exit 1
fi

echo -e "${YELLOW}Configuration:${NC}"
echo "  PARSE_URL: $PARSE_URL"
echo "  APP_ID: $APP_ID"
echo ""

# Helper function to make Parse API calls
parse_query() {
    local class=$1
    local params=${2:-""}
    curl -sS --connect-timeout 10 "$PARSE_URL/classes/$class$params" \
        -H "X-Parse-Application-Id: $APP_ID" \
        -H "X-Parse-Master-Key: $MASTER_KEY" \
        2>/dev/null
}

parse_count() {
    local class=$1
    local result=$(curl -sS --connect-timeout 10 "$PARSE_URL/classes/$class?count=1&limit=0" \
        -H "X-Parse-Application-Id: $APP_ID" \
        -H "X-Parse-Master-Key: $MASTER_KEY" \
        2>/dev/null)
    echo "$result" | grep -o '"count":[0-9]*' | grep -o '[0-9]*' || echo "0"
}

# =============================================================================
# Step 1: Diagnose current state
# =============================================================================
echo -e "${BLUE}Step 1: Diagnosing current state...${NC}"
echo ""

echo -n "  Checking FAQCategory count... "
FAQ_CAT_COUNT=$(parse_count "FAQCategory")
echo -e "${GREEN}$FAQ_CAT_COUNT${NC}"

echo -n "  Checking FAQItem count... "
FAQ_ITEM_COUNT=$(parse_count "FAQItem")
echo -e "${GREEN}$FAQ_ITEM_COUNT${NC}"

echo -n "  Checking FAQ count (wrong class)... "
FAQ_WRONG_COUNT=$(parse_count "FAQ")
echo -e "${YELLOW}$FAQ_WRONG_COUNT${NC}"

echo ""

# =============================================================================
# Step 2: Analyze and decide action
# =============================================================================
echo -e "${BLUE}Step 2: Analysis${NC}"
echo ""

if [ "$FAQ_CAT_COUNT" -eq 0 ]; then
    echo -e "  ${RED}✗ FAQCategory: No categories found${NC}"
    NEED_SEED_CATEGORIES=true
else
    echo -e "  ${GREEN}✓ FAQCategory: $FAQ_CAT_COUNT categories found${NC}"
    NEED_SEED_CATEGORIES=false
fi

if [ "$FAQ_ITEM_COUNT" -eq 0 ] && [ "$FAQ_WRONG_COUNT" -gt 0 ]; then
    echo -e "  ${YELLOW}⚠ Data is in wrong class 'FAQ' ($FAQ_WRONG_COUNT items)${NC}"
    echo -e "  ${YELLOW}  → Need to migrate from FAQ to FAQItem${NC}"
    NEED_MIGRATION=true
elif [ "$FAQ_ITEM_COUNT" -eq 0 ]; then
    echo -e "  ${RED}✗ FAQItem: No items found${NC}"
    NEED_SEED_ITEMS=true
    NEED_MIGRATION=false
else
    echo -e "  ${GREEN}✓ FAQItem: $FAQ_ITEM_COUNT items found${NC}"
    NEED_SEED_ITEMS=false
    NEED_MIGRATION=false
fi

echo ""

# =============================================================================
# Step 3: Perform fixes
# =============================================================================
echo -e "${BLUE}Step 3: Applying fixes...${NC}"
echo ""

# 3a: Migrate data from FAQ to FAQItem if needed
if [ "$NEED_MIGRATION" = true ]; then
    echo -e "  ${YELLOW}Migrating data from FAQ to FAQItem...${NC}"

    # Get all items from FAQ class
    FAQ_DATA=$(parse_query "FAQ" "?limit=1000")

    # Parse and re-insert into FAQItem
    echo "$FAQ_DATA" | python3 -c "
import sys
import json
import urllib.request

data = json.load(sys.stdin)
results = data.get('results', [])

if not results:
    print('  No data to migrate')
    sys.exit(0)

url = '$PARSE_URL/classes/FAQItem'
headers = {
    'X-Parse-Application-Id': '$APP_ID',
    'X-Parse-Master-Key': '$MASTER_KEY',
    'Content-Type': 'application/json'
}

migrated = 0
for item in results:
    # Remove Parse internal fields
    for field in ['objectId', 'createdAt', 'updatedAt', 'ACL']:
        item.pop(field, None)

    req = urllib.request.Request(url, data=json.dumps(item).encode(), headers=headers, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            migrated += 1
    except Exception as e:
        print(f'  Error migrating item: {e}')

print(f'  Migrated {migrated} items from FAQ to FAQItem')
"
    echo ""
fi

# 3b: Seed data if needed (from bundled Swift content)
if [ "$NEED_SEED_CATEGORIES" = true ] || [ "$NEED_SEED_ITEMS" = true ]; then
    echo -e "  ${YELLOW}Seeding FAQ data from bundled content...${NC}"

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(dirname "$SCRIPT_DIR")"

    # Check if we can run the export script
    if [ -f "$REPO_ROOT/scripts/export_faqs_from_swift.py" ]; then
        echo "  Exporting FAQs from Swift sources..."
        python3 "$REPO_ROOT/scripts/export_faqs_from_swift.py" > /tmp/faqs_export.json 2>/dev/null || {
            echo -e "  ${RED}Failed to export FAQs from Swift${NC}"
        }

        if [ -f /tmp/faqs_export.json ] && [ -s /tmp/faqs_export.json ]; then
            echo "  Applying FAQs to Parse..."

            # Set environment for the apply script
            export PARSE_SERVER_APPLICATION_ID="$APP_ID"
            export PARSE_SERVER_MASTER_KEY="$MASTER_KEY"
            export PARSE_SERVER_URL="$PARSE_URL"

            python3 "$REPO_ROOT/scripts/apply_faqs_to_parse.py" --input /tmp/faqs_export.json 2>&1 | head -20
            echo ""
        fi
    else
        echo -e "  ${YELLOW}Export script not found, using minimal seed...${NC}"

        # Create minimal seed data directly
        python3 << 'PYTHON_SEED'
import json
import urllib.request

PARSE_URL = "$PARSE_URL"
APP_ID = "$APP_ID"
MASTER_KEY = "$MASTER_KEY"

headers = {
    'X-Parse-Application-Id': APP_ID,
    'X-Parse-Master-Key': MASTER_KEY,
    'Content-Type': 'application/json'
}

# Minimal FAQ categories
categories = [
    {"slug": "general", "title": "Allgemein", "displayName": "Allgemein", "icon": "questionmark.circle.fill", "sortOrder": 1, "isActive": True, "showOnLanding": True, "showInHelpCenter": True},
    {"slug": "account", "title": "Konto", "displayName": "Konto & Sicherheit", "icon": "person.circle.fill", "sortOrder": 2, "isActive": True, "showOnLanding": True, "showInHelpCenter": True},
    {"slug": "trading", "title": "Trading", "displayName": "Trading", "icon": "chart.line.uptrend.xyaxis", "sortOrder": 3, "isActive": True, "showOnLanding": True, "showInHelpCenter": True},
]

for cat in categories:
    req = urllib.request.Request(f"{PARSE_URL}/classes/FAQCategory", data=json.dumps(cat).encode(), headers=headers, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.load(resp)
            print(f"  Created FAQCategory: {cat['slug']} -> {result.get('objectId')}")
    except Exception as e:
        print(f"  Category {cat['slug']} may already exist: {e}")

print("  Minimal categories seeded")
PYTHON_SEED
    fi
fi

# =============================================================================
# Step 4: Verify fix
# =============================================================================
echo ""
echo -e "${BLUE}Step 4: Verifying fix...${NC}"
echo ""

echo -n "  FAQCategory count: "
NEW_CAT_COUNT=$(parse_count "FAQCategory")
echo -e "${GREEN}$NEW_CAT_COUNT${NC}"

echo -n "  FAQItem count: "
NEW_ITEM_COUNT=$(parse_count "FAQItem")
echo -e "${GREEN}$NEW_ITEM_COUNT${NC}"

# Test the Cloud Function
echo ""
echo -e "  Testing getFAQCategories Cloud Function..."
FUNC_RESULT=$(curl -sS --connect-timeout 10 "$PARSE_URL/functions/getFAQCategories" \
    -H "X-Parse-Application-Id: $APP_ID" \
    -H "Content-Type: application/json" \
    -d '{"location":"landing"}' 2>/dev/null)

if echo "$FUNC_RESULT" | grep -q '"categories"'; then
    CAT_IN_RESULT=$(echo "$FUNC_RESULT" | grep -o '"objectId"' | wc -l)
    echo -e "  ${GREEN}✓ getFAQCategories works ($CAT_IN_RESULT categories returned)${NC}"
else
    echo -e "  ${RED}✗ getFAQCategories failed: $FUNC_RESULT${NC}"
fi

echo ""
echo -e "  Testing getFAQs Cloud Function..."
FUNC_RESULT=$(curl -sS --connect-timeout 10 "$PARSE_URL/functions/getFAQs" \
    -H "X-Parse-Application-Id: $APP_ID" \
    -H "Content-Type: application/json" \
    -d '{"isPublic":true}' 2>/dev/null)

if echo "$FUNC_RESULT" | grep -q '"faqs"'; then
    FAQS_IN_RESULT=$(echo "$FUNC_RESULT" | grep -o '"objectId"' | wc -l)
    echo -e "  ${GREEN}✓ getFAQs works ($FAQS_IN_RESULT FAQs returned)${NC}"
else
    echo -e "  ${RED}✗ getFAQs failed or returned no items: $FUNC_RESULT${NC}"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}  Summary                                            ${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo ""

if [ "$NEW_CAT_COUNT" -gt 0 ] && [ "$NEW_ITEM_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ FAQ data is now available:${NC}"
    echo "  - $NEW_CAT_COUNT categories"
    echo "  - $NEW_ITEM_COUNT FAQ items"
    echo ""
    echo -e "${YELLOW}Note: You may need to restart Parse Server to reload Cloud Functions:${NC}"
    echo "  docker compose -f docker-compose.production.yml restart parse-server"
else
    echo -e "${YELLOW}⚠ Some data may still be missing.${NC}"
    echo "  Categories: $NEW_CAT_COUNT"
    echo "  Items: $NEW_ITEM_COUNT"
    echo ""
    echo "Manual steps may be needed - check the output above."
fi

echo ""
echo -e "${GREEN}Done!${NC}"
