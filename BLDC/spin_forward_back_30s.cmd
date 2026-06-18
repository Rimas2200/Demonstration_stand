@echo off
setlocal
cd /d "%~dp0"
python spin_forward_back_30s.py %*
endlocal
