param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet("single", "batch")]
    [string]$Mode,

    [string]$OutputDir = ".",
    [string]$ProductSlug,
    [string]$RegionSlug,
    [string]$BatchSlug,
    [string]$Timestamp
)

$SingleColumns = @(
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
    "note"
)

$BatchColumns = @(
    "batch_id",
    "task_id",
    "region",
    "product",
    "requested_business_type"
) + $SingleColumns

function Require-Value {
    param(
        [string]$Value,
        [string]$Flag
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Flag is required for the selected mode."
    }

    return $Value
}

function Get-TimestampValue {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return (Get-Date).ToString("yyyy-MM-dd_HHmm")
    }

    return $Value
}

function Normalize-Value {
    param($Value)

    if ($null -eq $Value) {
        return ""
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $parts = @()
        foreach ($item in $Value) {
            if ($null -ne $item) {
                $parts += [string]$item
            }
        }
        return ($parts -join "; ")
    }

    if ($Value -is [bool]) {
        if ($Value) { return "true" }
        return "false"
    }

    return [string]$Value
}

function Normalize-Record {
    param(
        $Record,
        [string[]]$Columns
    )

    $row = [ordered]@{}
    foreach ($column in $Columns) {
        $row[$column] = Normalize-Value $Record.$column
    }
    return [pscustomobject]$row
}

function Get-SortKeyScore {
    param($Row)

    $parsed = 0
    [void][int]::TryParse([string]$Row.confidence_score, [ref]$parsed)
    return $parsed
}

function Sort-Records {
    param(
        [object[]]$Records,
        [string[]]$Columns
    )

    $normalized = foreach ($record in $Records) {
        Normalize-Record -Record $record -Columns $Columns
    }

    return $normalized | Sort-Object `
        @{ Expression = { -(Get-SortKeyScore $_) } }, `
        @{ Expression = { [string]($_.region) } }, `
        @{ Expression = { [string]($_.product) } }
}

function Quote-CsvValue {
    param([string]$Value)

    $escaped = $Value.Replace('"', '""')
    return '"' + $escaped + '"'
}

function Write-CsvFile {
    param(
        [string]$Path,
        [object[]]$Rows,
        [string[]]$Columns
    )

    $dir = Split-Path -Parent $Path
    if ($dir) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    $writer = [System.IO.StreamWriter]::new($Path, $false, $utf8Bom)
    try {
        $writer.WriteLine(($Columns | ForEach-Object { Quote-CsvValue $_ }) -join ",")
        foreach ($row in $Rows) {
            $cells = foreach ($column in $Columns) {
                Quote-CsvValue ([string]$row.$column)
            }
            $writer.WriteLine(($cells -join ","))
        }
    }
    finally {
        $writer.Dispose()
    }
}

function Escape-MarkdownCell {
    param([string]$Value)

    return $Value.Replace("|", "\|").Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "<br>")
}

function Write-MarkdownFile {
    param(
        [string]$Path,
        [object[]]$Rows,
        [string[]]$Columns,
        [string]$Title,
        [string]$Note
    )

    $dir = Split-Path -Parent $Path
    if ($dir) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# $Title")
    $lines.Add("")
    $lines.Add($Note)
    $lines.Add("")
    $lines.Add("| " + ($Columns -join " | ") + " |")
    $lines.Add("| " + (($Columns | ForEach-Object { "---" }) -join " | ") + " |")

    foreach ($row in $Rows) {
        $cells = foreach ($column in $Columns) {
            Escape-MarkdownCell ([string]$row.$column)
        }
        $lines.Add("| " + ($cells -join " | ") + " |")
    }

    [System.IO.File]::WriteAllLines($Path, $lines, [System.Text.Encoding]::UTF8)
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object[]]$Rows
    )

    $dir = Split-Path -Parent $Path
    if ($dir) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $json = $Rows | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.Encoding]::UTF8)
}

$timestampValue = Get-TimestampValue $Timestamp
$outputRoot = (Resolve-Path -LiteralPath $OutputDir -ErrorAction SilentlyContinue)
if ($null -eq $outputRoot) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    $outputRoot = Resolve-Path -LiteralPath $OutputDir
}

$raw = Get-Content -LiteralPath $InputPath -Raw -Encoding UTF8
if ($raw.Length -gt 0 -and [int][char]$raw[0] -eq 0xFEFF) {
    $raw = $raw.Substring(1)
}

$records = $raw | ConvertFrom-Json
if ($records -isnot [System.Collections.IEnumerable] -or $records -is [string]) {
    throw "Input JSON must be an array of objects."
}

if ($Mode -eq "single") {
    $productValue = Require-Value -Value $ProductSlug -Flag "--ProductSlug"
    $regionValue = Require-Value -Value $RegionSlug -Flag "--RegionSlug"
    $baseName = "leads_{0}_{1}_{2}" -f $productValue, $regionValue, $timestampValue
    $rows = Sort-Records -Records @($records) -Columns $SingleColumns
    Write-CsvFile -Path (Join-Path $outputRoot.Path "$baseName.csv") -Rows $rows -Columns $SingleColumns
    Write-MarkdownFile -Path (Join-Path $outputRoot.Path "$baseName.md") -Rows $rows -Columns $SingleColumns -Title "Lead Table: $productValue / $regionValue" -Note "Generated by scripts/export_leads.ps1. One row = one lead."
    Write-JsonFile -Path (Join-Path $outputRoot.Path "$baseName.json") -Rows $rows
    return
}

$batchValue = Require-Value -Value $BatchSlug -Flag "--BatchSlug"
$batchBaseName = "batch_leads_{0}_{1}" -f $batchValue, $timestampValue
$batchRows = Sort-Records -Records @($records) -Columns $BatchColumns
Write-CsvFile -Path (Join-Path $outputRoot.Path "$batchBaseName.csv") -Rows $batchRows -Columns $BatchColumns
Write-MarkdownFile -Path (Join-Path $outputRoot.Path "$batchBaseName.md") -Rows $batchRows -Columns $BatchColumns -Title "Batch Lead Table: $batchValue" -Note "Generated by scripts/export_leads.ps1. One row = one lead."
Write-JsonFile -Path (Join-Path $outputRoot.Path "$batchBaseName.json") -Rows $batchRows
