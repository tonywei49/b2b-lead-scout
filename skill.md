---
name: b2b-lead-scout
description: B2B lead discovery skill. Searches for companies selling specific products in target regions, collects company background (name, location, website, contact person, email, main products), and outputs structured CSV/MD files. Use when doing outbound lead generation, finding B2B distributors or resellers in a specific country or region, or building a prospect list for cold outreach.
---

# B2B Lead Scout

## Overview

Search for B2B companies selling specific products in target regions. Outputs structured lead lists with company info, contacts, and confidence scores.

**Data fields**: company_name, location, website, contact_person, contact_title, email, main_products, business_type, confidence_score, source_url, note

**Output**: .csv file + .md summary in workspace

---

## Step 1 - Parse the Request

Extract from user input:

- **Region**: country, city, or multi-country region (e.g., France, DACH, Southeast Asia)
- **Product**: product/service being sold (e.g., indoor fitness equipment, industrial sensors)
- **B2B type**: brand manufacturer / distributor / reseller / trading company (if not stated, assume all)

If ambiguous, ask one clarifying question before proceeding.

---

## Step 2 - Build Search Queries

Always search in **English + local language** of the target country. Many local B2B companies only appear in local language.

Run 3 EN + 3 local = 6 queries in parallel.

See references/country-search-terms.md for pre-built terms per country.

### Example (France + indoor fitness equipment)

EN:
1. indoor fitness equipment distributor France B2B
2. commercial gym equipment supplier France
3. fitness equipment wholesaler France

FR:
4. distributeur materiel fitness interieur France
5. fournisseur equipement gym commercial France
6. grossiste materiel fitness France B2B

---

## Step 3 - Execute Search

Use **Tavily** as primary search engine.

python skills/tavily-search/tavily.py search QUERY --depth advanced --max-results 20

Run all 6 queries in parallel, collect all results.

---

## Step 4 - Deduplicate Companies

Merge results from all query variations:
- Same company name / domain - keep highest confidence entry
- Same website URL - merge contact fields
- Use domain as primary deduplication key

---

## Step 5 - Enrich with Company + People Research

### 5a. Company Background

Using Tavily search for each company:
- Company overview (founding, size, location)
- Main products/services
- Business type (brand manufacturer / distributor / reseller / wholesaler / trading company)

### 5b. Contact Discovery

Priority order:
1. Official website Contact/Team page - direct email if listed
2. LinkedIn - find key contact (CEO, Sales Director, Purchasing Manager)
3. Hunter.io (if available) - domain search
4. Apollo.io (if available) - domain search
5. Tavily deep search - search for site:company.com email or company.com contact

---

## Step 6 - Confidence Scoring

Score each lead 1-10 based on data completeness:

9-10: Email confirmed + contact person confirmed + website complete + product match clear
7-8: Email confirmed + product match + website complete
5-6: Website confirmed + product match confirmed, no direct email/contact
3-4: Product match likely based on search snippet, no direct verification
1-2: Company mentioned in article/news, unclear if actually selling the product

Additive factors:
- Email found = +3
- Contact name found = +2
- Website complete = +1
- Product explicitly mentioned on site = +2
- Comes from product page vs news/listing = +2

---

## Step 7 - Classify Business Type

- brand_manufacturer - makes the product
- distributor - distributes multiple brands, sells to retailers
- reseller - sells to end customers
- wholesaler - bulk quantities
- trading_company - international trade intermediary
- unknown - insufficient data

---

## Step 8 - Output Files

### CSV Output

File: leads_[product]_[region]_[YYYY-MM-DD].csv
Encoding: UTF-8 with BOM (for Excel compatibility)
Columns: company_name, location, website, contact_person, contact_title, email, main_products, business_type, confidence_score, source_url, note

### MD Summary

File: leads_[product]_[region]_[YYYY-MM-DD].md
Include: total leads, confidence distribution, business type breakdown, top 10 high-confidence leads (score >= 8), data quality issues.

---

## Step 9 - Quality Checks

Before delivering output, verify:
- At least 5 companies found
- At least 50% have website URLs
- Confidence scores are realistic (not all 10s)
- No duplicate companies
- CSV opens correctly in Excel
