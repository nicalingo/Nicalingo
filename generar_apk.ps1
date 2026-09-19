Write-Host "Limpiando procesos fantasma..." -ForegroundColor Yellow
taskkill /F /IM dart.exe /T 2>$null
cd android
.\gradlew --stop
cd ..

Write-Host "Ejecutando Flutter Clean..." -ForegroundColor Yellow
flutter clean

Write-Host "Descargando dependencias..." -ForegroundColor Yellow
flutter pub get

Write-Host "Construyendo APK..." -ForegroundColor Green
flutter build apk