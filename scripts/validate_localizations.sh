#!/bin/bash

# Localization Validation Script
# Ensures every .lproj folder covers all base-language keys

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
RESOURCES_DIR="$SCRIPT_DIR/../Claude Usage/Resources"

echo "🌍 Validating Localization Files..."
echo "===================================="
echo ""

# Change to resources directory
cd "$RESOURCES_DIR" || exit 1

# Check if en.lproj exists
if [ ! -d "en.lproj" ]; then
    echo "❌ Error: en.lproj (base language) not found!"
    exit 1
fi

# Get base keys from English
BASE_FILE="en.lproj/Localizable.strings"
if [ ! -f "$BASE_FILE" ]; then
    echo "❌ Error: $BASE_FILE not found!"
    exit 1
fi

echo "📋 Base language: English (en.lproj)"
echo ""

# Extract keys from base file
BASE_KEYS=$(grep -o '^"[^"]*"' "$BASE_FILE" | sort | uniq)
BASE_COUNT=$(echo "$BASE_KEYS" | wc -l | tr -d ' ')

echo "✓ Found $BASE_COUNT keys in base language"
echo ""

# Initialize counters
TOTAL_LANGUAGES=0
ERRORS_FOUND=0

# Check each .lproj directory
for lproj in *.lproj; do
    if [ "$lproj" = "en.lproj" ]; then
        continue
    fi

    LANG_FILE="$lproj/Localizable.strings"

    if [ ! -f "$LANG_FILE" ]; then
        echo "⚠️  Warning: $LANG_FILE not found, skipping..."
        continue
    fi

    TOTAL_LANGUAGES=$((TOTAL_LANGUAGES + 1))

    # Extract keys
    LANG_KEYS=$(grep -o '^"[^"]*"' "$LANG_FILE" | sort | uniq)
    LANG_COUNT=$(echo "$LANG_KEYS" | wc -l | tr -d ' ')

    echo "🔍 Checking $lproj..."
    echo "   Keys found: $LANG_COUNT"
    LANG_HAS_ERROR=0

    # Find missing keys
    MISSING=$(comm -23 <(echo "$BASE_KEYS") <(echo "$LANG_KEYS"))

    # Find extra keys
    EXTRA=$(comm -13 <(echo "$BASE_KEYS") <(echo "$LANG_KEYS"))

    if [ -n "$MISSING" ]; then
        echo "   ❌ Missing keys:"
        echo "$MISSING" | sed 's/^/      /'
        LANG_HAS_ERROR=1
    fi

    if [ -n "$EXTRA" ]; then
        echo "   ⚠️  Extra keys (not in base):"
        echo "$EXTRA" | sed 's/^/      /'
    fi

    if [ -z "$MISSING" ] && [ -z "$EXTRA" ]; then
        echo "   ✅ All keys match!"
    fi

    ERRORS_FOUND=$((ERRORS_FOUND + LANG_HAS_ERROR))

    echo ""
done

echo "===================================="
echo "📊 Summary:"
echo "   Base language: $BASE_COUNT keys"
echo "   Languages checked: $TOTAL_LANGUAGES"
echo ""

if [ $ERRORS_FOUND -eq 0 ]; then
    echo "✅ All localizations are valid!"
    exit 0
else
    echo "❌ Found $ERRORS_FOUND language(s) with issues"
    exit 1
fi
