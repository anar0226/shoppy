#!/bin/bash

# Shoppy/Avii App Testing Script
# This script helps automate testing of key systems

echo "🧪 Starting Shoppy/Avii App Testing..."
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Flutter is installed
check_flutter() {
    print_status "Checking Flutter installation..."
    if command -v flutter &> /dev/null; then
        print_success "Flutter is installed"
        flutter --version
    else
        print_error "Flutter is not installed. Please install Flutter first."
        exit 1
    fi
}

# Check if Firebase CLI is installed
check_firebase() {
    print_status "Checking Firebase CLI installation..."
    if command -v firebase &> /dev/null; then
        print_success "Firebase CLI is installed"
        firebase --version
    else
        print_warning "Firebase CLI is not installed. Some tests may fail."
    fi
}

# Run Flutter tests
run_flutter_tests() {
    print_status "Running Flutter tests..."
    
    if flutter test; then
        print_success "All Flutter tests passed"
    else
        print_error "Some Flutter tests failed"
        return 1
    fi
}

# Check app dependencies
check_dependencies() {
    print_status "Checking app dependencies..."
    
    if flutter pub get; then
        print_success "Dependencies are up to date"
    else
        print_error "Failed to get dependencies"
        return 1
    fi
}

# Analyze code
analyze_code() {
    print_status "Analyzing code..."
    
    if flutter analyze; then
        print_success "Code analysis passed"
    else
        print_warning "Code analysis found issues"
    fi
}

# Build app for testing
build_app() {
    print_status "Building app for testing..."
    
    if flutter build apk --debug; then
        print_success "App built successfully"
    else
        print_error "Failed to build app"
        return 1
    fi
}

# Test on connected devices
test_devices() {
    print_status "Checking connected devices..."
    
    devices=$(flutter devices)
    echo "$devices"
    
    if echo "$devices" | grep -q "No devices connected"; then
        print_warning "No devices connected. Connect a device to test on hardware."
    else
        print_success "Devices found for testing"
    fi
}

# Run specific feature tests
test_inventory_system() {
    print_status "Testing Inventory Management System..."
    print_status "1. Create test products with variants"
    print_status "2. Set initial stock levels"
    print_status "3. Place test orders"
    print_status "4. Verify stock reservation/release"
    print_status "5. Test manual adjustments"
    print_status "6. Check audit trails"
    print_warning "Manual testing required for inventory system"
}

test_order_fulfillment() {
    print_status "Testing Order Fulfillment Automation..."
    print_status "1. Place test orders"
    print_status "2. Monitor automatic status transitions"
    print_status "3. Test manual overrides"
    print_status "4. Verify customer notifications"
    print_status "5. Check escalation system"
    print_warning "Manual testing required for order fulfillment"
}

test_user_agreements() {
    print_status "Testing User Agreement System..."
    print_status "1. Test signup with terms agreement"
    print_status "2. Verify terms page navigation"
    print_status "3. Check Mongolian text display"
    print_warning "Manual testing required for user agreements"
}

test_analytics() {
    print_status "Testing Analytics System..."
    print_status "1. Generate test data"
    print_status "2. Verify analytics dashboard"
    print_status "3. Test chart interactions"
    print_status "4. Check data export"
    print_warning "Manual testing required for analytics"
}

# Main testing function
main() {
    echo "Starting comprehensive app testing..."
    echo ""
    
    # Pre-flight checks
    check_flutter
    check_firebase
    check_dependencies
    
    echo ""
    print_status "Running automated tests..."
    
    # Automated tests
    analyze_code
    run_flutter_tests
    build_app
    test_devices
    
    echo ""
    print_status "Manual testing checklist:"
    echo "=============================="
    
    # Manual testing guides
    test_inventory_system
    echo ""
    test_order_fulfillment
    echo ""
    test_user_agreements
    echo ""
    test_analytics
    
    echo ""
    print_status "Testing Summary:"
    echo "==================="
    print_success "Automated tests completed"
    print_warning "Manual testing required for full validation"
    print_status "Refer to docs/TESTING_GUIDE.md for detailed testing procedures"
    
    echo ""
    print_status "Next steps:"
    echo "1. Run the app on a device: flutter run"
    echo "2. Follow the manual testing checklist above"
    echo "3. Test all user flows end-to-end"
    echo "4. Verify all systems work together"
}

# Run main function
main "$@" 