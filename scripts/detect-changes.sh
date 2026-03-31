#!/usr/bin/env bash
# detect-changes.sh — Compare current product scan against last saved scan
# Exit 0: changes detected (pipeline continues to assess-impact)
# Exit 0: no changes (pipeline continues — assess-impact will determine policy-current verdict)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SCAN_RESULTS="$PROJECT_ROOT/data/scan-results"
REVIEWS_DIR="$PROJECT_ROOT/data/reviews"
DATE=$(date +%Y-%m-%d)
DATETIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$REVIEWS_DIR"

# Save last scan as baseline if it exists
LAST_SCAN="$SCAN_RESULTS/raw-findings.json"
LAST_THIRD_PARTIES="$SCAN_RESULTS/third-parties.json"

# Create backup of current scan
if [ -f "$LAST_SCAN" ]; then
    cp "$LAST_SCAN" "$REVIEWS_DIR/baseline-findings-$DATE.json"
fi

# Re-run the product scan
echo "Re-running product scan for change detection..." >&2
bash "$SCRIPT_DIR/scan-product.sh"

# Compare scans
python3 << PYEOF
import json, os, sys
from datetime import datetime

reviews_dir = "$REVIEWS_DIR"
scan_results_dir = "$SCAN_RESULTS"
date = "$DATE"
datetime_str = "$DATETIME"

# Load current scan
current_scan_path = os.path.join(scan_results_dir, "raw-findings.json")
current_tp_path = os.path.join(scan_results_dir, "third-parties.json")

if not os.path.exists(current_scan_path):
    print("ERROR: No current scan found. Run generate-policies workflow first.", file=sys.stderr)
    # Write a change report indicating no baseline
    report = {
        "detected_at": datetime_str,
        "date": date,
        "status": "no_baseline",
        "changes": [{"type": "no_baseline", "description": "No previous scan found — initial scan required"}],
        "has_changes": True,
        "summary": "No baseline scan found. Full policy generation required."
    }
    with open(os.path.join(reviews_dir, f"changes-{date}.json"), "w") as f:
        json.dump(report, f, indent=2)
    sys.exit(0)

with open(current_scan_path) as f:
    current = json.load(f)

# Load baseline
baseline_path = os.path.join(reviews_dir, f"baseline-findings-{date}.json")
# Try previous day baselines too
if not os.path.exists(baseline_path):
    baselines = sorted([f for f in os.listdir(reviews_dir) if f.startswith("baseline-findings-")])
    if baselines:
        baseline_path = os.path.join(reviews_dir, baselines[-1])
    else:
        baseline_path = None

changes = []

if baseline_path and os.path.exists(baseline_path):
    with open(baseline_path) as f:
        baseline = json.load(f)

    # Compare findings categories
    baseline_categories = {f["category"] for f in baseline.get("findings", [])}
    current_categories = {f["category"] for f in current.get("findings", [])}

    # New categories
    new_categories = current_categories - baseline_categories
    for cat in new_categories:
        changes.append({
            "type": "new_data_category",
            "category": cat,
            "severity": "major",
            "description": f"New data category detected: {cat}"
        })

    # Removed categories
    removed_categories = baseline_categories - current_categories
    for cat in removed_categories:
        changes.append({
            "type": "removed_data_category",
            "category": cat,
            "severity": "minor",
            "description": f"Data category no longer detected: {cat}"
        })

    # Match count changes (significant increases)
    baseline_counts = {f["category"]: f["match_count"] for f in baseline.get("findings", [])}
    current_counts = {f["category"]: f["match_count"] for f in current.get("findings", [])}
    for cat in baseline_categories & current_categories:
        b_count = baseline_counts.get(cat, 0)
        c_count = current_counts.get(cat, 0)
        if c_count > b_count * 1.5 and c_count - b_count > 5:
            changes.append({
                "type": "increased_data_collection",
                "category": cat,
                "severity": "minor",
                "description": f"Data collection increased for {cat}: {b_count} → {c_count} instances"
            })

    # Compare third parties
    current_tp_path_file = os.path.join(scan_results_dir, "third-parties.json")
    if os.path.exists(current_tp_path_file):
        with open(current_tp_path_file) as f:
            current_tp = json.load(f)
        current_services = {t["service"] for t in current_tp.get("third_parties", [])}

        # Check baseline third parties if available
        baseline_tp_files = sorted([f for f in os.listdir(reviews_dir) if f.startswith("baseline-findings-")])
        baseline_services = set()

        current_services_list = list(current_services)
        baseline_services_list = list(baseline_services)

        new_services = current_services - baseline_services
        for svc in new_services:
            changes.append({
                "type": "new_third_party",
                "service": svc,
                "severity": "major",
                "description": f"New third-party service detected: {svc}"
            })
else:
    # No baseline — flag all current findings as new
    for finding in current.get("findings", [])[:5]:
        changes.append({
            "type": "baseline_scan",
            "category": finding["category"],
            "severity": "info",
            "description": f"Initial scan: {finding['match_count']} instances of {finding['category']} found"
        })

has_changes = len([c for c in changes if c["severity"] in ["major", "critical"]]) > 0

report = {
    "detected_at": datetime_str,
    "date": date,
    "status": "changes_detected" if has_changes else "no_material_changes",
    "changes": changes,
    "has_changes": has_changes,
    "change_summary": {
        "critical": len([c for c in changes if c.get("severity") == "critical"]),
        "major": len([c for c in changes if c.get("severity") == "major"]),
        "minor": len([c for c in changes if c.get("severity") == "minor"]),
        "info": len([c for c in changes if c.get("severity") == "info"]),
    },
    "summary": f"{len(changes)} changes detected, {len([c for c in changes if c['severity'] in ['major', 'critical']])} material"
}

output_path = os.path.join(reviews_dir, f"changes-{date}.json")
with open(output_path, "w") as f:
    json.dump(report, f, indent=2)

print(f"Change detection complete: {report['summary']}", file=sys.stderr)
print(f"Report written to: {output_path}", file=sys.stderr)

# Always exit 0 — assess-impact will decide the verdict
sys.exit(0)
PYEOF

echo "Change detection complete." >&2
