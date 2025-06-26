#!/bin/bash

# 🚀 Shoppy CI/CD Setup Script
# This script helps set up the GitHub Actions CI/CD pipeline

set -e

echo "🚀 Setting up Shoppy CI/CD Pipeline"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}$1${NC}"
    echo "$(printf '=%.0s' {1..50})"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) is not installed."
    print_info "Please install it from: https://cli.github.com/"
    exit 1
fi

# Check if user is logged in to GitHub CLI
if ! gh auth status &> /dev/null; then
    print_warning "You're not logged in to GitHub CLI."
    echo "Please run: gh auth login"
    exit 1
fi

print_header "🔐 Setting up GitHub Secrets"

# Required secrets for CI/CD
declare -A SECRETS=(
    ["FIREBASE_TOKEN"]="Firebase CI token (run: firebase login:ci)"
    ["ANDROID_KEYSTORE"]="Base64 encoded Android keystore file"
    ["ANDROID_KEYSTORE_PASSWORD"]="Android keystore password"
    ["ANDROID_KEY_PASSWORD"]="Android key password"
    ["ANDROID_KEY_ALIAS"]="Android key alias"
    ["GOOGLE_PLAY_SERVICE_ACCOUNT"]="Google Play Console service account JSON"
    ["SLACK_WEBHOOK_URL"]="Slack webhook URL for notifications"
    ["SMTP_SERVER"]="SMTP server for email notifications"
    ["SMTP_PORT"]="SMTP port (usually 587)"
    ["SMTP_USERNAME"]="SMTP username"
    ["SMTP_PASSWORD"]="SMTP password"
    ["SMTP_FROM"]="From email address"
    ["NOTIFICATION_EMAIL"]="Email for general notifications"
    ["SECURITY_EMAIL"]="Email for security alerts"
)

# Optional secrets for iOS (if building iOS)
declare -A OPTIONAL_SECRETS=(
    ["APPLE_CERTIFICATE"]="Base64 encoded Apple certificate (.p12)"
    ["APPLE_CERTIFICATE_PASSWORD"]="Apple certificate password"
    ["APPLE_PROVISIONING_PROFILE"]="Base64 encoded provisioning profile"
    ["APP_STORE_CONNECT_API_KEY"]="App Store Connect API key"
    ["APP_STORE_CONNECT_ISSUER_ID"]="App Store Connect issuer ID"
    ["APP_STORE_CONNECT_KEY_ID"]="App Store Connect key ID"
)

echo "Setting up required secrets..."

for secret in "${!SECRETS[@]}"; do
    echo -e "\n${YELLOW}Setting up: $secret${NC}"
    echo "Description: ${SECRETS[$secret]}"
    
    # Check if secret already exists
    if gh secret list | grep -q "$secret"; then
        print_warning "Secret $secret already exists."
        read -p "Do you want to update it? (y/N): " update_secret
        if [[ ! $update_secret =~ ^[Yy]$ ]]; then
            continue
        fi
    fi
    
    read -s -p "Enter value for $secret: " secret_value
    echo
    
    if [ -n "$secret_value" ]; then
        if gh secret set "$secret" --body "$secret_value"; then
            print_success "Secret $secret set successfully"
        else
            print_error "Failed to set secret $secret"
        fi
    else
        print_warning "Skipping empty secret $secret"
    fi
done

print_header "📱 iOS Secrets (Optional)"
echo "The following secrets are only needed if you plan to build and deploy iOS apps:"

read -p "Do you want to set up iOS deployment secrets? (y/N): " setup_ios
if [[ $setup_ios =~ ^[Yy]$ ]]; then
    for secret in "${!OPTIONAL_SECRETS[@]}"; do
        echo -e "\n${YELLOW}Setting up: $secret${NC}"
        echo "Description: ${OPTIONAL_SECRETS[$secret]}"
        
        if gh secret list | grep -q "$secret"; then
            print_warning "Secret $secret already exists."
            read -p "Do you want to update it? (y/N): " update_secret
            if [[ ! $update_secret =~ ^[Yy]$ ]]; then
                continue
            fi
        fi
        
        read -s -p "Enter value for $secret (or press Enter to skip): " secret_value
        echo
        
        if [ -n "$secret_value" ]; then
            if gh secret set "$secret" --body "$secret_value"; then
                print_success "Secret $secret set successfully"
            else
                print_error "Failed to set secret $secret"
            fi
        else
            print_info "Skipping $secret"
        fi
    done
fi

print_header "🔧 Repository Settings"

# Enable GitHub Actions if not already enabled
echo "Ensuring GitHub Actions is enabled..."
if gh api repos/:owner/:repo --jq '.has_actions' | grep -q "false"; then
    print_warning "GitHub Actions is not enabled for this repository"
    echo "Please enable it manually in repository settings"
else
    print_success "GitHub Actions is enabled"
fi

print_header "🚀 Workflow Files"

# Check if workflow files exist
workflows=(
    ".github/workflows/ci-cd.yml"
    ".github/workflows/pr-validation.yml"
    ".github/workflows/security-scan.yml"
    ".github/workflows/release.yml"
)

for workflow in "${workflows[@]}"; do
    if [ -f "$workflow" ]; then
        print_success "Workflow file exists: $workflow"
    else
        print_error "Workflow file missing: $workflow"
    fi
done

print_header "📋 Next Steps"

echo "1. 🔑 Firebase Setup:"
echo "   - Run: firebase login:ci"
echo "   - Copy the token and set it as FIREBASE_TOKEN secret"
echo ""

echo "2. 🤖 Android Setup:"
echo "   - Generate a release keystore"
echo "   - Encode it as base64 and set as ANDROID_KEYSTORE secret"
echo "   - Set up Google Play Console service account"
echo ""

echo "3. 🍎 iOS Setup (if needed):"
echo "   - Generate Apple certificates and provisioning profiles"
echo "   - Set up App Store Connect API keys"
echo ""

echo "4. 🔔 Notifications:"
echo "   - Set up Slack webhook for team notifications"
echo "   - Configure SMTP for email alerts"
echo ""

echo "5. 🧪 Test the Pipeline:"
echo "   - Create a pull request to test PR validation"
echo "   - Push to main branch to test full CI/CD"
echo "   - Create a tag (v1.0.0) to test release workflow"
echo ""

print_success "CI/CD setup complete! 🎉"
print_info "Check the GitHub Actions tab to see your workflows in action."

echo -e "\n${BLUE}Useful Commands:${NC}"
echo "- View workflow runs: gh run list"
echo "- View specific run: gh run view <run-id>"
echo "- View secrets: gh secret list"
echo "- Trigger workflow: gh workflow run ci-cd.yml"

echo -e "\n${GREEN}Happy deploying! 🚀${NC}" 