@echo off
cd /d "d:\Downloads\OdooPb_02\PeoplePay360\frontend"
"D:\FlutterDev\flutter\bin\cache\dart-sdk\bin\dart.exe" analyze lib 1> "d:\Downloads\OdooPb_02\PeoplePay360\frontend\analyze_out.txt" 2>&1
echo DART_EXIT=%ERRORLEVEL% >> "d:\Downloads\OdooPb_02\PeoplePay360\frontend\analyze_out.txt"
