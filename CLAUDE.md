# Privacy Policy Generator

AI-powered privacy policy generation pipeline. Scans a product codebase for data
collection points, maps data flows, classifies sensitivity by regulation (GDPR/CCPA/COPPA),
and generates jurisdiction-specific privacy policies ready for legal review.

## Agents

| Agent | Model | Role |
|---|---|---|
| **scanner** | claude-haiku-4-5 | Fast pattern scanning of product code and configs |
| **classifier** | claude-sonnet-4-6 | Data flow mapping and sensitivity classification |
| **drafter** | claude-sonnet-4-6 | Privacy policy and compliance document generation |
| **reviewer** | claude-opus-4-6 | Legal compliance review with escalation capability |

## Workflows

- **generate-policies** (default): Full pipeline — scan → classify → review → draft → legal review → version → report
- **quarterly-review**: Lightweight change detection to determine if policies need updating

## Output Files

All generated policies are written to `output/`:
- `output/policies/privacy-policy.md` — combined policy (all jurisdictions)
- `output/policies/gdpr-privacy-policy.md` — GDPR-specific policy
- `output/policies/ccpa-privacy-policy.md` — CCPA-specific policy
- `output/records/article-30-processing-record.md` — GDPR Article 30 record
- `output/configs/cookie-consent.json` — cookie consent configuration
- `output/audit-report.md` — full audit summary

## Configuration

Edit `config/product-config.yaml` to point to your product directory and set company info.
Edit `config/scan-patterns.yaml` to add custom data collection patterns.

## Scripts

All scripts use only native tools (bash, python3, grep, find, diff, jq):
- `scripts/scan-product.sh` — scans product for data collection indicators
- `scripts/version-policies.sh` — archives policy versions with diffs
- `scripts/detect-changes.sh` — detects product changes for quarterly review

## Data Flow

```
config/product-config.yaml → scan-product.sh → data/scan-results/
→ classifier agent → data/analysis/
→ reviewer agent (approve/rework)
→ drafter agent → output/policies/ + output/records/ + output/configs/
→ reviewer agent (approve/rework/escalate)
→ version-policies.sh → output/versions/ + output/changelog.md
→ drafter agent → output/audit-report.md
```
