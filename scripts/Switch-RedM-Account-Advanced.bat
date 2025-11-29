@echo off
chcp 65001 >nul
:: Switch-RedM-Account-Advanced.bat (portable)
:: Objetivo: Alternar entre contas/plataformas (Steam/Epic/Rockstar) para RedM.
:: Portável: sem caminhos fixos; detecta instalacoes; usa variaveis de ambiente.
setlocal EnableExtensions EnableDelayedExpansion

:: =====================
:: Caminhos (tentativas multiplas, sem hardcode de usuario)
:: =====================
set "PF86=%ProgramFiles(x86)%"
set "PF64=%ProgramFiles%"
set "REDM_EXE=%LOCALAPPDATA%\RedM\RedM.exe"
set "STEAM_EXE=%PF86%\Steam\steam.exe"
set "EPIC_EXE=%PF64%\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe"
set "ROCKSTAR_EXE=%PF64%\Rockstar Games\Launcher\Launcher.exe"

:: Timeout padrao para launcher
set "DEFAULT_TIMEOUT=5"

:: Logs
set "ENABLE_LOGS=1"
set "LOG_DIR=%LOCALAPPDATA%\RedM\SwitchRedM\logs"

:: Perfis (mesma pasta do script)
set "PROFILES_FILE=%~dp0SwitchRedMProfiles.txt"

:: Execucao
set "TARGET_PLATFORM="
set "DO_CLEAN_CACHE=0"
set "SERVER_ENDPOINT="
set "TIMEOUT=%DEFAULT_TIMEOUT%"
set "SILENT=0"
set "PROFILE_NAME="

:: =====================
:: Argumentos
:: =====================
for %%A in (%*) do (
  set "arg=%%~A"
  if /I "!arg!"=="STEAM" set "TARGET_PLATFORM=STEAM"
  if /I "!arg!"=="EPIC" set "TARGET_PLATFORM=EPIC"
  if /I "!arg!"=="ROCKSTAR" set "TARGET_PLATFORM=ROCKSTAR"
  if /I "!arg!"=="-clean-cache" set "DO_CLEAN_CACHE=1"
  if /I "!arg!"=="-silent" set "SILENT=1"
  for /f "tokens=1,2 delims==" %%i in ("!arg!") do (
    if /I "%%i"=="-server" set "SERVER_ENDPOINT=%%j"
    if /I "%%i"=="-timeout" set "TIMEOUT=%%j"
    if /I "%%i"=="-profile" set "PROFILE_NAME=%%j"
  )
)

if not defined TARGET_PLATFORM if not defined PROFILE_NAME goto :menu
if defined PROFILE_NAME call :load_profile "%PROFILE_NAME%"

call :detect_paths
call :kill_processes
call :rotate_entitlements || goto :error_rotate
if %DO_CLEAN_CACHE%==1 call :clean_cache || goto :error_cache
call :start_platform "%TARGET_PLATFORM%" || goto :error_platform
if not defined SERVER_ENDPOINT call :ask_endpoint
call :start_redm "%SERVER_ENDPOINT%" || goto :error_redm
call :log "Concluido. Plataforma=%TARGET_PLATFORM% Endpoint=%SERVER_ENDPOINT%"
exit /b 0

:usage
  echo.
  echo Uso:
  echo   %~nx0 STEAM ^| EPIC ^| ROCKSTAR [opcoes]
  echo Opcoes:
  echo   -clean-cache         Limpa caches com backup
  echo   -server=IP:PORTA     Endpoint direto (ex.: 127.0.0.1:30120 ou cfx.re/join/XXXX)
  echo   -timeout=SEG         Espera apos abrir launcher (padrao %DEFAULT_TIMEOUT%s)
  echo   -silent              Modo silencioso
  echo   -profile=Nome        Usa perfil de %~n0Profiles.txt
  exit /b 1

