# Privacy Policy Generator

AI-powered privacy compliance pipeline that scans your product codebase, maps data flows,
and generates jurisdiction-specific privacy policies (GDPR, CCPA, COPPA) — ready for legal review.

## What It Does

1. **Scans** your product code and configs for data collection points (PII, payment info,
   tracking cookies, third-party SDKs)
2. **Maps** each data element through its full lifecycle: collection → processing → storage →
   sharing → retention → deletion
3. **Classifies** data sensitivity (low/medium/high/critical) and identifies applicable
   regulations (GDPR, CCPA, COPPA)
4. **Generates** jurisdiction-specific privacy policies, GDPR Article 30 processing records,
   and cookie consent configurations
5. **Reviews** policies for legal completeness and accuracy (using Opus for compliance checking)
6. **Versions** all policy documents with diffs and changelogs
7. **Schedules** quarterly reviews to detect when product changes require policy updates

## Quick Start

```bash
# 1. Install AO
npm install -g @launchapp-dev/ao

# 2. Start the daemon
ao daemon start --autonomous

# 3. Point to your product (edit config/product-config.yaml)
#    Set product.directory to your codebase path

# 4. Run the pipeline
ao workflow run generate-policies

# 5. Watch it run
ao daemon stream --pretty

# 6. Find your policies in output/
ls output/policies/
```

No API keys required — uses only Claude via AO and native CLI tools (bash, python3, grep, find, diff, jq).

## Agents

| Agent | Model | Role |
|---|---|---|
| **scanner** | claude-haiku-4-5 | Fast pattern scanning — identifies data collection points across code and configs |
| **classifier** | claude-sonnet-4-6 | Maps data flows, classifies sensitivity, identifies GDPR/CCPA/COPPA triggers |
| **drafter** | claude-sonnet-4-6 | Generates privacy policies, Article 30 records, cookie consent configs |
| **reviewer** | claude-opus-4-6 | Legal compliance review — approves, requests rework, or escalates to human counsel |

## Workflows

### `generate-policies` (on-demand)

Full policy generation pipeline:

```
scan-product → map-data-flows → review-classification → draft-policies
→ legal-review → version-policies → generate-report
```

The reviewer can send classification or drafts back for revision (up to 2 attempts each).
If legal review escalates, an alert is written to `output/alerts/` for human review.

### `quarterly-review` (scheduled: 1st of every 3rd month)

Lightweight change detection:

```
detect-changes → assess-impact → [policy-up-to-date | queue-policy-update | write-compliance-alert]
```

## Configuration

### `config/product-config.yaml`

```yaml
product:
  name: "MyApp"
  directory: "./sample-product"   # ← point to your codebase
  company:
    name: "Acme Corp"
    address: "123 Main St, San Francisco, CA 94105"
  dpo:
    email: "privacy@acme-corp.example.com"
  jurisdictions: [GDPR, CCPA]
  effective_date: "2026-04-01"
```

### `config/scan-patterns.yaml`

Customize data collection patterns and third-party SDK detection for your stack.

## Output Files

| File | Description |
|---|---|
| `output/policies/privacy-policy.md` | Combined policy — all jurisdictions |
| `output/policies/gdpr-privacy-policy.md` | GDPR-specific policy |
| `output/policies/ccpa-privacy-policy.md` | CCPA-specific policy |
| `output/policies/coppa-privacy-policy.md` | COPPA policy (if children's data detected) |
| `output/records/article-30-processing-record.md` | GDPR Article 30 processing record |
| `output/records/data-processing-inventory.md` | Full data processing inventory |
| `output/configs/cookie-consent.json` | Cookie consent configuration |
| `output/audit-report.md` | Audit summary with data flow tables |
| `output/changelog.md` | Policy version history |
| `output/versions/` | Dated policy archives with diffs |

## AO Features Demonstrated

- **Multi-agent pipeline** — 4 specialized agents with distinct roles and models
- **Multi-model routing** — Haiku for scanning, Sonnet for drafting, Opus for legal review
- **Decision contracts** — approve/rework/escalate verdicts with rework loops
- **Command phases** — grep/find/python3/diff/jq for codebase scanning and versioning
- **Scheduled workflows** — quarterly policy reviews via cron
- **Phase routing** — rework loops send back to earlier phases (max 2 attempts each)
- **Escalation paths** — legal review can escalate to human counsel

## Sample Product

The `sample-product/` directory contains a demo Node.js app that triggers realistic
privacy scan results: authentication (email/password), payments (Stripe), error tracking
(Sentry), analytics (Google Analytics, Segment), and customer support (Intercom).

Run the pipeline against it out of the box without any configuration changes.
