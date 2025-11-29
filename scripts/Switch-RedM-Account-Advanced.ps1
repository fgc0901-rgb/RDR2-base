Param(
    [ValidateSet('STEAM','EPIC','ROCKSTAR')]
    [string]$Platform,
    [string]$Server,
    [int]$Timeout = 5,
    [switch]$CleanCache,
    [switch]$Silent,
    [string]$Profile
)

$ErrorActionPreference = 'Stop'

$ConfigPath = Join-Path $PSScriptRoot 'SwitchRedM.config.json'

function Load-Config {
    if (Test-Path $ConfigPath) {
        try { return Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json } catch { }
    }
    return [pscustomobject]@{ RedMPath = $null }
}

function Save-Config($cfg) {
    try { $cfg | ConvertTo-Json -Depth 3 | Set-Content -Path $ConfigPath -Encoding UTF8 } catch { }
}

function Write-Log([string]$msg) {
    if ($Silent) { return }
    Write-Host $msg
    $logDir = Join-Path $env:LOCALAPPDATA 'RedM\SwitchRedM\logs'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
    if (-not $script:LogFile) {
        $ts = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
        $script:LogFile = Join-Path $logDir "Switch-RedM-$ts.log"
        Write-Host "[LOG] Criado: $script:LogFile"
    }
    Add-Content -Path $script:LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $msg"
}

function Detect-Paths {
    $cfg = Load-Config
    $paths = [ordered]@{
        REDM      = $cfg.RedMPath
        STEAM     = "$env:ProgramFiles(x86)\Steam\steam.exe"
        EPIC      = "$env:ProgramFiles\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe"
        ROCKSTAR  = "$env:ProgramFiles\Rockstar Games\Launcher\Launcher.exe"
    }
    # RedM path detection
    if (-not $paths.REDM) {
        $candidate = Join-Path $env:LOCALAPPDATA 'RedM\RedM.exe'
        if (Test-Path $candidate) { $paths.REDM = $candidate }
    }
    if (-not (Test-Path $paths.REDM)) {
        $candidate = Join-Path $env:USERPROFILE 'AppData\Local\RedM\RedM.exe'
        if (Test-Path $candidate) { $paths.REDM = $candidate }
    }
    # Steam detection
    if (-not (Test-Path $paths.STEAM)) {
        $cmd = Get-Command steam.exe -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) { $paths.STEAM = $cmd.Source }
    }
    # Epic via registry
    if (-not (Test-Path $paths.EPIC)) {
        try {
            $regPath = 'HKLM:\SOFTWARE\Epic Games\EpicGamesLauncher'
            $inst = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
            if ($inst -and $inst.InstallDir) {
                $ep = Join-Path $inst.InstallDir 'Portal\Binaries\Win64\EpicGamesLauncher.exe'
                if (Test-Path $ep) { $paths.EPIC = $ep }
            }
        } catch {}
    }
    # Rockstar via registry
    if (-not (Test-Path $paths.ROCKSTAR)) {
        foreach ($rp in 'HKLM:\SOFTWARE\Rockstar Games\Launcher','HKLM:\SOFTWARE\WOW6432Node\Rockstar Games\Launcher') {
            try {
                $p = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue
                if ($p -and $p.InstallFolder) {
                    $rl = Join-Path $p.InstallFolder 'Launcher.exe'
                    if (Test-Path $rl) { $paths.ROCKSTAR = $rl; break }
                }
            } catch {}
        }
    }
    Write-Log "Detectados: REDM=$($paths.REDM) STEAM=$($paths.STEAM) EPIC=$($paths.EPIC) ROCKSTAR=$($paths.ROCKSTAR)"
    return $paths
}

function Kill-Processes {
    foreach ($p in 'RedM','RockstarLauncher','Steam','EpicGamesLauncher') {
        Get-Process -Name $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Write-Log 'Processos encerrados (RedM/Rockstar/Steam/Epic).'
}

function Rotate-Entitlements {
    $deDir = Join-Path $env:LOCALAPPDATA 'RedM'
    $deFile = Join-Path $deDir 'DigitalEntitlements'
    if (-not (Test-Path $deDir)) { New-Item -ItemType Directory -Path $deDir | Out-Null }
    if (Test-Path $deFile) {
        $ts = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
        $backup = Join-Path $deDir "DigitalEntitlements_$ts.old"
        Rename-Item -Path $deFile -NewName (Split-Path -Leaf $backup) -ErrorAction SilentlyContinue
        Write-Log "DigitalEntitlements renomeado para: $backup"
    } else {
        Write-Log 'DigitalEntitlements inexistente (seguiremos).'
    }
}

function Clean-Cache {
    $dataDir = Join-Path $env:LOCALAPPDATA 'RedM\RedM.app\data'
    if (-not (Test-Path $dataDir)) { Write-Log "Sem pasta de dados do RedM: $dataDir"; return }
    $ts = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $backupDir = Join-Path $env:LOCALAPPDATA "RedM\SwitchRedM\cache_backup_$ts"
    if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }
    foreach ($f in 'cache','server-cache','server-cache-priv') {
        $src = Join-Path $dataDir $f
        if (Test-Path $src) {
            Move-Item -Path $src -Destination (Join-Path $backupDir $f) -Force -ErrorAction SilentlyContinue
            Write-Log "Cache movido para backup: $f -> $(Join-Path $backupDir $f)"
        }
    }
}

