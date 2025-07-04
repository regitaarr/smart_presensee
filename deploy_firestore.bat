@echo off
echo ========================================
echo Deploying Firestore Rules
echo ========================================

echo.
echo Checking Firebase CLI...
firebase --version
if %errorlevel% neq 0 (
    echo Firebase CLI not found. Please install it first:
    echo npm install -g firebase-tools
    pause
    exit /b 1
)

echo.
echo Logging in to Firebase...
firebase login

echo.
echo Setting project to smart-presensee-app...
firebase use smart-presensee-app

echo.
echo Deploying Firestore rules...
firebase deploy --only firestore:rules

echo.
echo ========================================
echo Deployment completed!
echo ========================================
echo.
echo Please test your application now.
echo If you still see errors, check the Firebase Console.
echo.
pause 