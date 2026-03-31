#!/usr/bin/env bash
# version-policies.sh — Archive current policies with versioning and diffs
# Creates dated archive, generates diffs vs previous version, updates changelog

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

POLICIES_DIR="$PROJECT_ROOT/output/policies"
VERSIONS_DIR="$PROJECT_ROOT/output/versions"
CHANGELOG="$PROJECT_ROOT/output/changelog.md"
VERSION_HISTORY="$PROJECT_ROOT/data/version-history.json"

mkdir -p "$VERSIONS_DIR"

DATE=$(date +%Y-%m-%d)
DATETIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Read current version or start at v1.0
if [ -f "$VERSION_HISTORY" ]; then
    CURRENT_VERSION=$(python3 -c "
import json
try:
    data = json.load(open('$VERSION_HISTORY'))
    versions = data.get('versions', [])
    if versions:
        last = versions[-1]['version']
        major, minor = last.lstrip('v').split('.')
        print(f'v{major}.{int(minor)+1}')
    else:
        print('v1.0')
except:
    print('v1.0')
")
else
    CURRENT_VERSION="v1.0"
fi

echo "Creating version $CURRENT_VERSION ($DATE)..." >&2

# Create versioned archive directory
ARCHIVE_DIR="$VERSIONS_DIR/$DATE-$CURRENT_VERSION"
mkdir -p "$ARCHIVE_DIR"

# Copy current policies to archive
if [ -d "$POLICIES_DIR" ] && [ "$(ls -A "$POLICIES_DIR" 2>/dev/null)" ]; then
    cp -r "$POLICIES_DIR"/. "$ARCHIVE_DIR/"
    echo "Archived $(ls "$ARCHIVE_DIR" | wc -l) policy files to $ARCHIVE_DIR" >&2
else
    echo "WARNING: No policy files found in $POLICIES_DIR" >&2
fi

# Find previous version for diff
PREV_ARCHIVE=""
if [ -d "$VERSIONS_DIR" ]; then
    PREV_ARCHIVE=$(ls -d "$VERSIONS_DIR"/*/ 2>/dev/null | sort | tail -2 | head -1 || true)
fi

# Generate diffs
DIFF_OUTPUT=""
if [ -n "$PREV_ARCHIVE" ] && [ "$PREV_ARCHIVE" != "$ARCHIVE_DIR/" ]; then
    echo "Generating diffs against previous version..." >&2
    DIFF_FILES=$(ls "$POLICIES_DIR"/*.md 2>/dev/null || true)
    for policy_file in $DIFF_FILES; do
        filename=$(basename "$policy_file")
        prev_file="$PREV_ARCHIVE/$filename"
        if [ -f "$prev_file" ]; then
            file_diff=$(diff -u "$prev_file" "$policy_file" 2>/dev/null || true)
            if [ -n "$file_diff" ]; then
                DIFF_OUTPUT="$DIFF_OUTPUT\n\n### Changes in $filename\n\`\`\`diff\n$file_diff\n\`\`\`"
            fi
        fi
    done
fi

# Update version header in policy files
for policy_file in "$POLICIES_DIR"/*.md; do
    [ -f "$policy_file" ] || continue
    # Add/update version comment at top
    if grep -q "^<!-- Version:" "$policy_file" 2>/dev/null; then
        sed -i.bak "s|^<!-- Version:.*-->|<!-- Version: $CURRENT_VERSION | Effective: $DATE -->|" "$policy_file" && rm -f "${policy_file}.bak"
    else
        # Prepend version header
        TMP=$(mktemp)
        echo "<!-- Version: $CURRENT_VERSION | Generated: $DATETIME | Effective: $DATE -->" > "$TMP"
        cat "$policy_file" >> "$TMP"
        mv "$TMP" "$policy_file"
    fi
done

# Append changelog entry
if [ ! -f "$CHANGELOG" ]; then
    echo "# Privacy Policy Changelog" > "$CHANGELOG"
    echo "" >> "$CHANGELOG"
fi

python3 << PYEOF
changelog_entry = f"""
## {os.environ.get('CURRENT_VERSION', 'v1.0')} — {os.environ.get('DATE', '$(date +%Y-%m-%d)')}

**Generated**: {os.environ.get('DATETIME', '$(date -u +%Y-%m-%dT%H:%M:%SZ)')}
**Archive**: output/versions/{os.environ.get('DATE', '$(date +%Y-%m-%d)')}-{os.environ.get('CURRENT_VERSION', 'v1.0')}/

### Changes

{'''No previous version to compare against — initial generation.''' if not '$DIFF_OUTPUT' else '$DIFF_OUTPUT'}

---
"""
import os
changelog_path = "$CHANGELOG"
with open(changelog_path, "r") as f:
    content = f.read()
header_end = content.find("\n\n")
if header_end == -1:
    header_end = len(content)
new_content = content[:header_end + 2] + changelog_entry + content[header_end + 2:]
with open(changelog_path, "w") as f:
    f.write(new_content)
print("Changelog updated")
PYEOF

# Update version history JSON
python3 << PYEOF
import json, os
from datetime import datetime

history_path = "$VERSION_HISTORY"
if os.path.exists(history_path):
    with open(history_path) as f:
        data = json.load(f)
else:
    data = {"versions": []}

import glob
policy_files = glob.glob("$POLICIES_DIR/*.md")

data["versions"].append({
    "version": "$CURRENT_VERSION",
    "date": "$DATE",
    "generated_at": "$DATETIME",
    "archive_path": "output/versions/$DATE-$CURRENT_VERSION/",
    "policy_files": [os.path.basename(f) for f in policy_files]
})
data["latest_version"] = "$CURRENT_VERSION"
data["last_updated"] = "$DATETIME"

os.makedirs(os.path.dirname(history_path), exist_ok=True)
with open(history_path, "w") as f:
    json.dump(data, f, indent=2)
print(f"Version history updated: {len(data['versions'])} versions recorded")
PYEOF

echo "Versioning complete: $CURRENT_VERSION archived to $ARCHIVE_DIR" >&2