function Start-Platform([string]$plat, $paths, [int]$waitSec) {
    switch -Regex ($plat) {
        '^STEAM$' {
            Write-Log 'Abrindo Steam'
            if (Test-Path $paths.STEAM) { Start-Process $paths.STEAM } else { Start-Process 'steam://open/main' }
        }
        '^EPIC$' {
            Write-Log 'Abrindo Epic'
            if (Test-Path $paths.EPIC) { Start-Process $paths.EPIC } else { throw '[!] Nao encontrei EpicGamesLauncher.exe' }
        }
        '^ROCKSTAR$' {
            Write-Log 'Abrindo Rockstar Launcher'
            if (Test-Path $paths.ROCKSTAR) { Start-Process $paths.ROCKSTAR } else { throw '[!] Nao encontrei Rockstar Launcher' }
        }
        default { throw "[!] Plataforma desconhecida: $plat" }
    }
    Write-Log "Aguardando ${waitSec}s"
    Start-Sleep -Seconds $waitSec
}

function Ask-Endpoint {
    if ($Server) { Write-Log "Endpoint definido: $Server"; return }
    Write-Host ''
    $Server = Read-Host 'Informe o ENDPOINT (IP:PORTA ou cfx.re/join/XXXX)'
    if (-not $Server) { Write-Log 'Sem endpoint informado. Use Play ou F8 (connect IP:PORTA).' }
    return $Server
}

function Start-RedM([string]$endpoint, $paths) {
    if (-not (Test-Path $paths.REDM)) {
        Write-Log "[!] RedM.exe nao encontrado: $($paths.REDM)"
        $new = Read-Host 'Informe o caminho completo para RedM.exe (ou Enter para cancelar)'
        if (-not $new) { throw '[!] RedM.exe ausente; cancelado.' }
        if (-not (Test-Path $new)) { throw '[!] Caminho informado invalido.' }
        $paths.REDM = $new
        $cfg = Load-Config; $cfg.RedMPath = $new; Save-Config $cfg
        Write-Log "[+] RedMPath salvo em $ConfigPath"
    }
    if ($endpoint) {
        Write-Log "Iniciando RedM com +connect $endpoint"
        Start-Process -FilePath $paths.REDM -ArgumentList "+connect $endpoint"
    } else {
        Write-Log 'Iniciando RedM sem endpoint (use Play ou F8 -> connect IP:PORTA)'
        Start-Process -FilePath $paths.REDM
    }
}

function Load-Profile([string]$name) {
    $profilesFile = Join-Path $PSScriptRoot 'SwitchRedMProfiles.txt'
    if (-not (Test-Path $profilesFile)) { throw '[!] Nao ha arquivo de perfis.' }
    $lines = Get-Content -Path $profilesFile | Where-Object { $_ -and -not $_.Trim().StartsWith('#') }
    foreach ($line in $lines) {
        $parts = $line.Split(',')
        if ($parts[0] -ieq $name) {
            $t = $null
            if ($parts.Count -ge 4) { $t = [int]($parts[3] -as [int]) }
            if (-not $t) { $t = $Timeout }
            return [pscustomobject]@{ Name=$parts[0]; Platform=$parts[1]; Server=$parts[2]; Timeout=$t }
        }
    }
    throw '[!] Perfil nao encontrado.'
}

try {
    $paths = Detect-Paths
    Kill-Processes
    Rotate-Entitlements
    if ($CleanCache) { Clean-Cache }

    if ($Profile) {
        $p = Load-Profile -name $Profile
        if (-not $Platform) { $Platform = $p.Platform }
        if (-not $Server)   { $Server   = $p.Server }
        if ($Timeout -eq 5 -and $p.Timeout) { $Timeout = [int]$p.Timeout }
    }

    if (-not $Platform) {
        Write-Host "==============================="
        Write-Host " Switch RedM (Contas/Plataformas)"
        Write-Host "==============================="
        Write-Host "[1] Steam"
        Write-Host "[2] Epic"
        Write-Host "[3] Rockstar Launcher (Social Club)"
        Write-Host "[4] Steam + Limpar cache"
        Write-Host "[5] Epic  + Limpar cache"
        Write-Host "[6] Gerenciar Perfis (via arquivo)"
        Write-Host "[0] Sair"
        $opt = Read-Host 'Selecione uma opcao'
        switch ($opt) {
            '1' { $Platform='STEAM' }
            '2' { $Platform='EPIC' }
            '3' { $Platform='ROCKSTAR' }
            '4' { $Platform='STEAM'; $CleanCache=$true }
            '5' { $Platform='EPIC';  $CleanCache=$true }
            '0' { return }
            default { return }
        }
    }

    Start-Platform -plat $Platform -paths $paths -waitSec $Timeout
    $Server = Ask-Endpoint
    Start-RedM -endpoint $Server -paths $paths
    Write-Log "Concluido. Plataforma=$Platform Endpoint=$Server"
}
catch {
    Write-Log "[ERRO] $_"
    exit 1
}
