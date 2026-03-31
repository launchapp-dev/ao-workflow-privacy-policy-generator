#!/usr/bin/env bash
# scan-product.sh — Scan product directory for data collection indicators
# Reads config/product-config.yaml for target directory
# Writes data/scan-results/raw-findings.json and data/scan-results/third-parties.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG="$PROJECT_ROOT/config/product-config.yaml"
SCAN_PATTERNS="$PROJECT_ROOT/config/scan-patterns.yaml"
OUTPUT_DIR="$PROJECT_ROOT/data/scan-results"

mkdir -p "$OUTPUT_DIR"

# Read product directory from config
PRODUCT_DIR=$(python3 -c "
import yaml, sys
try:
    cfg = yaml.safe_load(open('$CONFIG'))
    print(cfg['product']['directory'])
except Exception as e:
    print('./sample-product', file=sys.stderr)
    print('./sample-product')
")

# Resolve product directory relative to project root
if [[ "$PRODUCT_DIR" == ./* ]]; then
    PRODUCT_DIR="$PROJECT_ROOT/${PRODUCT_DIR#./}"
fi

echo "Scanning product directory: $PRODUCT_DIR" >&2

if [ ! -d "$PRODUCT_DIR" ]; then
    echo "WARNING: Product directory not found: $PRODUCT_DIR — using sample-product" >&2
    PRODUCT_DIR="$PROJECT_ROOT/sample-product"
fi

# PII patterns to search for
PII_PATTERNS=(
    "email" "e-mail" "emailAddress"
    "password" "passwd"
    "firstName" "lastName" "fullName" "displayName"
    "ssn" "socialSecurity" "taxId"
    "dateOfBirth" "dob" "birthDate"
    "phone" "phoneNumber" "mobile"
    "address" "zipCode" "postalCode"
    "creditCard" "cardNumber" "cvv" "paymentMethod"
    "bankAccount" "routingNumber"
    "geolocation" "geoip"
    "cookie" "setCookie" "localStorage" "sessionStorage"
    "analytics" "tracking" "pageview"
    "ip_address" "ipAddress" "user_agent" "userAgent"
    "fingerprint"
    "health" "medical" "diagnosis"
    "biometric"
)

# Third-party SDK patterns
SDK_PATTERNS=(
    "google-analytics:Google Analytics"
    "gtag:Google Analytics"
    "GA_TRACKING:Google Analytics"
    "segment:Segment"
    "mixpanel:Mixpanel"
    "hotjar:Hotjar"
    "sentry:Sentry"
    "Sentry.init:Sentry"
    "intercom:Intercom"
    "facebook-pixel:Facebook Pixel"
    "fbq(:Facebook Pixel"
    "amplitude:Amplitude"
    "datadog:Datadog"
    "stripe:Stripe"
    "braintree:Braintree"
    "paypal:PayPal"
)

echo "Running PII pattern scan..." >&2

# Build raw findings
python3 << PYEOF
import subprocess, json, os, sys
from datetime import datetime

product_dir = "$PRODUCT_DIR"
findings = []

pii_patterns = [
    ("email|e-mail|emailAddress", "contact_info", "medium"),
    ("password|passwd", "credentials", "high"),
    ("firstName|lastName|fullName|displayName", "identity", "medium"),
    ("ssn|socialSecurity|taxId", "government_id", "critical"),
    ("dateOfBirth|dob|birthDate", "demographics", "high"),
    ("phone|phoneNumber|mobile", "contact_info", "medium"),
    ("creditCard|cardNumber|cvv|paymentMethod", "payment", "critical"),
    ("bankAccount|routingNumber|iban", "banking", "critical"),
    ("geolocation|navigator.geolocation|geoip", "location", "high"),
    ("cookie|setCookie|localStorage|sessionStorage", "tracking", "medium"),
    ("analytics|tracking|pageview", "analytics", "medium"),
    ("ip_address|ipAddress|user_agent|userAgent", "network_info", "medium"),
    ("fingerprint|canvas|webgl|audioContext", "device_fingerprinting", "high"),
    ("health|medical|diagnosis|prescription", "health_data", "critical"),
    ("biometric|facial|voiceprint", "biometric", "critical"),
]

for pattern, category, sensitivity in pii_patterns:
    try:
        result = subprocess.run(
            ["grep", "-rn", "-E", "--include=*.js", "--include=*.ts",
             "--include=*.py", "--include=*.rb", "--include=*.go",
             "--include=*.java", "--include=*.json", "--include=*.yaml",
             "--include=*.env", "--include=*.env.example",
             pattern, product_dir],
            capture_output=True, text=True, timeout=30
        )
        matches = []
        for line in result.stdout.splitlines()[:20]:  # cap at 20 per pattern
            parts = line.split(":", 2)
            if len(parts) >= 3:
                matches.append({"file": parts[0], "line": parts[1], "content": parts[2].strip()})

        if matches:
            findings.append({
                "pattern": pattern,
                "category": category,
                "sensitivity": sensitivity,
                "match_count": len(matches),
                "sample_matches": matches[:5]
            })
    except Exception as e:
        print(f"Error scanning pattern {pattern}: {e}", file=sys.stderr)

# Find config files
try:
    result = subprocess.run(
        ["find", product_dir, "-type", "f", "-name", "*.env*",
         "-o", "-name", "package.json", "-o", "-name", "docker-compose*",
         "-o", "-name", "*.config.*"],
        capture_output=True, text=True, timeout=30
    )
    config_files = [f.strip() for f in result.stdout.splitlines() if f.strip()]
except Exception as e:
    config_files = []
    print(f"Error finding config files: {e}", file=sys.stderr)

output = {
    "scanned_at": datetime.utcnow().isoformat() + "Z",
    "product_directory": product_dir,
    "findings": findings,
    "config_files_found": config_files,
    "total_pattern_matches": sum(f["match_count"] for f in findings)
}

os.makedirs("$OUTPUT_DIR", exist_ok=True)
with open("$OUTPUT_DIR/raw-findings.json", "w") as f:
    json.dump(output, f, indent=2)

print(f"Scan complete: {len(findings)} data categories found, {output['total_pattern_matches']} total matches", file=sys.stderr)
PYEOF

echo "Running third-party SDK scan..." >&2

python3 << PYEOF
import subprocess, json, os, sys
from datetime import datetime

product_dir = "$PRODUCT_DIR"
third_parties = []

sdk_patterns = [
    ("google-analytics|gtag|GA_TRACKING", "Google Analytics", ["page views", "user behavior", "device info"]),
    ("segment|analytics\\.identify", "Segment", ["user identity", "events", "traits"]),
    ("mixpanel", "Mixpanel", ["user events", "properties", "device info"]),
    ("hotjar|hj\\(", "Hotjar", ["session recordings", "heatmaps", "user behavior"]),
    ("sentry|Sentry\\.init", "Sentry", ["error reports", "stack traces", "user context"]),
    ("intercom", "Intercom", ["user identity", "conversations", "events"]),
    ("facebook-pixel|fbq\\(", "Facebook Pixel", ["page views", "conversions", "user actions"]),
    ("amplitude", "Amplitude", ["user events", "properties", "session data"]),
    ("stripe", "Stripe", ["payment info", "billing", "transaction data"]),
    ("paypal", "PayPal", ["payment info", "billing address"]),
    ("braintree", "Braintree", ["payment info", "transaction data"]),
]

for pattern, service, data_shared in sdk_patterns:
    try:
        result = subprocess.run(
            ["grep", "-rn", "-E", "--include=*.js", "--include=*.ts",
             "--include=*.py", "--include=*.json", "--include=*.html",
             pattern, product_dir],
            capture_output=True, text=True, timeout=30
        )
        if result.stdout.strip():
            matches = result.stdout.splitlines()[:3]
            third_parties.append({
                "service": service,
                "pattern_matched": pattern,
                "data_shared": data_shared,
                "evidence": [m.strip() for m in matches],
                "detected": True
            })
    except Exception as e:
        print(f"Error scanning for {service}: {e}", file=sys.stderr)

# Also check package.json for SDK dependencies
try:
    pkg_path = os.path.join(product_dir, "package.json")
    if os.path.exists(pkg_path):
        with open(pkg_path) as f:
            pkg = json.load(f)
        all_deps = {**pkg.get("dependencies", {}), **pkg.get("devDependencies", {})}
        sdk_dep_map = {
            "@segment/analytics-next": ("Segment", ["user identity", "events"]),
            "mixpanel-browser": ("Mixpanel", ["user events", "properties"]),
            "@sentry/browser": ("Sentry", ["error reports", "stack traces"]),
            "@sentry/node": ("Sentry", ["error reports", "stack traces"]),
            "stripe": ("Stripe", ["payment info", "transaction data"]),
            "@amplitude/analytics-browser": ("Amplitude", ["user events", "session data"]),
            "intercom": ("Intercom", ["user identity", "conversations"]),
        }
        for dep, (service, data_shared) in sdk_dep_map.items():
            if dep in all_deps:
                # Check not already detected
                if not any(t["service"] == service for t in third_parties):
                    third_parties.append({
                        "service": service,
                        "detected_via": "package.json",
                        "package": dep,
                        "version": all_deps[dep],
                        "data_shared": data_shared,
                        "detected": True
                    })
except Exception as e:
    print(f"Error reading package.json: {e}", file=sys.stderr)

output = {
    "scanned_at": datetime.utcnow().isoformat() + "Z",
    "product_directory": product_dir,
    "third_parties": third_parties,
    "count": len(third_parties)
}

with open("$OUTPUT_DIR/third-parties.json", "w") as f:
    json.dump(output, f, indent=2)

print(f"Third-party scan complete: {len(third_parties)} services detected", file=sys.stderr)
PYEOF

echo "Scan complete. Results written to $OUTPUT_DIR/" >&2
