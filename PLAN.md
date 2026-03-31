# Privacy Policy Generator — Build Plan

## Overview

Privacy policy generation pipeline — scans a product's configuration files and
feature manifests to identify data collection points, maps data flows through the
system (collection, processing, storage, sharing, deletion), classifies data by
sensitivity (PII, financial, health, biometric), generates privacy policy sections
per regulatory framework (GDPR, CCPA, COPPA), produces Article 30 data processing
records, creates cookie consent configurations, version-controls policy documents
with change tracking, and schedules quarterly reviews.

All analysis uses filesystem MCP (read configs/code), sequential-thinking MCP
(structured legal reasoning), and git MCP (version-control policies). Command
phases use `grep`, `find`, `python3`, `diff`, and `jq` — all available natively.

---

## Agents (4)

| Agent | Model | Role |
|---|---|---|
| **scanner** | claude-haiku-4-5 | Fast extraction — scans product configs, code, and manifests for data collection points |
| **classifier** | claude-sonnet-4-6 | Maps data flows, classifies sensitivity levels, identifies regulatory triggers |
| **drafter** | claude-sonnet-4-6 | Generates privacy policy sections, data processing records, cookie consent configs |
| **reviewer** | claude-opus-4-6 | Legal review — checks completeness, accuracy, regulatory compliance of drafted policies |

### MCP Servers Used by Agents

- **filesystem** — all agents read product configs, write analysis files and policy documents
- **sequential-thinking** — classifier uses for data flow mapping reasoning, reviewer uses for compliance checking
- **git** (@modelcontextprotocol/server-git) — drafter uses for version-controlling policy documents with diffs

---

## Workflows (2)

### 1. `generate-policies` (primary — triggered per product audit)

Main pipeline: product directory in → privacy policies + processing records + consent configs out.

**Phases:**

1. **scan-product** (command)
   - Script: `scripts/scan-product.sh`
   - Scans the target product directory for data collection indicators:
     - `grep -rn` for common patterns: `email`, `password`, `cookie`, `localStorage`, `analytics`, `tracking`, `geolocation`, `ip_address`, `user_agent`, `fingerprint`, `payment`, `ssn`, `dob`, `health`, `biometric`
     - `find` for config files: `*.env*`, `*config*`, `*manifest*`, `package.json`, `docker-compose*`
     - `jq` to parse JSON configs for API keys, third-party service declarations, database schemas
     - `grep -rn` for third-party SDKs: `google-analytics`, `segment`, `mixpanel`, `stripe`, `facebook-pixel`, `hotjar`, `sentry`, `intercom`
   - Writes raw scan to `data/scan-results/raw-findings.json`
   - Writes detected third-party services to `data/scan-results/third-parties.json`
   - Exit 0 always — logs scan errors to stderr

2. **map-data-flows** (agent: classifier)
   - Reads raw findings from `data/scan-results/`
   - Uses sequential-thinking to map each data point through its lifecycle:
     - **Collection**: how/where is it collected? (form, cookie, API, SDK)
     - **Processing**: what operations are performed? (authentication, personalization, analytics)
     - **Storage**: where is it stored? (database, cache, third-party, logs)
     - **Sharing**: who receives it? (third-party services, partners, sub-processors)
     - **Retention**: how long is it kept? (session, account lifetime, regulatory minimum)
     - **Deletion**: how can it be removed? (user request, automated, account closure)
   - Classifies each data element by sensitivity:
     - **Low**: anonymized analytics, aggregated metrics, public profile info
     - **Medium**: email, name, preferences, usage history
     - **High**: financial data (payment info, billing), precise geolocation, government IDs
     - **Critical**: health/medical data, biometric data, children's data, racial/ethnic origin
   - Identifies regulatory triggers:
     - GDPR: any EU user data, special categories (Art. 9), automated decision-making (Art. 22)
     - CCPA: California resident data, sale/sharing of personal information
     - COPPA: any data from users under 13
   - Output contract: writes `data/analysis/data-flow-map.json`, `data/analysis/sensitivity-classification.json`, `data/analysis/regulatory-triggers.json`

3. **review-classification** (agent: reviewer)
   - Decision contract: `verdict` (approve | rework), `reasoning`, `issues[]`
   - Checks data flow map for completeness:
     - Every detected data point has a full lifecycle mapped
     - Sensitivity classifications are defensible
     - No obvious data flows missed (e.g., server logs, error tracking)
     - Third-party data sharing is fully enumerated
   - **Routing:**
     - `approve` → draft-policies
     - `rework` → map-data-flows (max 2 attempts)

