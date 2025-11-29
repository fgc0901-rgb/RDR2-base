# Switch-RedM Usage

## Config persistence
- The script stores `RedMPath` in `scripts/SwitchRedM.config.json` after the first prompt if auto-detection fails.
- Delete or edit this file to change the path later.

## Registry detection
- Epic Games Launcher: `HKLM\SOFTWARE\Epic Games\EpicGamesLauncher` → `InstallDir`.
- Rockstar Games Launcher: `HKLM\SOFTWARE\Rockstar Games\Launcher` or `HKLM\SOFTWARE\WOW6432Node\Rockstar Games\Launcher` → `InstallFolder`.
- Steam: resolved via `Get-Command steam.exe` or default `ProgramFiles(x86)`.

## Commands
- Steam direct connect: `Switch-RedM-Account-Advanced.bat STEAM -server=127.0.0.1:30120`
- Using profiles: `Switch-RedM-Account-Advanced.bat -profile=MinhaSteam`
- Interactive menu: `Switch-RedM-Account-Advanced.bat`

## Logs
- Stored under `%LOCALAPPDATA%/RedM/SwitchRedM/logs` with timestamps.