:menu
  cls
  echo ================================
  echo  Switch RedM (Contas/Plataformas)
  echo ================================
  echo [1] Steam
  echo [2] Epic
  echo [3] Rockstar Launcher (Social Club)
  echo [4] Steam + Limpar cache
  echo [5] Epic  + Limpar cache
  echo [6] Gerenciar Perfis
  echo [0] Sair
  set /p opt=Selecione uma opcao: 
  if "%opt%"=="1" set "TARGET_PLATFORM=STEAM" & set "DO_CLEAN_CACHE=0"
  if "%opt%"=="2" set "TARGET_PLATFORM=EPIC" & set "DO_CLEAN_CACHE=0"
  if "%opt%"=="3" set "TARGET_PLATFORM=ROCKSTAR" & set "DO_CLEAN_CACHE=0"
  if "%opt%"=="4" set "TARGET_PLATFORM=STEAM" & set "DO_CLEAN_CACHE=1"
  if "%opt%"=="5" set "TARGET_PLATFORM=EPIC"  & set "DO_CLEAN_CACHE=1"
  if "%opt%"=="6" goto :profiles_menu
  if "%opt%"=="0" exit /b 0
  if not defined TARGET_PLATFORM goto :menu
  goto :flow_from_menu

:flow_from_menu
  call :detect_paths
  call :kill_processes
  call :rotate_entitlements || goto :error_rotate
  if %DO_CLEAN_CACHE%==1 call :clean_cache || goto :error_cache
  call :start_platform "%TARGET_PLATFORM%" || goto :error_platform
  call :ask_endpoint
  call :start_redm "%SERVER_ENDPOINT%" || goto :error_redm
  call :log "Concluido via menu. Plataforma=%TARGET_PLATFORM% Endpoint=%SERVER_ENDPOINT%"
  exit /b 0

:profiles_menu
  cls
  echo ================================
  echo  Perfis
  echo ================================
  echo [1] Listar perfis
  echo [2] Criar perfil
  echo [3] Selecionar perfil
  echo [4] Remover perfil
  echo [9] Voltar
  echo [0] Sair
  set /p popt=Opcao: 
  if "%popt%"=="1" call :list_profiles & pause & goto :profiles_menu
  if "%popt%"=="2" call :create_profile & goto :profiles_menu
  if "%popt%"=="3" call :select_profile_flow & goto :profiles_menu
  if "%popt%"=="4" call :remove_profile & goto :profiles_menu
  if "%popt%"=="9" goto :menu
  if "%popt%"=="0" exit /b 0
  goto :profiles_menu

:list_profiles
  if not exist "%PROFILES_FILE%" (
    echo [i] Nao ha perfis. %PROFILES_FILE% nao existe.
    exit /b 0
  )
  echo Nome,Plataforma,Servidor,Timeout
  for /f "usebackq tokens=1-4 delims=, eol=#" %%a in ("%PROFILES_FILE%") do echo %%a,%%b,%%c,%%d
  exit /b 0

:create_profile
  set "name=" & set "plat=" & set "srv=" & set "tout="
  set /p name=Nome do perfil: 
  set /p plat=Plataforma (STEAM/EPIC/ROCKSTAR): 
  set /p srv=Endpoint padrao (IP:PORTA) [opcional]: 
  set /p tout=Timeout em segundos [Enter=%DEFAULT_TIMEOUT%]: 
  if not defined tout set "tout=%DEFAULT_TIMEOUT%"
  if not defined name echo [!] Nome obrigatorio. & exit /b 1
  if /I not "%plat%"=="STEAM" if /I not "%plat%"=="EPIC" if /I not "%plat%"=="ROCKSTAR" echo [!] Plataforma invalida. & exit /b 1
  if not exist "%PROFILES_FILE%" echo # nome,plataforma,servidor,timeout> "%PROFILES_FILE%"
  echo %name%,%plat%,%srv%,%tout%>>"%PROFILES_FILE%"
  echo [+] Perfil salvo: %name%
  exit /b 0

