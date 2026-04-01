---
name: b2b-lead-scout
description: B2B lead discovery skill. Finds companies selling specific products in target regions, verifies whether they are relevant trade-facing businesses, enriches each lead with evidence-backed company/contact data, and outputs structured CSV/MD files for outbound prospecting.
---

# B2B Lead Scout

## Overview

Search for B2B companies selling a specific product in a target region. The goal is not just to collect names, but to produce a shortlist that is evidence-backed, deduplicated, and usable for outreach.

**Primary use cases**:
- Build prospect lists for outbound sales
- Find distributors, wholesalers, importers, dealers, or manufacturers in a country or region
- Research local channel partners before market entry

**Outputs**:
- `leads_[product_slug]_[region_slug]_[YYYY-MM-DD_HHMM].csv`
- `leads_[product_slug]_[region_slug]_[YYYY-MM-DD_HHMM].md`
- `leads_[product_slug]_[region_slug]_[YYYY-MM-DD_HHMM].xlsx` optional
- `batch_leads_[batch_slug]_[YYYY-MM-DD_HHMM].csv` for batch mode
- `batch_leads_[batch_slug]_[YYYY-MM-DD_HHMM].md` for batch mode
- `batch_leads_[batch_slug]_[YYYY-MM-DD_HHMM].xlsx` optional
- formatting reference: `examples/sample_leads_industrial-sensors_germany.csv` and `examples/sample_leads_industrial-sensors_germany.md`
- batch formatting reference: `examples/sample_batch_leads.csv` and `examples/sample_batch_leads.md`
- export helper: `scripts/export_leads.py`

**Required fields**:
- company_name
- country
- city_or_region
- official_website
- source_url
- evidence_url
- contact_person
- contact_title
- email
- email_source
- main_products
- business_type
- verification_status
- confidence_score
- note

**Batch-mode fields**:
- batch_id
- task_id
- region
- product
- requested_business_type

---

## Step 1 - Parse the Request

Extract from the user request:

- **Region**: country, city, or multi-country region such as `France`, `DACH`, or `Southeast Asia`
- **Product**: product or service being sold
- **Business type**: manufacturer / distributor / wholesaler / reseller / importer / trading company

If business type is not specified, search broadly first and classify later.

Ask one clarifying question only if one of these is missing or materially ambiguous:
- target region
- product category
- whether the user wants manufacturers only vs all trade-facing sellers

---

## Step 2 - Build Query Sets

Always search in **English + local language** when the target market is not primarily English-speaking. Local-language search is mandatory because many relevant companies do not rank well in English.

### Stage 1 Query Set

Run these in parallel:
- 3 English queries
- 3 local-language queries

Build them from:
- product term
- business type term
- region term
- optional trade qualifier such as `B2B`, `commercial`, `wholesale`, `OEM`, `supplier`, `dealer`, `importer`

Use `references/country-search-terms.md` for local-language business terms and example phrasing.

### Stage 2 Query Set

If Stage 1 returns fewer than 5 usable companies, expand with 4-8 more queries using:
- synonyms for the product
- alternate business types
- `importer`, `dealer`, `supplier`, `OEM`, `manufacturer`, `wholesale`
- city-level searches for major cities in the region

For multi-country regions such as `DACH` or `SEA`, split by country and run each country separately.

---

## Step 3 - Execute Search

Use **Tavily** as the primary search engine.

Execution requirements:
- run the initial query set in parallel
- collect at least title, snippet, and URL for each result
- prefer official websites, product pages, catalog pages, dealer pages, and team/contact pages
- treat marketplace pages, directory sites, and news articles as secondary evidence only

Do not hardcode a single script path. Use the available Tavily tool or the environment's Tavily search wrapper.

---

## Step 4 - Extract Candidate Companies

For each search result, extract or infer:
- candidate company name
- candidate domain
- candidate country or city
- possible product relevance
- possible business type

Do not treat a listing platform or marketplace as the company itself unless the company identity is explicit.

---

