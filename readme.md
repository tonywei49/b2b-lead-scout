# b2b-lead-scout

B2B lead discovery skill for AutoClaw / OpenClaw agents. Searches for companies selling specific products in target regions, collects company background and contact info, and outputs structured CSV/MD lead lists.

## What It Does

1. Accepts a product + region query (e.g., "法国销售室内健身器材的B2B公司")
2. Builds bilingual search queries (English + local language)
3. Searches via Tavily, deduplicates results
4. Enriches with company background and contact discovery
5. Scores leads by confidence (1-10)
6. Outputs `.csv` + `.md` files ready for outreach

## File Structure

```
b2b-lead-scout/
├── SKILL.md                              # Main skill file
└── references/
    └── country-search-terms.md            # Local-language search terms per country
```

## Installation

Place the `b2b-lead-scout/` folder into your OpenClaw skills directory:

```
~/.openclaw-autoclaw/skills/b2b-lead-scout/
```

The skill will be auto-discovered on next restart.

## Usage

Trigger phrases:
- "找法国销售健身器材的公司"
- "find B2B distributors Germany"
- "搜索日本工业传感器供应商"
- "找美国中间商销售医疗设备"

## Output

Each search produces two files in the workspace:
- `leads_[product]_[region]_[YYYY-MM-DD].csv` — structured lead list
- `leads_[product]_[region]_[YYYY-MM-DD].md` — summary report

## Data Fields

| Field | Description |
|-------|-------------|
| company_name | Company name |
| location | City, country |
| website | Official website |
| contact_person | Key contact name |
| contact_title | Job title |
| email | Email (官网可见优先) |
| main_products | Main products/services |
| business_type | brand_manufacturer / distributor / reseller / wholesaler / trading_company |
| confidence_score | 1-10 based on data completeness |
| source_url | Primary source link |
| note | Additional notes |

## Dependencies

- **Tavily Search** (`tavily-search` skill) — primary search engine
- **Hunter.io / Apollo.io** — email enrichment (optional, if available)

## Confidence Scoring

| Score | Criteria |
|-------|----------|
| 9-10 | Email + contact + website + product all confirmed |
| 7-8 | Email + product + website confirmed |
| 5-6 | Website + product confirmed, no direct contact |
| 3-4 | Product match likely, not directly verified |
| 1-2 | From news/listing, unclear if actually selling |