:select_profile_flow
  call :list_profiles
  set /p pname=Digite o nome exato do perfil: 
  if not defined pname exit /b 1
  call :load_profile "%pname%" || (echo [!] Perfil nao encontrado.& exit /b 1)
  set "TARGET_PLATFORM=%PROFILE_PLATFORM%"
  if not defined SERVER_ENDPOINT set "SERVER_ENDPOINT=%PROFILE_SERVER%"
  if not defined TIMEOUT set "TIMEOUT=%PROFILE_TIMEOUT%"
  goto :flow_from_menu

:remove_profile
  set /p pname=Nome do perfil a remover: 
  if not defined pname exit /b 1
  if not exist "%PROFILES_FILE%" (echo [!] Nao ha arquivo de perfis.& exit /b 1)
  set "TMP=%TEMP%\srmp_%RANDOM%.tmp"
  >"%TMP%" (
    for /f "usebackq tokens=1-4 delims=, eol=#" %%a in ("%PROFILES_FILE%") do (
      if /I not "%%a"=="%pname%" echo %%a,%%b,%%c,%%d
    )
  )
  move /y "%TMP%" "%PROFILES_FILE%" >nul
  echo [+] Removido (se existia): %pname%
  exit /b 0

:load_profile
  set "_pname=%~1"
  if not exist "%PROFILES_FILE%" exit /b 1
  set "PROFILE_PLATFORM="
  set "PROFILE_SERVER="
  set "PROFILE_TIMEOUT="
  for /f "usebackq tokens=1-4 delims=, eol=#" %%a in ("%PROFILES_FILE%") do if /I "%%a"=="%_pname%" (
    set "PROFILE_PLATFORM=%%b"
    set "PROFILE_SERVER=%%c"
    set "PROFILE_TIMEOUT=%%d"
  )
  if not defined PROFILE_PLATFORM exit /b 1
  exit /b 0

:detect_paths
  if not exist "%REDM_EXE%" (
    if exist "%LOCALAPPDATA%\RedM\RedM.exe" set "REDM_EXE=%LOCALAPPDATA%\RedM\RedM.exe"
  )
  if not exist "%REDM_EXE%" (
    for %%D in ("%USERPROFILE%\AppData\Local\RedM\RedM.exe") do if exist "%%~fD" set "REDM_EXE=%%~fD"
  )
  if not exist "%STEAM_EXE%" (
    if exist "%PF64%\Steam\steam.exe" set "STEAM_EXE=%PF64%\Steam\steam.exe"
  )
  if not exist "%STEAM_EXE%" (
    for /f "delims=" %%P in ('where steam.exe 2^>nul') do set "STEAM_EXE=%%P"
  )
  if not exist "%EPIC_EXE%" (
    if exist "%PF86%\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe" set "EPIC_EXE=%PF86%\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe"
  )
  if not exist "%ROCKSTAR_EXE%" (
    if exist "%PF86%\Rockstar Games\Launcher\Launcher.exe" set "ROCKSTAR_EXE=%PF86%\Rockstar Games\Launcher\Launcher.exe"
  )
  call :log "Detectados: REDM=%REDM_EXE% STEAM=%STEAM_EXE% EPIC=%EPIC_EXE% ROCKSTAR=%ROCKSTAR_EXE%"
  exit /b 0

:kill_processes
  for %%P in (RedM.exe, RockstarLauncher.exe, Steam.exe, EpicGamesLauncher.exe) do (
    taskkill /IM %%P >nul 2>&1
    taskkill /F /IM %%P >nul 2>&1
  )
  call :log "Processos encerrados (RedM/Rockstar/Steam/Epic)."
  exit /b 0

:rotate_entitlements
  set "DE_DIR=%LOCALAPPDATA%\RedM"
  set "DE_FILE=%DE_DIR%\DigitalEntitlements"
  if not exist "%DE_DIR%" mkdir "%DE_DIR%" >nul 2>&1
  if exist "%DE_FILE" (
    call :timestamp TS
    ren "%DE_FILE%" "DigitalEntitlements_%TS%.old" >nul 2>&1
    call :log "DigitalEntitlements rotacionado."
  ) else (
    call :log "DigitalEntitlements inexistente."
  )
  exit /b 0

