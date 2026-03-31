# b2b-lead-scout

B2B lead discovery skill for AutoClaw / OpenClaw agents. It searches for companies selling specific products in target regions, verifies whether they are relevant trade-facing businesses, enriches each lead with evidence-backed company/contact data, and outputs structured CSV/Markdown lead lists.

## What It Does

1. Accepts a product + region request, such as `find B2B distributors for industrial sensors in Germany`
2. Builds bilingual search queries in English + the target market's local language
3. Searches via Tavily and expands the search when the first pass is too thin
4. Deduplicates candidates using website + company identity rules
5. Verifies product relevance from official sources when possible
6. Enriches each lead with contact and classification data
7. Scores each lead with a deterministic confidence formula
8. Outputs `.csv` + `.md` files that are usable for outreach review

## File Structure

```text
b2b-lead-scout/
|-- README.md
|-- SKILL.md
|-- examples/
|   |-- sample_leads_industrial-sensors_germany.csv
|   |-- sample_leads_industrial-sensors_germany.md
|   `-- sample_batch_leads.md
`-- references/
    `-- country-search-terms.md
```

## Installation

Place the `b2b-lead-scout/` folder into your OpenClaw skills directory:

```text
~/.openclaw-autoclaw/skills/b2b-lead-scout/
```

The skill will be auto-discovered on next restart.

## Typical Prompts

- `find B2B gym equipment distributors in France`
- `search for Japanese industrial sensor suppliers`
- `build a prospect list of medical device importers in Mexico`
- `find Taiwan wholesalers selling packaging machinery`

## Output

Each run produces two files in the workspace:

- `leads_[product_slug]_[region_slug]_[YYYY-MM-DD_HHMM].csv`
- `leads_[product_slug]_[region_slug]_[YYYY-MM-DD_HHMM].md`

The CSV is intended for spreadsheet review. The Markdown file summarizes result quality, lead mix, and follow-up search gaps.

For batch mode, the skill can also produce:

- `batch_leads_[batch_slug]_[YYYY-MM-DD_HHMM].md`

In batch mode, the Markdown output is a single flat table with one row per lead and task-level columns such as `batch_id`, `task_id`, `region`, and `product`. This avoids generating a separate control summary file.

## Sample Outputs

Illustrative output templates live in `examples/`:

- `examples/sample_leads_industrial-sensors_germany.csv`
- `examples/sample_leads_industrial-sensors_germany.md`
- `examples/sample_batch_leads.md`

Use them as formatting references for:

- CSV column order
- how to separate `official_website`, `source_url`, and `evidence_url`
- how to present verification status and confidence
- how to structure the Markdown summary
- how to structure a single-table batch Markdown export

## Output Fields

| Field | Description |
|-------|-------------|
| company_name | Company name |
| country | Target country |
| city_or_region | City, state, or region |
| official_website | Canonical company website |
| source_url | Discovery source |
| evidence_url | URL used to verify product relevance |
| contact_person | Key contact name |
| contact_title | Job title |
| email | Business email |
| email_source | Website / LinkedIn / Hunter / Apollo / other |
| main_products | Relevant products or categories |
| business_type | brand_manufacturer / distributor / wholesaler / reseller / importer / trading_company / unknown |
| verification_status | verified / partial / manual_review |
| confidence_score | 1-10 based on explicit scoring rules |
| note | Gaps, caveats, or context |

For batch-mode Markdown tables, prepend these task-level columns:

- `batch_id`
- `task_id`
- `region`
- `product`
- `requested_business_type`

## Dependencies

- Tavily search capability
- Optional enrichment tools such as Hunter.io or Apollo.io

## Design Principles

- Search in English + local language
- Prefer official websites over directory pages
- Separate `source_url` from `official_website`
- Keep weak evidence, but mark it clearly and score it lower
- Favor a smaller verified list over a larger noisy list
