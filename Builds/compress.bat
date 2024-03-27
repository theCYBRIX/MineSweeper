@echo off

echo Compressing desktop builds...
echo Progress: 0/4

7z a -tzip -mx=9 "MineSweeper_Windows_x32.zip" .\MineSweeper_x32.exe && del .\MineSweeper_x32.exe
echo Progress: 1/4

7z a -tzip -mx=9 "MineSweeper_Windows_x64.zip" .\MineSweeper_x64.exe && del .\MineSweeper_x64.exe
echo Progress: 2/4

7z a -tzip -mx=9 "MineSweeper_Linux_x32.zip" .\MineSweeper_x32.x86_32 && del .\MineSweeper_x32.x86_32
echo Progress: 3/4

7z a -tzip -mx=9 "MineSweeper_Linux_x64.zip" .\MineSweeper_x64.x86_64 && del .\MineSweeper_x64.x86_64
echo Progress: 4/4

echo Finished.
set /p DUMMY=Hit ENTER to exit...