4. **draft-policies** (agent: drafter)
   - Reads data flow map, sensitivity classifications, regulatory triggers
   - Reads policy templates from `config/templates/`
   - Generates per-jurisdiction privacy policies:
     - **GDPR Policy** (`output/policies/gdpr-privacy-policy.md`):
       - Legal basis for processing (consent, legitimate interest, contract, legal obligation)
       - Data subject rights (access, rectification, erasure, portability, restriction, objection)
       - International data transfers and safeguards
       - Data Protection Officer contact info (from config)
       - Cookie policy and consent mechanism
     - **CCPA Policy** (`output/policies/ccpa-privacy-policy.md`):
       - Categories of personal information collected
       - Business/commercial purposes for collection
       - Categories of third parties with whom data is shared
       - Right to know, delete, opt-out of sale
       - Non-discrimination statement
       - Financial incentive programs (if applicable)
     - **COPPA Policy** (`output/policies/coppa-privacy-policy.md`) — only if triggered:
       - Parental consent mechanisms
       - Limited data collection from children
       - Parental access and deletion rights
     - **Combined Policy** (`output/policies/privacy-policy.md`):
       - Unified policy covering all applicable jurisdictions
       - Jurisdiction-specific sections clearly marked
   - Generates supplementary documents:
     - **Article 30 Record** (`output/records/article-30-processing-record.md`):
       - Processing activity name, purpose, legal basis
       - Categories of data subjects and personal data
       - Recipients and international transfers
       - Retention periods and security measures
     - **Cookie Consent Config** (`output/configs/cookie-consent.json`):
       - Cookie categories (strictly necessary, functional, analytics, marketing)
       - Per-cookie details: name, provider, purpose, expiry, type
       - Default consent states per jurisdiction
     - **Data Processing Inventory** (`output/records/data-processing-inventory.md`):
       - Full inventory of all processing activities
       - Sub-processor list with purposes and safeguards
   - Capabilities: writes_files, mutates_state

5. **legal-review** (agent: reviewer)
   - Decision contract: `verdict` (approve | rework | escalate), `reasoning`, `findings[]`
   - Uses sequential-thinking for systematic compliance check:
     - **Completeness**: all required sections present per regulation
     - **Accuracy**: policy text matches actual data flows
     - **Consistency**: no contradictions between jurisdiction-specific policies
     - **Plain language**: readability appropriate for general audience
     - **Legal sufficiency**: required legal disclosures present
   - Each finding includes: severity (critical/warning/info), section, description, recommendation
   - **Routing:**
     - `approve` → version-policies
     - `rework` → draft-policies (max 2 attempts)
     - `escalate` → stops pipeline, flags for human legal counsel review

6. **version-policies** (command)
   - Script: `scripts/version-policies.sh`
   - Copies current policies from `output/policies/` to `output/versions/{date}/`
   - Generates diff against previous version (if exists) using `diff -u`
   - Writes changelog entry to `output/changelog.md`
   - Writes `data/version-history.json` with version metadata
   - Updates `output/policies/` header with version number and effective date

7. **generate-report** (agent: drafter)
   - Reads all analysis and generated documents
   - Produces final summary report: `output/audit-report.md`
     - Executive summary: jurisdictions covered, data sensitivity breakdown
     - Data flow diagram (ASCII/markdown table)
     - Policy document manifest with links
     - Change summary (if updating existing policies)
     - Recommended next steps (annual review date, monitoring setup)
   - Capabilities: writes_files, requires_commit

### 2. `quarterly-review` (scheduled — policy freshness check)

Lightweight review: checks if product has changed since last policy generation.

**Phases:**

1. **detect-changes** (command)
   - Script: `scripts/detect-changes.sh`
   - Compares current product scan against last scan in `data/scan-results/`
   - Uses `diff` to identify new data collection points, removed features, new third-party services
   - Writes change report to `data/reviews/changes-{date}.json`
   - Exit code: 0 = changes detected, 1 = no changes

2. **assess-impact** (agent: classifier)
   - Decision contract: `verdict` (policy-current | needs-update | non-compliant), `reasoning`, `changes[]`
   - Reads change report
   - Classifies impact of each change:
     - **No impact**: cosmetic changes, non-data-related features
     - **Minor update**: new analytics events, UI text changes
     - **Major update**: new data collection, new third-party sharing, new jurisdiction
     - **Non-compliant**: removed consent mechanism, new high-sensitivity data without safeguards
   - **Routing:**
     - `policy-current` → pipeline ends (no action needed)
     - `needs-update` → triggers full `generate-policies` workflow
     - `non-compliant` → escalate alert (writes urgent finding to `output/alerts/`)

