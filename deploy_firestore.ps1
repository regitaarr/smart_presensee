Write-Host "========================================" -ForegroundColor Green
Write-Host "Deploying Firestore Rules" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host ""
Write-Host "Checking Firebase CLI..." -ForegroundColor Yellow
try {
    $firebaseVersion = firebase --version
    Write-Host "Firebase CLI version: $firebaseVersion" -ForegroundColor Green
} catch {
    Write-Host "Firebase CLI not found. Please install it first:" -ForegroundColor Red
    Write-Host "npm install -g firebase-tools" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Logging in to Firebase..." -ForegroundColor Yellow
firebase login

Write-Host ""
Write-Host "Setting project to smart-presensee-app..." -ForegroundColor Yellow
firebase use smart-presensee-app

Write-Host ""
Write-Host "Deploying Firestore rules..." -ForegroundColor Yellow
firebase deploy --only firestore:rules

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Deployment completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Please test your application now." -ForegroundColor Cyan
Write-Host "If you still see errors, check the Firebase Console." -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit" 