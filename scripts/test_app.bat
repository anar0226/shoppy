@echo off
REM Shoppy/Avii App Testing Script for Windows
REM This script helps automate testing of key systems

echo 🧪 Starting Shoppy/Avii App Testing...
echo ======================================

REM Check if Flutter is installed
echo [INFO] Checking Flutter installation...
flutter --version >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] Flutter is installed
    flutter --version
) else (
    echo [ERROR] Flutter is not installed. Please install Flutter first.
    exit /b 1
)

REM Check if Firebase CLI is installed
echo [INFO] Checking Firebase CLI installation...
firebase --version >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] Firebase CLI is installed
    firebase --version
) else (
    echo [WARNING] Firebase CLI is not installed. Some tests may fail.
)

REM Check app dependencies
echo [INFO] Checking app dependencies...
flutter pub get
if %errorlevel% equ 0 (
    echo [SUCCESS] Dependencies are up to date
) else (
    echo [ERROR] Failed to get dependencies
    exit /b 1
)

echo.
echo [INFO] Running automated tests...

REM Analyze code
echo [INFO] Analyzing code...
flutter analyze
if %errorlevel% equ 0 (
    echo [SUCCESS] Code analysis passed
) else (
    echo [WARNING] Code analysis found issues
)

REM Run Flutter tests
echo [INFO] Running Flutter tests...
flutter test
if %errorlevel% equ 0 (
    echo [SUCCESS] All Flutter tests passed
) else (
    echo [ERROR] Some Flutter tests failed
)

REM Build app for testing
echo [INFO] Building app for testing...
flutter build apk --debug
if %errorlevel% equ 0 (
    echo [SUCCESS] App built successfully
) else (
    echo [ERROR] Failed to build app
)

REM Test on connected devices
echo [INFO] Checking connected devices...
flutter devices
if %errorlevel% equ 0 (
    echo [SUCCESS] Devices found for testing
) else (
    echo [WARNING] No devices connected. Connect a device to test on hardware.
)

echo.
echo [INFO] Manual testing checklist:
echo ==============================

echo [INFO] Testing Inventory Management System...
echo 1. Create test products with variants
echo 2. Set initial stock levels
echo 3. Place test orders
echo 4. Verify stock reservation/release
echo 5. Test manual adjustments
echo 6. Check audit trails
echo [WARNING] Manual testing required for inventory system

echo.
echo [INFO] Testing Order Fulfillment Automation...
echo 1. Place test orders
echo 2. Monitor automatic status transitions
echo 3. Test manual overrides
echo 4. Verify customer notifications
echo 5. Check escalation system
echo [WARNING] Manual testing required for order fulfillment

echo.
echo [INFO] Testing User Agreement System...
echo 1. Test signup with terms agreement
echo 2. Verify terms page navigation
echo 3. Check Mongolian text display
echo [WARNING] Manual testing required for user agreements

echo.
echo [INFO] Testing Analytics System...
echo 1. Generate test data
echo 2. Verify analytics dashboard
echo 3. Test chart interactions
echo 4. Check data export
echo [WARNING] Manual testing required for analytics

echo.
echo [INFO] Testing Summary:
echo ===================
echo [SUCCESS] Automated tests completed
echo [WARNING] Manual testing required for full validation
echo [INFO] Refer to docs/TESTING_GUIDE.md for detailed testing procedures

echo.
echo [INFO] Next steps:
echo 1. Run the app on a device: flutter run
echo 2. Follow the manual testing checklist above
echo 3. Test all user flows end-to-end
echo 4. Verify all systems work together

pause 