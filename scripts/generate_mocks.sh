#!/bin/bash

# Generate mock classes for testing
echo "🔧 Generating mock classes..."

# Clean previous generated files
flutter packages pub run build_runner clean

# Generate new mock files
flutter packages pub run build_runner build --delete-conflicting-outputs

echo "✅ Mock classes generated successfully!"
echo "📁 Generated files are in: lib/generated/" 