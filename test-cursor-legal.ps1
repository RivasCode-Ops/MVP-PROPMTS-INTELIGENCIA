Write-Host "Testando ambiente juridico (Cursor + MCP)..." -ForegroundColor Cyan

$ErrorActionPreference = "Continue"
$fail = $false

$uvBin = Join-Path $HOME ".local\bin"
if (Test-Path $uvBin) {
    $env:Path = "$uvBin;$env:Path"
}
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

Write-Host "`n1. Node.js" -ForegroundColor Yellow
try {
    node --version
} catch {
    Write-Host "FALHA: Node nao encontrado." -ForegroundColor Red
    $fail = $true
}

Write-Host "`n2. Ollama" -ForegroundColor Yellow
try {
    ollama --version
    ollama list
} catch {
    Write-Host "FALHA: Ollama nao encontrado no PATH." -ForegroundColor Red
    $fail = $true
}

Write-Host "`n3. uv / uvx" -ForegroundColor Yellow
if (Get-Command uv -ErrorAction SilentlyContinue) {
    uv --version
} else {
    Write-Host "AVISO: uv nao no PATH (rode setup-cursor-legal.ps1)." -ForegroundColor Yellow
}

Write-Host "`n4. Pacotes MCP (registro npm)" -ForegroundColor Yellow
try {
    $sd = npm view skill-depot version 2>&1
    Write-Host "skill-depot@$sd" -ForegroundColor Green
} catch {
    Write-Host "FALHA: skill-depot nao resolvido no npm." -ForegroundColor Red
    $fail = $true
}
try {
    $sm = npm view skills-mcp version 2>&1
    Write-Host "skills-mcp@$sm" -ForegroundColor Green
} catch {
    Write-Host "FALHA: skills-mcp nao resolvido no npm." -ForegroundColor Red
    $fail = $true
}
try {
    $km = npm view knowledge-mcp version 2>&1
    Write-Host "knowledge-mcp (npm): $km" -ForegroundColor Green
} catch {
    Write-Host "AVISO: knowledge-mcp pode ser apenas PyPI (ok com uvx)." -ForegroundColor Yellow
}

Write-Host "`n5. Skills no perfil do usuario" -ForegroundColor Yellow
$skillsDir = Join-Path $HOME "skills\direito-imobiliario"
if (Test-Path $skillsDir) {
    Get-ChildItem $skillsDir -Filter "*.md" | ForEach-Object { Write-Host "  - $($_.Name)" }
} else {
    Write-Host "AVISO: pasta nao encontrada: $skillsDir" -ForegroundColor Yellow
}

Write-Host "`n6. KB no perfil do usuario" -ForegroundColor Yellow
$kbDir = Join-Path $HOME "kb\direito-imobiliario"
if (Test-Path $kbDir) {
    Get-ChildItem $kbDir -Filter "*.md" | ForEach-Object { Write-Host "  - $($_.Name)" }
} else {
    Write-Host "AVISO: pasta nao encontrada: $kbDir" -ForegroundColor Yellow
}

Write-Host "`n7. API Ollama (localhost)" -ForegroundColor Yellow
try {
    $r = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5
    Write-Host "API OK (modelos: $($r.models.Count))" -ForegroundColor Green
} catch {
    Write-Host "AVISO: API nao respondeu. Inicie o app Ollama ou o servico." -ForegroundColor Yellow
}

Write-Host "`n8. Arquivos de configuracao" -ForegroundColor Yellow
foreach ($p in @(
    (Join-Path $HOME "kb\config.yaml"),
    (Join-Path $HOME ".cursor\mcp.json"),
    (Join-Path $PSScriptRoot ".cursor\mcp.json")
)) {
    if (Test-Path $p) {
        Write-Host "  OK $p" -ForegroundColor Green
    } else {
        Write-Host "  FALTA $p" -ForegroundColor Yellow
    }
}

if ($fail) {
    Write-Host "`nAlguns testes falharam. Corrija e rode de novo." -ForegroundColor Red
    exit 1
}
Write-Host "`nVerificacao concluida. Reinicie o Cursor se alterou MCP." -ForegroundColor Green
exit 0
