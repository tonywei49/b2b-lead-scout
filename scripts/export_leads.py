#!/usr/bin/env python3
"""Reference exporter for b2b-lead-scout outputs.

This script exists to make exports deterministic:
- CSV is written as UTF-8 with BOM for Excel compatibility
- column order is fixed
- missing values stay as empty cells instead of shifting left
- Markdown tables escape pipes and embedded newlines
"""

from __future__ import annotations

import argparse
import csv
import json
from datetime import datetime
from pathlib import Path
from typing import Any

try:
    from openpyxl import Workbook
except ImportError:  # pragma: no cover - optional dependency
    Workbook = None

SINGLE_COLUMNS = [
    "company_name",
    "country",
    "city_or_region",
    "official_website",
    "source_url",
    "evidence_url",
    "contact_person",
    "contact_title",
    "email",
    "email_source",
    "main_products",
    "business_type",
    "verification_status",
    "confidence_score",
    "note",
]

BATCH_COLUMNS = [
    "batch_id",
    "task_id",
    "region",
    "product",
    "requested_business_type",
    *SINGLE_COLUMNS,
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export lead data to CSV and Markdown.")
    parser.add_argument("--input", required=True, help="Path to a JSON array of lead objects.")
    parser.add_argument("--output-dir", default=".", help="Directory for exported files.")
    parser.add_argument(
        "--mode",
        choices=["single", "batch"],
        required=True,
        help="Export one task or a multi-task batch.",
    )
    parser.add_argument("--product-slug", help="Required for single mode.")
    parser.add_argument("--region-slug", help="Required for single mode.")
    parser.add_argument("--batch-slug", help="Required for batch mode.")
    parser.add_argument(
        "--xlsx",
        action="store_true",
        help="Also write an XLSX file with all cells formatted as text.",
    )
    parser.add_argument(
        "--timestamp",
        help="Optional timestamp override in YYYY-MM-DD_HHMM format.",
    )
    return parser.parse_args()


def slugless_timestamp(raw: str | None) -> str:
    if raw:
        return raw
    return datetime.now().strftime("%Y-%m-%d_%H%M")


def load_records(path: Path) -> list[dict[str, Any]]:
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(data, list):
        raise ValueError("Input JSON must be an array of objects.")
    normalized: list[dict[str, Any]] = []
    for item in data:
        if not isinstance(item, dict):
            raise ValueError("Each row in input JSON must be an object.")
        normalized.append(item)
    return normalized


def normalize_value(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, list):
        return "; ".join(normalize_value(v) for v in value if v is not None)
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def normalize_record(record: dict[str, Any], columns: list[str]) -> dict[str, str]:
    normalized: dict[str, str] = {}
    for column in columns:
        normalized[column] = normalize_value(record.get(column, ""))
    return normalized


def sort_records(records: list[dict[str, Any]], columns: list[str]) -> list[dict[str, str]]:
    normalized = [normalize_record(record, columns) for record in records]

    def sort_key(row: dict[str, str]) -> tuple[int, str, str]:
        try:
            score = int(row.get("confidence_score", "") or 0)
        except ValueError:
            score = 0
        return (-score, row.get("region", ""), row.get("product", ""))

    return sorted(normalized, key=sort_key)


def write_csv(path: Path, rows: list[dict[str, str]], columns: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=columns,
            extrasaction="ignore",
            restval="",
            quoting=csv.QUOTE_ALL,
            lineterminator="\n",
        )
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def md_cell(value: str) -> str:
    return value.replace("|", r"\|").replace("\r\n", "\n").replace("\r", "\n").replace("\n", "<br>")


def write_markdown_table(
    path: Path,
    rows: list[dict[str, str]],
    columns: list[str],
    title: str,
    note: str,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [f"# {title}", "", note, ""]
    header = "| " + " | ".join(columns) + " |"
    separator = "| " + " | ".join(["---"] * len(columns)) + " |"
    lines.append(header)
    lines.append(separator)
    for row in rows:
        line = "| " + " | ".join(md_cell(row[column]) for column in columns) + " |"
        lines.append(line)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_xlsx(path: Path, rows: list[dict[str, str]], columns: list[str]) -> None:
    if Workbook is None:
        raise RuntimeError(
            "openpyxl is required for --xlsx. Install it with: pip install openpyxl"
        )

    path.parent.mkdir(parents=True, exist_ok=True)
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "leads"
    sheet.append(columns)

    for row in rows:
        sheet.append([row[column] for column in columns])

    for row in sheet.iter_rows():
        for cell in row:
            cell.number_format = "@"

    workbook.save(path)


def require(value: str | None, flag: str) -> str:
    if value:
        return value
    raise ValueError(f"{flag} is required for the selected mode.")


def main() -> None:
    args = parse_args()
    input_path = Path(args.input)
    output_dir = Path(args.output_dir)
    timestamp = slugless_timestamp(args.timestamp)
    records = load_records(input_path)

    if args.mode == "single":
        product_slug = require(args.product_slug, "--product-slug")
        region_slug = require(args.region_slug, "--region-slug")
        base_name = f"leads_{product_slug}_{region_slug}_{timestamp}"
        columns = SINGLE_COLUMNS
        rows = sort_records(records, columns)
        write_csv(output_dir / f"{base_name}.csv", rows, columns)
        write_markdown_table(
            output_dir / f"{base_name}.md",
            rows,
            columns,
            title=f"Lead Table: {product_slug} / {region_slug}",
            note="Generated by scripts/export_leads.py. One row = one lead.",
        )
        if args.xlsx:
            write_xlsx(output_dir / f"{base_name}.xlsx", rows, columns)
        return

    batch_slug = require(args.batch_slug, "--batch-slug")
    base_name = f"batch_leads_{batch_slug}_{timestamp}"
    columns = BATCH_COLUMNS
    rows = sort_records(records, columns)
    write_csv(output_dir / f"{base_name}.csv", rows, columns)
    write_markdown_table(
        output_dir / f"{base_name}.md",
        rows,
        columns,
        title=f"Batch Lead Table: {batch_slug}",
        note="Generated by scripts/export_leads.py. One row = one lead.",
    )
    if args.xlsx:
        write_xlsx(output_dir / f"{base_name}.xlsx", rows, columns)


if __name__ == "__main__":
    main()
