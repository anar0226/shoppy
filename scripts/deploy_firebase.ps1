# Firebase Hosting Deployment Script
# This script builds and deploys your Flutter web app to Firebase Hosting

param(
    [switch]$Help,
    [switch]$BuildOnly,
    [switch]$DeployOnly,
    [string]$Target = "lib/admin_panel/admin_main.dart"
)

if ($Help) {
    Write-Host "Firebase Hosting Deployment Script" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\deploy_firebase.ps1                    # Build and deploy"
    Write-Host "  .\deploy_firebase.ps1 -BuildOnly         # Only build, don't deploy"
    Write-Host "  .\deploy_firebase.ps1 -DeployOnly        # Only deploy (assumes build exists)"
    Write-Host "  .\deploy_firebase.ps1 -Help              # Show this help"
    Write-Host "  .\deploy_firebase.ps1 -Target lib/main.dart  # Deploy main app instead of admin"
    Write-Host ""
    Write-Host "Prerequisites:" -ForegroundColor Yellow
    Write-Host "  1. Install Firebase CLI: npm install -g firebase-tools"
    Write-Host "  2. Login to Firebase: firebase login"
    Write-Host "  3. Initialize Firebase: firebase init hosting"
    Write-Host "  4. Make sure you have a Firebase project set up"
    exit 0
}

Write-Host "🚀 Firebase Hosting Deployment" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green
Write-Host ""

# Check if Firebase CLI is installed
try {
    $firebaseVersion = firebase --version
    Write-Host "✅ Firebase CLI found: $firebaseVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Firebase CLI not found!" -ForegroundColor Red
    Write-Host "Please install Firebase CLI:" -ForegroundColor Yellow
    Write-Host "  npm install -g firebase-tools" -ForegroundColor Gray
    Write-Host "  firebase login" -ForegroundColor Gray
    exit 1
}

# Check if user is logged in
try {
    $firebaseProjects = firebase projects:list --json 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Not logged into Firebase!" -ForegroundColor Red
        Write-Host "Please run: firebase login" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ Logged into Firebase" -ForegroundColor Green
} catch {
    Write-Host "❌ Firebase login check failed!" -ForegroundColor Red
    Write-Host "Please run: firebase login" -ForegroundColor Yellow
    exit 1
}

if (-not $DeployOnly) {
    # Step 1: Clean previous build
    Write-Host "🧹 Cleaning previous build..." -ForegroundColor Yellow
    if (Test-Path "build/web") {
        Remove-Item "build/web" -Recurse -Force
    }

    # Step 2: Build Flutter web app
    Write-Host "🔨 Building Flutter web app..." -ForegroundColor Yellow
    Write-Host "Target: $Target" -ForegroundColor Gray
    
    $buildCommand = "flutter build web --target $Target --release"
    Write-Host "Command: $buildCommand" -ForegroundColor Gray
    Invoke-Expression $buildCommand

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Build failed!" -ForegroundColor Red
        exit 1
    }

    Write-Host "✅ Build completed successfully!" -ForegroundColor Green
}

if ($BuildOnly) {
    Write-Host "📦 Build only mode - deployment skipped" -ForegroundColor Yellow
    exit 0
}

# Step 3: Deploy to Firebase
Write-Host "🚀 Deploying to Firebase Hosting..." -ForegroundColor Yellow

# Check if firebase.json exists
if (-not (Test-Path "firebase.json")) {
    Write-Host "❌ firebase.json not found!" -ForegroundColor Red
    Write-Host "Please run: firebase init hosting" -ForegroundColor Yellow
    exit 1
}

# Deploy to Firebase
Write-Host "Deploying..." -ForegroundColor Gray
firebase deploy --only hosting

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 Your app is now live on Firebase Hosting!" -ForegroundColor Cyan
Write-Host "   You can find the URL in the Firebase console or in the output above." -ForegroundColor White
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Add your custom domain in Firebase console" -ForegroundColor White
Write-Host "  2. Configure DNS settings for your domain" -ForegroundColor White
Write-Host "  3. Test your website functionality" -ForegroundColor White
Write-Host ""
Write-Host "🔧 Useful Commands:" -ForegroundColor Cyan
Write-Host "  firebase hosting:channel:deploy preview  # Deploy to preview channel" -ForegroundColor Gray
Write-Host "  firebase hosting:open                    # Open your site" -ForegroundColor Gray
Write-Host "  firebase projects:list                   # List your projects" -ForegroundColor Gray 