$pythonCommand = $null
$pythonAvailable = $false
$openpyxlAvailable = $false
$powershellAvailable = $false
$preferredExporter = "json_fallback"
$xlsxSupported = $false

foreach ($candidate in @("python", "py")) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($null -ne $cmd) {
        $pythonCommand = $candidate
        $pythonAvailable = $true
        break
    }
}

if ($pythonAvailable) {
    & $pythonCommand -c "import openpyxl" 2>$null
    if ($LASTEXITCODE -eq 0) {
        $openpyxlAvailable = $true
        $xlsxSupported = $true
    }
}

if ($PSVersionTable.PSVersion) {
    $powershellAvailable = $true
}

if ($pythonAvailable) {
    $preferredExporter = "python"
}
elseif ($powershellAvailable) {
    $preferredExporter = "powershell"
}

$result = [ordered]@{
    python_available = $pythonAvailable
    python_command = if ($pythonCommand) { $pythonCommand } else { "" }
    openpyxl_available = $openpyxlAvailable
    powershell_available = $powershellAvailable
    preferred_exporter = $preferredExporter
    xlsx_supported = $xlsxSupported
}

$result | ConvertTo-Json -Depth 3
