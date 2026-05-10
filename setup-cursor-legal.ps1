Write-Host "Configurando ambiente juridico para Cursor..." -ForegroundColor Cyan

$ErrorActionPreference = "Stop"

# Caminhos base (usuario atual)
$winUser = $env:UserName
$skillsRoot = "C:\Users\$winUser\skills"
$kbRoot = "C:\Users\$winUser\kb"
$cursorRoot = "C:\Users\$winUser\.cursor"

$skillsPath = Join-Path $skillsRoot "direito-imobiliario"
$kbPath = Join-Path $kbRoot "direito-imobiliario"

New-Item -ItemType Directory -Force -Path $skillsPath | Out-Null
New-Item -ItemType Directory -Force -Path $kbPath | Out-Null
New-Item -ItemType Directory -Force -Path $cursorRoot | Out-Null
Write-Host "Pastas criadas com sucesso." -ForegroundColor Green

# Node.js
if (!(Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "Node.js nao encontrado. Instale em: https://nodejs.org/" -ForegroundColor Yellow
    Start-Process "https://nodejs.org/"
    Read-Host "Pressione Enter apos concluir a instalacao do Node.js"
}

# uv (necessario para uvx / knowledge-mcp)
if (!(Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "Instalando uv..." -ForegroundColor Yellow
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
}

$uvBin = Join-Path $HOME ".local\bin"
if (Test-Path $uvBin) {
    $env:Path = "$uvBin;$env:Path"
}

# Ollama (preferir winget silencioso; fallback instalador GUI)
if (!(Get-Command ollama -ErrorAction SilentlyContinue)) {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Host "Instalando Ollama via winget (pode demorar)..." -ForegroundColor Yellow
        winget install -e --id Ollama.Ollama --accept-package-agreements --accept-source-agreements --silent
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    }
    if (!(Get-Command ollama -ErrorAction SilentlyContinue)) {
        Write-Host "Ollama nao encontrado no PATH. Baixando instalador..." -ForegroundColor Yellow
        $ollamaInstaller = Join-Path $env:TEMP "OllamaSetup.exe"
        Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" -OutFile $ollamaInstaller
        Start-Process $ollamaInstaller -Wait
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    }
}

# Copiar skills/kb do repositorio (mesma pasta deste script) para o perfil do usuario
$repoRoot = $PSScriptRoot
if ($repoRoot -and (Test-Path (Join-Path $repoRoot "skills"))) {
    Write-Host "Sincronizando skills e kb do repositorio..." -ForegroundColor Yellow
    Copy-Item -Path (Join-Path $repoRoot "skills\*") -Destination $skillsRoot -Recurse -Force
}
if ($repoRoot -and (Test-Path (Join-Path $repoRoot "kb"))) {
    Copy-Item -Path (Join-Path $repoRoot "kb\*") -Destination $kbRoot -Recurse -Force
}

Write-Host "Baixando modelo local qwen2.5:7b..." -ForegroundColor Yellow
ollama pull qwen2.5:7b

# Gerar config.yaml com caminho absoluto resolvido
$configYamlPath = Join-Path $kbRoot "config.yaml"
$configYaml = @"
knowledge_base:
  base_dir: "C:/Users/$winUser/kb"

lightrag:
  llm:
    provider: "ollama"
    model_name: "qwen2.5:7b"
    api_url: "http://localhost:11434"

  embedding:
    provider: "huggingface"
    model_name: "sentence-transformers/all-MiniLM-L6-v2"

  retrieval:
    top_k: 5
    hybrid_search: true
    graph_weight: 0.3
    similarity_threshold: 0.7

chunking:
  chunk_size: 1000
  chunk_overlap: 200

logging:
  level: "INFO"
  file: "C:/Users/$winUser/kb/logs.txt"
"@
Set-Content -Path $configYamlPath -Value $configYaml -Encoding UTF8

# Gerar mcp.json com caminho absoluto do usuario atual
$mcpJsonPath = Join-Path $cursorRoot "mcp.json"
$mcpJson = @"
{
  "mcpServers": {
    "skill-depot": {
      "command": "npx",
      "args": ["-y", "skill-depot", "serve"],
      "env": {
        "SKILLS_PATH": "C:/Users/$winUser/skills"
      }
    },
    "skills-mcp": {
      "command": "npx",
      "args": ["-y", "skills-mcp", "-s", "C:/Users/$winUser/skills"]
    },
    "knowledge-mcp": {
      "command": "uvx",
      "args": [
        "knowledge-mcp",
        "--config",
        "C:/Users/$winUser/kb/config.yaml",
        "mcp"
      ]
    }
  }
}
"@
Set-Content -Path $mcpJsonPath -Value $mcpJson -Encoding UTF8

# Espelhar MCP no repositorio (Cursor usa .cursor/mcp.json por projeto)
if ($repoRoot -and (Test-Path $repoRoot)) {
    $projectCursor = Join-Path $repoRoot ".cursor"
    New-Item -ItemType Directory -Force -Path $projectCursor | Out-Null
    $projectMcpPath = Join-Path $projectCursor "mcp.json"
    Set-Content -Path $projectMcpPath -Value $mcpJson -Encoding UTF8
    Write-Host "MCP do projeto atualizado: $projectMcpPath" -ForegroundColor Green
}

Write-Host "Setup concluido." -ForegroundColor Green
Write-Host "Arquivos gerados:" -ForegroundColor Green
Write-Host " - $configYamlPath"
Write-Host " - $mcpJsonPath"
Write-Host "Reinicie o Cursor para recarregar os MCPs." -ForegroundColor Cyan
