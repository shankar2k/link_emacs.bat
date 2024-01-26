@echo off
rem link_emacs.bat --- Fix path, context menu, and daemon links after Emacs upgrade
rem
rem Copyright (C) 2024 Shankar Rao
rem
rem
rem * Commentary:
rem
rem This Windows batch script updates the PATH environment variable, commands
rem in the context menu and the link to the Emacs daemon in Task Scheduler to
rem refer to the latest installed version of Emacs.
rem
rem See documentation on https://github.com/shankar2k/link_emacs.bat/.
rem
rem * License:
rem
rem This program is free software; you can redistribute it and/or modify
rem it under the terms of the GNU General Public License as published by
rem the Free Software Foundation, either version 3 of the License, or
rem (at your option) any later version.
rem
rem This program is distributed in the hope that it will be useful,
rem but WITHOUT ANY WARRANTY; without even the implied warranty of
rem MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
rem GNU General Public License for more details.
rem
rem You should have received a copy of the GNU General Public License
rem along with this program.  If not, see <http://www.gnu.org/licenses/>.
rem
rem * History:
rem
rem Version 0.1 (2024-01-25):
rem
rem - Initial version
rem
rem * Code:

setlocal enabledelayedexpansion
set EMACSROOT=C:\Program Files\Emacs

rem Find latest Emacs version
for /f "tokens=*" %%f in ('dir /b "%EMACSROOT%\Emacs-*"') do set latest=%%f
set EMACSBINDIR=%EMACSROOT%\%latest%\x86_64\bin
echo Found latest version %latest%.

rem Update Emacs version in User PATH environment variable
for /f "skip=2tokens=1-2*" %%a in ('reg query HKCU\Environment /v PATH 2^>Nul') do set MYPATH=%%c
echo %MYPATH% > temp.txt
findstr /r "%EMACSROOT:\=\\%" temp.txt > nul
if errorlevel 1 (
    echo Emacs not found in User PATH, adding ...
    set "MYPATH=!MYPATH!;!EMACSBINDIR!"
) else (
    echo Emacs found in User PATH, updating ...
    set "EPATH=!MYPATH:\=\\!"
    set UPDATEPATHCMD="(princ (replace-regexp-in-string \"Emacs-[0-9]+\\.[0-9]+\" \"!latest!\" \"!EPATH!\"))"
    echo UPDATECMD = !UPDATEPATHCMD!
    "!EMACSBINDIR!\emacs.exe" --batch --eval !UPDATEPATHCMD! > temp.txt
    set /p MYPATH=<temp.txt
)
del /q temp.txt
setx path "!MYPATH!"

rem Add context menu
echo Updating context menu via registry ...
set REGROOT=HKCU\Software\Classes\*\shell
set EMACSCLIENT=\"%EMACSBINDIR%\emacsclientw.exe\"
set ARGS=-n --alternate-editor=runemacs.exe \"%%1\"

rem Open file in existing frame
set CURRFRAME=%REGROOT%\emacsopencurrentframe
reg add %CURRFRAME% /f /ve /d "&Emacs: Edit in existing window" /t REG_SZ
reg add %CURRFRAME% /f /v icon /d "%EMACSCLIENT%" /t REG_SZ
reg add %CURRFRAME%\command /f /ve /d "%EMACSCLIENT% %ARGS%" /t REG_SZ

rem Open file in new frame
set NEWFRAME=%REGROOT%\emacsopennewframe
reg add %NEWFRAME% /f /ve /d "&Emacs: Edit in new window" /t REG_SZ
reg add %NEWFRAME% /f /v icon /d "%EMACSCLIENT%" /t REG_SZ
reg add %NEWFRAME%\command /f /ve /d "%EMACSCLIENT% -c %ARGS%" /t REG_SZ

rem Update Daemon in Task Scheduler
schtasks /query /tn "Emacs Daemon" 1>NUL 2>NUL
if errorlevel 1 (
   echo Installing Emacs Daemon in Task Scheduler ...
   schtasks /create /sc onlogon /tn "Emacs Daemon" /tr "\"%EMACSBINDIR%\runemacs.exe\" --daemon"
   schtasks /run /tn "Emacs Daemon"
) else (
   schtasks /change /tn "Emacs Daemon" /tr "\"%EMACSBINDIR%\runemacs.exe\" --daemon"
)
