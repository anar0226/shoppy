# Deploy Custom Auth Cloud Functions
# This script deploys the custom authentication functions to Firebase

Write-Host "Deploying Custom Auth Cloud Functions..." -ForegroundColor Green

# Navigate to functions directory
Set-Location functions

# Install dependencies if needed
if (-not (Test-Path "node_modules")) {
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    npm install
}

# Build TypeScript
Write-Host "Building TypeScript..." -ForegroundColor Yellow
npm run build

# Deploy functions
Write-Host "Deploying functions..." -ForegroundColor Yellow
firebase deploy --only functions:generateCustomAuthAction,functions:handleCustomAuthAction,functions:sendCustomEmailVerification,functions:sendCustomPasswordResetEmail

# Return to root directory
Set-Location ..

Write-Host "Custom Auth Functions deployed successfully!" -ForegroundColor Green
Write-Host "Remember to:" -ForegroundColor Yellow
Write-Host "1. Add 'avii.mn' to Firebase Console > Authentication > Settings > Authorized domains" -ForegroundColor Cyan
Write-Host "2. Configure your web server to handle '/_/auth/action' path" -ForegroundColor Cyan
Write-Host "3. Test the authentication flows" -ForegroundColor Cyan 