## Step 5 - Deduplicate Carefully

Use domain as the primary key, but do not rely on it alone.

Deduplication rules:
- normalize URLs before comparing: remove protocol noise, `www`, tracking params, and trailing slash
- merge entries when `official_website` matches
- also compare `company_name + country` for likely duplicates
- keep the strongest evidence bundle, not just the first result
- keep `source_url` separate from `official_website`

Do not merge distinct subsidiaries or country branches unless the legal entity is clearly the same and the output is meant to be group-level.

---

## Step 6 - Enrich Company Data

For each deduplicated company, verify against the official website when possible.

Collect:
- official website
- city / country
- short company description
- main products or product categories
- business type
- evidence URL showing the product match

Prefer official evidence in this order:
1. product page
2. category page
3. about page
4. contact page

If only directory/news evidence exists, mark the lead for manual review.

---

## Step 7 - Find a Contact

Priority order:
1. official website contact or team page
2. official email on website
3. LinkedIn public profile for a relevant role
4. Hunter.io or Apollo.io domain lookup, if available
5. additional Tavily searches such as `site:company.com email`, `site:company.com contact`, or `[company name] sales manager`

Preferred contact roles:
- Sales Director
- Business Development Manager
- Export Manager
- Purchasing Manager
- CEO / Founder for small companies

Only collect publicly visible business contact data. Prefer role-based or work email over personal data.

---

## Step 8 - Classify Business Type

Choose the best-fit label:

- `brand_manufacturer`: makes the product or owns the brand
- `distributor`: distributes one or more brands to dealers or resellers
- `wholesaler`: sells in bulk, often trade-only
- `reseller`: mainly sells finished goods onward, often to end buyers or smaller accounts
- `importer`: emphasizes import and local distribution
- `trading_company`: intermediary focused on sourcing / international trade
- `unknown`: insufficient evidence

Base the classification on explicit website language whenever possible.

---

## Step 9 - Score Confidence

Use a **deterministic** formula.

Start from `0` and add:
- official website confirmed: `+2`
- product explicitly shown on official site: `+3`
- business type explicitly supported by evidence: `+1`
- named contact found: `+1`
- business email found: `+2`
- evidence comes from official product/category/contact page rather than a directory/news page: `+1`

Apply penalties:
- only directory/listing evidence, no official site confirmation: `-3`
- company relevance inferred only from snippet, not verified: `-2`
- no product evidence on site: `-2`

Then clamp the result to `1-10`.

Verification labels:
- `verified`: official site confirms product relevance
- `partial`: company is likely relevant but evidence is incomplete
- `manual_review`: only indirect or weak evidence is available

Interpretation:
- `9-10`: strong lead, outreach-ready
- `7-8`: good lead, minor gaps only
- `5-6`: plausible lead, should be reviewed before outreach
- `1-4`: weak or indirect lead

---

## Step 10 - Write Output Files

### CSV

Filename:
- `leads_[product_slug]_[region_slug]_[YYYY-MM-DD_HHMM].csv`

Rules:
- export with **Python only**; do not hand-build CSV with string concatenation
- use `encoding='utf-8-sig'` for Excel compatibility
- open the file with `newline=''`
- use Python `csv.DictWriter` with an explicit `fieldnames` list
- quote all fields to protect commas, line breaks, and delimiter confusion
- convert `None` to an empty string `''`
- never drop a column when a value is empty
- keep column order stable across runs
- slugify `product` and `region` for safe filenames
- one row per company

Columns:
- company_name
- country
- city_or_region
- official_website
- source_url
- evidence_url
- contact_person
- contact_title
- email
- email_source
- main_products
- business_type
- verification_status
- confidence_score
- note

Why this is mandatory:
- if the file is not written as `utf-8-sig`, Excel often shows Chinese text as mojibake
- if empty fields are skipped instead of emitted as empty cells, later values shift left and columns no longer match
- if commas or line breaks are not quoted correctly, spreadsheet apps split one logical cell into multiple columns or rows
- if phone-like or ID-like values are opened in Excel, CSV may still be auto-formatted as scientific notation; export `.xlsx` as a secondary file when exact spreadsheet display matters