---

## Data Model

### Config Files (static — read-only reference)

| File | Content |
|---|---|
| `config/product-config.yaml` | Target product directory, company info, DPO contact, applicable jurisdictions |
| `config/scan-patterns.yaml` | Regex patterns for detecting data collection, third-party SDKs, sensitive data |
| `config/templates/gdpr-template.md` | GDPR privacy policy template with placeholder sections |
| `config/templates/ccpa-template.md` | CCPA privacy policy template with placeholder sections |
| `config/templates/coppa-template.md` | COPPA privacy policy template with placeholder sections |
| `config/templates/article-30-template.md` | GDPR Article 30 record template |
| `config/cookie-categories.yaml` | Cookie classification taxonomy (necessary, functional, analytics, marketing) |

### Data Files (mutable — written by agents/scripts)

| File | Content | Writers |
|---|---|---|
| `data/scan-results/raw-findings.json` | Raw grep/find output from product scan | scan-product.sh |
| `data/scan-results/third-parties.json` | Detected third-party services and SDKs | scan-product.sh |
| `data/analysis/data-flow-map.json` | Full data lifecycle map per data element | classifier |
| `data/analysis/sensitivity-classification.json` | Data sensitivity levels per element | classifier |
| `data/analysis/regulatory-triggers.json` | Which regulations are triggered and why | classifier |
| `data/version-history.json` | Policy version metadata and dates | version-policies.sh |
| `data/reviews/changes-{date}.json` | Product change reports from quarterly reviews | detect-changes.sh |

### Output Files (generated artifacts)

| File | Content |
|---|---|
| `output/policies/privacy-policy.md` | Combined privacy policy (all jurisdictions) |
| `output/policies/gdpr-privacy-policy.md` | GDPR-specific privacy policy |
| `output/policies/ccpa-privacy-policy.md` | CCPA-specific privacy policy |
| `output/policies/coppa-privacy-policy.md` | COPPA-specific policy (if applicable) |
| `output/records/article-30-processing-record.md` | GDPR Article 30 data processing record |
| `output/records/data-processing-inventory.md` | Full data processing inventory |
| `output/configs/cookie-consent.json` | Cookie consent configuration |
| `output/changelog.md` | Policy version changelog |
| `output/versions/{date}/ ` | Archived policy versions |
| `output/audit-report.md` | Final audit summary report |
| `output/alerts/` | Urgent compliance alerts (quarterly review) |

---

## Command Phase Scripts (3)

### `scripts/scan-product.sh`
- Reads target product path from `config/product-config.yaml` (parsed with `python3 -c`)
- Reads scan patterns from `config/scan-patterns.yaml`
- Runs grep/find across target directory for data collection indicators
- Parses package.json/requirements.txt for third-party SDK dependencies
- Writes structured JSON output
- Exit 0 always — logs per-file errors to stderr

### `scripts/version-policies.sh`
- Reads current version from `data/version-history.json` (or starts at v1.0)
- Creates dated archive directory in `output/versions/`
- Copies current policies to archive
- Generates diffs against previous version using `diff -u`
- Appends changelog entry with date, version, and summary of changes
- Updates version-history.json

### `scripts/detect-changes.sh`
- Re-runs scan-product.sh to get current state
- Compares against `data/scan-results/raw-findings.json` (last run)
- Uses `diff` and `jq` to identify additions, removals, modifications
- Writes structured change report
- Exit code signals whether changes were found

---

## Schedules

| Schedule | Cron | Workflow |
|---|---|---|
| `quarterly-policy-review` | `0 9 1 */3 *` (1st of every 3rd month, 9am) | quarterly-review |

(`generate-policies` is triggered on-demand via queue)

---

## AO Features Demonstrated

