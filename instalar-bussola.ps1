#Requires -Version 5.0
# ============================================================
#  Bussola - instalador automatico
# ============================================================
#  Este script:
#  1. Guarda uma copia do seu .env (suas credenciais)
#  2. Apaga o conteudo antigo da pasta do projeto
#  3. Extrai o zip novo no lugar
#  4. Restaura o .env
#  5. Roda flutter create / pub get / run -d chrome
#
#  Voce so precisa: colocar este arquivo e o
#  "bussola-projeto-final.zip" DENTRO da pasta
#  Documentos\GitHub\Bussola, e dar 2 cliques neste script.
# ============================================================

$ErrorActionPreference = "Stop"
$pastaAtual = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $pastaAtual

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Bussola - instalador automatico" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- 1. Confirma que o zip esta aqui ---
$zip = Join-Path $pastaAtual "bussola-projeto-final.zip"
if (-not (Test-Path $zip)) {
    Write-Host "ERRO: nao encontrei 'bussola-projeto-final.zip' nesta pasta." -ForegroundColor Red
    Write-Host "Baixe o zip e coloque ele na mesma pasta deste script." -ForegroundColor Red
    Read-Host "Aperte Enter para fechar"
    exit 1
}

Write-Host "Isto vai APAGAR o conteudo antigo desta pasta (menos .env, .git, web, .dart_tool, build)"
Write-Host "e colocar a versao nova no lugar."
$confirmacao = Read-Host "Digite SIM para continuar"
if ($confirmacao -ne "SIM") {
    Write-Host "Cancelado. Nada foi alterado."
    Read-Host "Aperte Enter para fechar"
    exit 0
}

# --- 2. Guarda o .env em outro lugar, temporariamente ---
$envBackup = $null
if (Test-Path ".env") {
    $envBackup = Join-Path $env:TEMP "bussola_env_backup.txt"
    Copy-Item ".env" $envBackup -Force
    Write-Host "-> .env salvo temporariamente."
}

# --- 3. Apaga tudo, exceto o que precisa sobreviver ---
$preservar = @(".git", "web", ".dart_tool", "build", "bussola-projeto-final.zip", (Split-Path -Leaf $MyInvocation.MyCommand.Path))
Get-ChildItem -Force | Where-Object { $preservar -notcontains $_.Name } | ForEach-Object {
    Write-Host "Apagando: $($_.Name)"
    Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
}

# --- 4. Extrai o zip novo ---
Write-Host "-> Extraindo o projeto novo..."
$pastaTemp = Join-Path $env:TEMP "bussola_extract"
if (Test-Path $pastaTemp) { Remove-Item $pastaTemp -Recurse -Force }
Expand-Archive -Path $zip -DestinationPath $pastaTemp -Force

# O zip foi feito de dentro da pasta do projeto, entao o conteudo
# extraido ja vem na raiz certa (nao numa subpasta extra).
Copy-Item (Join-Path $pastaTemp "*") $pastaAtual -Recurse -Force

# --- 5. Restaura o .env ---
if ($envBackup -and (Test-Path $envBackup)) {
    Copy-Item $envBackup ".env" -Force
    Write-Host "-> .env restaurado."
} else {
    Write-Host "AVISO: nenhum .env encontrado para restaurar. Voce vai precisar criar um." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " Arquivos atualizados!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

# --- 6. Roda os comandos do Flutter ---
Write-Host "-> Rodando: flutter create ."
flutter create .

Write-Host "-> Rodando: flutter pub get"
flutter pub get

Write-Host "-> Rodando: flutter run -d chrome"
Write-Host "(isso pode demorar um pouco na primeira vez)"
flutter run -d chrome

Read-Host "Aperte Enter para fechar"
