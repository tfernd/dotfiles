$tools = @(
    "Starship.Starship", "ajeetdsouza.zoxide",
    "sharkdp.bat", "eza-community.eza", "BurntSushi.ripgrep.MSVC",
    "sharkdp.fd", "dbrgn.tealdeer", "JesseDuffield.lazygit",
    "GitHub.cli", "junegunn.fzf", "dandavison.delta",
    "jqlang.jq", "ducaale.xh", "MikeFarah.yq",
    "sxyazi.yazi", "Clement.bottom", "astral-sh.uv"
)

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "`n[+] Installing Git..." -ForegroundColor Yellow
    winget install --id Git.Git --exact --accept-source-agreements --accept-package-agreements
} else {
    Write-Host "`n[~] Git already installed, skipping." -ForegroundColor Cyan
}

foreach ($tool in $tools) {
    Write-Host "`n[+] Installing $tool..." -ForegroundColor Yellow
    winget install --id $tool --exact --accept-source-agreements --accept-package-agreements
}

if (Test-Path "C:\Windows\Fonts\FiraCodeNerdFont-Regular.ttf") {
    Write-Host "`n[~] FiraCode Nerd Font already installed, skipping." -ForegroundColor Cyan
} else {
    Write-Host "`n[+] Installing FiraCode Nerd Font..." -ForegroundColor Yellow
    $zip = "$env:TEMP\FiraCode.zip"
    $dest = "$env:TEMP\FiraCode"
    Invoke-WebRequest "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip" -OutFile $zip
    Expand-Archive $zip -DestinationPath $dest -Force
    Get-ChildItem "$dest\*.ttf" | ForEach-Object {
        Copy-Item $_.FullName "C:\Windows\Fonts\" -Force
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -Name $_.BaseName -Value $_.Name -Force | Out-Null
    }
}

if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Write-Host "`n[+] Installing bun..." -ForegroundColor Yellow
    powershell -Command "irm bun.sh/install.ps1 | iex"
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
} else {
    Write-Host "`n[~] bun already installed, skipping." -ForegroundColor Cyan
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

if (Get-Command trash -ErrorAction SilentlyContinue) {
    Write-Host "`n[~] trash-cli already installed, skipping." -ForegroundColor Cyan
} else {
    Write-Host "`n[+] Installing trash-cli via bun..." -ForegroundColor Yellow
    bun install -g trash-cli
}

Write-Host "`n[OK] Done! Press Enter to close this window." -ForegroundColor Green
Write-Host "`n[!] Now run 'setup-terminal' from Git Bash to finish the setup (git delta config, shell reload, etc)." -ForegroundColor Cyan
Read-Host