1. **Scheduled workflows** — quarterly policy reviews via cron, continuous product change monitoring
2. **Multi-agent pipeline** — 4 specialized agents: scanner (fast extraction), classifier (data analysis), drafter (policy generation), reviewer (legal compliance)
3. **Multi-model routing** — Haiku for fast scanning, Sonnet for drafting/classification, Opus for legal review (highest stakes)
4. **Command phases** — grep/find for codebase scanning, python3 for config parsing, diff for version comparison, jq for JSON processing
5. **Decision contracts** — classification review (approve/rework), legal review (approve/rework/escalate), quarterly assessment (current/needs-update/non-compliant)
6. **Phase routing with rework loops** — classification and legal review can send back for revision (max 2 attempts each)
7. **Escalation paths** — legal review can escalate to human counsel, quarterly review can flag non-compliance
8. **Version control** — policies are versioned with diffs, changelogs, and dated archives
9. **Output contracts** — privacy policies per jurisdiction, Article 30 records, cookie consent configs, audit reports

---

## Sample Data

### Sample Product Config (`config/product-config.yaml`)
```yaml
product:
  name: "MyApp"
  directory: "./sample-product"
  company:
    name: "Acme Corp"
    address: "123 Main St, San Francisco, CA 94105"
    website: "https://myapp.example.com"
  dpo:
    name: "Jane Smith"
    email: "privacy@acme-corp.example.com"
  jurisdictions:
    - GDPR
    - CCPA
  review_schedule: quarterly
  effective_date: "2026-04-01"
```

### Sample Scan Patterns (`config/scan-patterns.yaml`)
```yaml
data_collection_patterns:
  pii:
    - pattern: '(email|e-mail|emailAddress)'
      category: contact_info
      sensitivity: medium
    - pattern: '(password|passwd|secret)'
      category: credentials
      sensitivity: high
    - pattern: '(firstName|lastName|fullName|displayName)'
      category: identity
      sensitivity: medium
    - pattern: '(ssn|socialSecurity|taxId)'
      category: government_id
      sensitivity: critical
    - pattern: '(dateOfBirth|dob|birthDate|age)'
      category: demographics
      sensitivity: high
  financial:
    - pattern: '(creditCard|cardNumber|cvv|paymentMethod)'
      category: payment
      sensitivity: critical
    - pattern: '(bankAccount|routingNumber|iban)'
      category: banking
      sensitivity: critical
    - pattern: '(stripe|braintree|paypal|square)'
      category: payment_processor
      sensitivity: high
  tracking:
    - pattern: '(cookie|setCookie|document\.cookie)'
      category: cookies
      sensitivity: medium
    - pattern: '(localStorage|sessionStorage)'
      category: browser_storage
      sensitivity: medium
    - pattern: '(analytics|tracking|pageview|event\()'
      category: analytics
      sensitivity: medium
    - pattern: '(geolocation|navigator\.geolocation|geoip)'
      category: location
      sensitivity: high
    - pattern: '(fingerprint|canvas|webgl|audioContext)'
      category: device_fingerprinting
      sensitivity: high

third_party_sdks:
  - pattern: 'google-analytics|gtag|GA_TRACKING'
    service: "Google Analytics"
    data_shared: ["page views", "user behavior", "device info"]
  - pattern: 'segment|analytics\.identify'
    service: "Segment"
    data_shared: ["user identity", "events", "traits"]
  - pattern: 'mixpanel'
    service: "Mixpanel"
    data_shared: ["user events", "properties", "device info"]
  - pattern: 'hotjar|hj\('
    service: "Hotjar"
    data_shared: ["session recordings", "heatmaps", "user behavior"]
  - pattern: 'sentry|Sentry\.init'
    service: "Sentry"
    data_shared: ["error reports", "stack traces", "user context"]
  - pattern: 'intercom'
    service: "Intercom"
    data_shared: ["user identity", "conversations", "events"]
  - pattern: 'facebook-pixel|fbq\('
    service: "Facebook Pixel"
    data_shared: ["page views", "conversions", "user actions"]
```

