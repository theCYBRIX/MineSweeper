@echo off

echo Compressing desktop builds...

set fileNames[0]=.\MineSweeper_x32.exe
set fileNames[1]=.\MineSweeper_x64.exe
set fileNames[2]=.\MineSweeper_x32.x86_32
set fileNames[3]=.\MineSweeper_x64.x86_64

set compressedNames[0]=.\MineSweeper_Windows_x32.zip
set compressedNames[1]=.\MineSweeper_Windows_x64.zip
set compressedNames[2]=.\MineSweeper_Linux_x32.zip
set compressedNames[3]=.\MineSweeper_Linux_x64.zip

set numItems=4

set "x=0"

:CompressLoop
echo Progress: %x%/%numItems%

if defined fileNames[%x%] (
	call :CompressFile %%fileNames[%x%]%% %%compressedNames[%x%]%%
	set /a "x+=1"
	GOTO :CompressLoop
) ELSE (
	echo Finished.
	set /p DUMMY=Hit ENTER to exit... 
)
GOTO :EOF



:CompressFile
set fileName=%1
set compressedName=%2

IF EXIST "%fileName%" (
	IF EXIST %compressedName% del /F %compressedName%
	call 7z a -tzip -mx=9 %compressedName% %fileName% && call del /F %fileName%
) ELSE (
	echo %fileName% does not exist. Skipping...
)
GOTO :EOF

