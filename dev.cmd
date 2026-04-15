@ECHO OFF
SETLOCAL ENABLEEXTENSIONS
:: Go to script root
CD /D %~dp0
IF "%1"=="" GOTO HELP
SET CMD=%1
IF /I "%CMD%"=="start" GOTO DO_START
:HELP
ECHO Usage: dev [start^|fast^|test^|client]
ECHO.
ECHO   start   - Install deps, run tests, start uvicorn
EXIT /b 1
:INSTALL_DEPS
ECHO Installing Python dependencies...
CALL pip install -r requirements.txt
ECHO Installing Python developer dependencies...
CALL pip install -r requirements-dev.txt
IF ERRORLEVEL 1 EXIT /b 1
EXIT /b 0
:DO_START
CALL :INSTALL_DEPS || EXIT /b 1
ECHO.
ECHO Starting Uvicorn on http://localhost:8000 ...
ECHO.
CALL python -m uvicorn main:app --reload --host localhost
EXIT /b %ERRORLEVEL%