### Sample Cookie Consent Config (`output/configs/cookie-consent.json`)
```json
{
  "version": "1.0",
  "generated": "2026-04-01",
  "categories": {
    "strictly_necessary": {
      "description": "Essential cookies required for the website to function. Cannot be disabled.",
      "default_consent": true,
      "cookies": [
        {
          "name": "session_id",
          "provider": "MyApp",
          "purpose": "Maintains user session state",
          "expiry": "Session",
          "type": "HTTP"
        }
      ]
    },
    "functional": {
      "description": "Cookies that enable enhanced functionality and personalization.",
      "default_consent": false,
      "cookies": [
        {
          "name": "user_preferences",
          "provider": "MyApp",
          "purpose": "Stores user display preferences (theme, language)",
          "expiry": "1 year",
          "type": "HTTP"
        }
      ]
    },
    "analytics": {
      "description": "Cookies that help us understand how visitors use our website.",
      "default_consent": false,
      "cookies": [
        {
          "name": "_ga",
          "provider": "Google Analytics",
          "purpose": "Distinguishes unique users",
          "expiry": "2 years",
          "type": "HTTP"
        },
        {
          "name": "_gid",
          "provider": "Google Analytics",
          "purpose": "Distinguishes unique users (24h)",
          "expiry": "24 hours",
          "type": "HTTP"
        }
      ]
    },
    "marketing": {
      "description": "Cookies used to track visitors across websites for advertising purposes.",
      "default_consent": false,
      "cookies": [
        {
          "name": "_fbp",
          "provider": "Facebook",
          "purpose": "Tracks conversions from Facebook ads",
          "expiry": "3 months",
          "type": "HTTP"
        }
      ]
    }
  },
  "jurisdiction_defaults": {
    "GDPR": {
      "require_explicit_consent": true,
      "default_all_off": true,
      "allow_reject_all": true
    },
    "CCPA": {
      "require_explicit_consent": false,
      "show_do_not_sell": true,
      "default_analytics_on": true
    }
  }
}
```

### Sample Audit Report Output (`output/audit-report.md`)
```markdown
# Privacy Policy Audit Report — MyApp

**Generated**: 2026-04-01 | **Version**: 1.0

## Executive Summary

- **Jurisdictions covered**: GDPR, CCPA
- **Data elements identified**: 24
- **Sensitivity breakdown**: 3 critical, 6 high, 10 medium, 5 low
- **Third-party services**: 5 (Google Analytics, Segment, Stripe, Sentry, Intercom)
- **Policies generated**: 3 (Combined, GDPR, CCPA)

## Data Flow Summary

| Data Category | Collection | Processing | Storage | Sharing | Retention |
|---|---|---|---|---|---|
| Contact (email, name) | Registration form | Authentication, notifications | PostgreSQL | Intercom, Segment | Account lifetime |
| Payment (card info) | Checkout flow | Payment processing | Stripe (tokenized) | Stripe | Per PCI-DSS |
| Analytics (page views) | Automatic | Usage analysis | Google Analytics | Google | 26 months |
| Device info (IP, UA) | Automatic | Security, analytics | Server logs, Sentry | Sentry | 90 days |
| Preferences | Settings page | Personalization | PostgreSQL | None | Account lifetime |

## Generated Documents

1. [Combined Privacy Policy](policies/privacy-policy.md)
2. [GDPR Privacy Policy](policies/gdpr-privacy-policy.md)
3. [CCPA Privacy Policy](policies/ccpa-privacy-policy.md)
4. [Article 30 Processing Record](records/article-30-processing-record.md)
5. [Data Processing Inventory](records/data-processing-inventory.md)
6. [Cookie Consent Configuration](configs/cookie-consent.json)

## Recommended Next Steps

- [ ] Have legal counsel review all generated policies before publishing
- [ ] Configure cookie consent banner using `cookie-consent.json`
- [ ] Set up quarterly review schedule (next: 2026-07-01)
- [ ] Verify data retention periods with engineering team
- [ ] Confirm sub-processor list is complete with procurement team
```

---

## Directory Structure

```
examples/privacy-policy-generator/
├── .ao/workflows/
│   ├── agents.yaml
│   ├── phases.yaml
│   ├── workflows.yaml
│   ├── mcp-servers.yaml
│   └── schedules.yaml
├── config/
│   ├── product-config.yaml
│   ├── scan-patterns.yaml
│   ├── cookie-categories.yaml
│   └── templates/
│       ├── gdpr-template.md
│       ├── ccpa-template.md
│       ├── coppa-template.md
│       └── article-30-template.md
├── scripts/
│   ├── scan-product.sh
│   ├── version-policies.sh
│   └── detect-changes.sh
├── data/
│   ├── scan-results/
│   ├── analysis/
│   ├── reviews/
│   └── version-history.json
├── output/
│   ├── policies/
│   ├── records/
│   ├── configs/
│   ├── versions/
│   ├── alerts/
│   ├── changelog.md
│   └── audit-report.md
├── sample-product/          # Sample product to demo scanning against
│   ├── package.json
│   ├── src/
│   │   ├── auth.js
│   │   ├── analytics.js
│   │   ├── payments.js
│   │   └── config.js
│   └── .env.example
├── CLAUDE.md
└── README.md
```