### Batch CSV

When the user requests a **batch search** across multiple product/region tasks, also write:
- `batch_leads_[batch_slug]_[YYYY-MM-DD_HHMM].csv`

In batch CSV mode:
- one row = one company lead
- use the same column order as batch Markdown mode
- sort rows by `confidence_score` descending, then by `region`, then by `product`
- use the same Python export rules as single CSV mode
- use UTF-8 with BOM for spreadsheet compatibility

Required batch CSV columns:
- batch_id
- task_id
- region
- product
- requested_business_type
- company_name
- country
- city_or_region
- official_website
- source_url
- evidence_url
- contact_person
- contact_title
- email
- email_source
- main_products
- business_type
- verification_status
- confidence_score
- note

Use the exact column order shown in `examples/sample_batch_leads.csv`.

### Optional XLSX Export

If the output contains values that Excel tends to auto-convert, such as:
- phone numbers
- long numeric strings
- postal codes
- IDs with leading zeroes

also export an `.xlsx` file from Python.

XLSX rules:
- write the same column order as the CSV
- write all values as strings
- set all worksheet cells to text format
- use XLSX as the display-safe spreadsheet artifact
- keep CSV as the interchange artifact

### Markdown Summary

Filename:
- `leads_[product_slug]_[region_slug]_[YYYY-MM-DD_HHMM].md`

Include:
- search request summary
- total leads found
- confidence distribution
- business type breakdown
- top high-confidence leads
- manual-review leads
- data quality issues
- search gaps and suggested follow-up queries

Follow the section order and field naming shown in `examples/sample_leads_industrial-sensors_germany.md`.

Markdown export rules:
- export with Python only; do not hand-build rows with inconsistent separators
- convert `None` to `''`
- replace embedded newlines in cell values with `<br>`
- escape pipe characters `|` inside cell values
- keep the header and separator row fixed

Markdown does **not** have the same encoding issue as CSV in Excel, but malformed row rendering can still happen if:
- a cell contains an unescaped `|`
- a cell contains raw line breaks
- the row is emitted with fewer cells than the header

Therefore the Markdown table must also be generated programmatically from a fixed column list.

### Batch Markdown Table

When the user requests a **batch search** across multiple product/region tasks, do **not** generate one Markdown report per task and do **not** generate a separate summary/control report.

Instead, write a single Markdown file:
- `batch_leads_[batch_slug]_[YYYY-MM-DD_HHMM].md`

This file must contain:
- one short title
- one short note describing the batch
- one flat Markdown table containing **all leads from all tasks**

In batch mode:
- one row = one company lead
- include task context directly in the row
- sort rows by `confidence_score` descending, then by `region`, then by `product`
- keep the column order stable across runs
- do not add narrative sections below the table unless the user explicitly asks for them

Required batch Markdown columns:
- batch_id
- task_id
- region
- product
- requested_business_type
- company_name
- country
- city_or_region
- official_website
- source_url
- evidence_url
- contact_person
- contact_title
- email
- email_source
- main_products
- business_type
- verification_status
- confidence_score
- note

Use the exact table style shown in `examples/sample_batch_leads.md`.

---

## Step 11 - Quality Gates

Before delivering results, check:
- at least 5 companies found, or explain why not
- at least 70% of final rows have an official website
- confidence scores are distributed realistically
- no obvious duplicates remain
- every lead with score `>= 7` has an evidence URL
- CSV opens correctly in Excel

If quality gates are not met:
- run Stage 2 expanded search
- lower confidence where evidence is weak
- clearly mark unresolved entries as `manual_review`

---

## Execution Notes

- Prefer precision over volume. A smaller verified list is better than a larger noisy list.
- Keep directories and news pages as discovery inputs, not final evidence when better sources exist.
- When in doubt, preserve the row but lower the score and explain the gap in `note`.
