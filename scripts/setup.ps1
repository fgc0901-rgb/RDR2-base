Param(
    [switch]$Verbose
)

Write-Host "Setting up RDR2-base workspace..."

# Create local folders if missing
$paths = @("logs", "src", "docs")
foreach ($p in $paths) {
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Path $p | Out-Null
        Write-Host "Created $p" -ForegroundColor Green
    }
}

Write-Host "Setup complete."