:clean_cache
  set "DATA_DIR=%LOCALAPPDATA%\RedM\RedM.app\data"
  if not exist "%DATA_DIR%" (
    call :log "Sem pasta de dados do RedM: %DATA_DIR%"
    exit /b 0
  )
  call :timestamp TS
  set "BACKUP_DIR=%LOCALAPPDATA%\RedM\SwitchRedM\cache_backup_%TS%"
  mkdir "%BACKUP_DIR%" >nul 2>&1
  for %%F in (cache server-cache server-cache-priv) do if exist "%DATA_DIR%\%%F" (
    move /y "%DATA_DIR%\%%F" "%BACKUP_DIR%\%%F" >nul 2>&1
    call :log "Cache movido: %%F -> %BACKUP_DIR%\%%F"
  )
  exit /b 0

:start_platform
  set "plat=%~1"
  if /I "%plat%"=="STEAM" (
    call :log "Abrindo Steam"
    if exist "%STEAM_EXE%" (
      start "" "%STEAM_EXE%"
    ) else (
      start "" "steam://open/main"
    )
  ) else (
    if /I "%plat%"=="EPIC" (
      call :log "Abrindo Epic"
      if exist "%EPIC_EXE%" (
        start "" "%EPIC_EXE%"
      ) else (
        call :log "[!] Nao encontrei EpicGamesLauncher.exe"
        exit /b 3
      )
    ) else (
      if /I "%plat%"=="ROCKSTAR" (
        call :log "Abrindo Rockstar Launcher"
        if exist "%ROCKSTAR_EXE%" (
          start "" "%ROCKSTAR_EXE%"
        ) else (
          call :log "[!] Nao encontrei Rockstar Launcher"
          exit /b 3
        )
      ) else (
        call :log "[!] Plataforma desconhecida: %plat%"
        exit /b 1
      )
    )
  )
  call :log "Aguardando %TIMEOUT%s"
  ping 127.0.0.1 -n %TIMEOUT% >nul
  exit /b 0

:ask_endpoint
  echo.
  echo Informe o ENDPOINT (IP:PORTA ou cfx.re/join/XXXX):
  set /p SERVER_ENDPOINT=Endpoint: 
  if not defined SERVER_ENDPOINT (
    call :log "Sem endpoint informado. Use Play ou F8 (connect IP:PORTA)."
  ) else (
    call :log "Endpoint: %SERVER_ENDPOINT%"
  )
  exit /b 0

:start_redm
  set "endpoint=%~1"
  if not exist "%REDM_EXE%" (
    call :log "[!] RedM.exe nao encontrado: %REDM_EXE%"
    exit /b 2
  )
  if defined endpoint (
    call :log "Iniciando RedM com +connect %endpoint%"
    start "" "%REDM_EXE%" +connect %endpoint%
  ) else (
    call :log "Iniciando RedM sem endpoint"
    start "" "%REDM_EXE%"
  )
  exit /b 0

:timestamp
  setlocal
  for /f "tokens=1-3 delims=/ " %%a in ("%date%") do set "_d=%%c-%%a-%%b"
  for /f "tokens=1-3 delims=:.," %%a in ("%time%") do set "_t=%%a-%%b-%%c"
  endlocal & set "%1=%_d%_%_t%"
  exit /b 0

:log
  if "%SILENT%"=="1" goto :eof
  echo %~1
  if "%ENABLE_LOGS%"=="1" (
    if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
    if not defined LOG_FILE (
      call :timestamp TS
      set "LOG_FILE=%LOG_DIR%\Switch-RedM-%TS%.log"
      echo [LOG] Criado: %LOG_FILE%
    )
    >>"%LOG_FILE%" echo %date% %time% ^| %~1
  )
  exit /b 0

:error_platform
  call :log "[ERRO] Falha ao abrir launcher"
  exit /b 3
:error_rotate
  call :log "[ERRO] Falha ao rotacionar DigitalEntitlements"
  exit /b 4
:error_cache
  call :log "[ERRO] Falha ao limpar cache"
  exit /b 5
:error_redm
  call :log "[ERRO] Falha ao iniciar RedM"
  exit /b 2

:: Fim
