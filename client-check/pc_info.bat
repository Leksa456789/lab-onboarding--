@echo off
chcp 65001 >nul
REM ============================================================
REM Практическая работа: Диагностика клиентского компьютера
REM Тема: инструментальные средства ревьюирования, проверки на
REM       стороне клиента
REM Автор: Колесниченко
REM Дата: 29.10.2026
REM ============================================================
goto :main

REM ------------------------------------------------------------
REM Подпрограмма :out - выводит строку в окно и дописывает её
REM в файл отчета
REM ------------------------------------------------------------
:out
setlocal enabledelayedexpansion
set "t=%~1"
echo(!t!
>>"%REPORT%" echo(!t!
endlocal
exit /b

REM ------------------------------------------------------------
REM Подпрограмма :togb - переводит байты в гигабайты.
REM Значения диска не помещаются в 32-битное число set /a,
REM поэтому последние 6 цифр отбрасываются (точность до 1 МБ).
REM %1 - значение в байтах, %2 - имя переменной для результата
REM ------------------------------------------------------------
:togb
setlocal enabledelayedexpansion
set "v=%~1"
set "hi=!v:~0,-6!"
if not defined hi set "hi=0"
set /a gb=hi*1000/1073742
endlocal & set "%~2=%gb%"
exit /b

:main
REM Проверка: утилита wmic должна быть в системе
where wmic >nul 2>&1
if errorlevel 1 (
    echo Утилита wmic не найдена в этой версии Windows.
    pause
    exit /b 1
)

REM Файл отчета создается рядом с pc_info.bat
set "REPORT=%~dp0pc_report.txt"
type nul > "%REPORT%"

REM --- Заголовок ---
call :out "============================================================"
call :out "Диагностика компьютера"
call :out "Дата: %DATE% %TIME%"
call :out "============================================================"
call :out ""

REM --- Операционная система ---
call :out "--- Операционная система ---"
REM Название берем из реестра: wmic отдает русский текст в другой кодировке
for /f "usebackq tokens=2*" %%a in (`reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName ^| findstr "ProductName"`) do call :out "Название: %%b"
for /f "usebackq tokens=2 delims==" %%a in (`wmic os get Version /value ^| find "="`) do for /f "delims=" %%b in ("%%a") do call :out "Версия: %%b"
call :out ""

REM --- Процессор ---
call :out "--- Процессор ---"
for /f "usebackq tokens=2 delims==" %%a in (`wmic cpu get Name /value ^| find "="`) do for /f "delims=" %%b in ("%%a") do call :out "%%b"
call :out ""

REM --- Оперативная память (значения в КБ переводим в ГБ) ---
call :out "--- Оперативная память ---"
for /f "usebackq tokens=2 delims==" %%a in (`wmic os get TotalVisibleMemorySize /value ^| find "="`) do for /f "delims=" %%b in ("%%a") do set /a MEM_TOTAL=%%b/1048576
for /f "usebackq tokens=2 delims==" %%a in (`wmic os get FreePhysicalMemory /value ^| find "="`) do for /f "delims=" %%b in ("%%a") do set /a MEM_FREE=%%b/1048576
call :out "Всего памяти: %MEM_TOTAL% ГБ"
call :out "Свободно памяти: %MEM_FREE% ГБ"
call :out ""

REM --- Диск C (значения в байтах переводим в ГБ) ---
call :out "--- Диск C ---"
for /f "usebackq tokens=2 delims==" %%a in (`wmic logicaldisk where "DeviceID='C:'" get Size /value ^| find "="`) do for /f "delims=" %%b in ("%%a") do call :togb "%%b" DISK_TOTAL
for /f "usebackq tokens=2 delims==" %%a in (`wmic logicaldisk where "DeviceID='C:'" get FreeSpace /value ^| find "="`) do for /f "delims=" %%b in ("%%a") do call :togb "%%b" DISK_FREE
call :out "Всего: %DISK_TOTAL% ГБ"
call :out "Свободно: %DISK_FREE% ГБ"
call :out ""

REM --- Установленные программы (через реестр, команда reg query) ---
call :out "--- Установленные программы ---"
set "RAW=%TEMP%\pc_progs_raw.txt"
if exist "%RAW%" del "%RAW%"
REM 64-битные программы и 32-битные программы на 64-битной системе
reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall" /s /v DisplayName 2>nul | findstr "DisplayName" >> "%RAW%"
reg query "HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s /v DisplayName 2>nul | findstr "DisplayName" >> "%RAW%"

REM Оставляем только названия (без служебных путей реестра)
setlocal enabledelayedexpansion
for /f "usebackq tokens=2*" %%a in ("%RAW%") do (
    set "n=%%b"
    if defined n call :out "!n!"
)
endlocal
del "%RAW%" 2>nul

REM --- Завершение ---
call :out ""
call :out "Отчёт сохранён: %REPORT%"
pause
