@echo off
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
