#!/usr/bin/env bash
# ============================================================================
# WINDOWS SPECIFIC QUIRKS & POWER SHELL WRAPPERS
# ============================================================================

# Recycle Bin Management via PowerShell
function trash-list() {
    powershell.exe -NoProfile -Command - <<'EOF' 2>/dev/null
        $shell = New-Object -ComObject Shell.Application
        $bin = $shell.Namespace(0xA)
        $items = $bin.Items()
        if ($items.Count -eq 0) {
            Write-Host '🗑️  Recycle Bin is empty.' -ForegroundColor Green
        } else {
            Write-Host "🗑️  Recycle Bin ($($items.Count) items):" -ForegroundColor Yellow
            $results = $items | ForEach-Object {
                [PSCustomObject]@{
                    Name        = $_.Name
                    Size        = $bin.GetDetailsOf($_, 2)
                    DateDeleted = $bin.GetDetailsOf($_, 3)
                }
            }
            $results | Format-Table -AutoSize
        }
EOF
}

function empty-trash() {
    powershell.exe -NoProfile -Command - <<'EOF'
        $shell = New-Object -ComObject Shell.Application
        $bin = $shell.Namespace(0xA)
        if ($bin.Items().Count -eq 0) {
            Write-Host '🗑️  Recycle Bin is already empty.' -ForegroundColor Green
        } else {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            Write-Host '✅ Recycle Bin emptied.' -ForegroundColor Green
        }
EOF
}
