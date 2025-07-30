# Color System Guide

## Overview

This guide explains how to use the centralized color system in the Shoppy application. All colors are defined in `lib/core/constants/colors.dart` to ensure consistency and easy maintenance across the entire application.

## 🎨 Brand Colors

### Primary Brand Color
- **Hex**: `#0053A3`
- **Dart**: `Color(0xFF0053A3)`
- **Usage**: Primary buttons, links, brand elements, focus states
- **Access**: `AppColors.brandBlue`

### Secondary Brand Color
- **Hex**: `#4F46E5`
- **Dart**: `Color(0xFF4F46E5)`
- **Usage**: Secondary buttons, highlights, backgrounds
- **Access**: `AppColors.brandBlueLight`

### Brand Blue Overlay
- **Hex**: `#0053A3` with 10% opacity
- **Dart**: `Color(0x1A0053A3)`
- **Usage**: Overlays, backgrounds with brand color
- **Access**: `AppColors.brandBlueOverlay`

## 🎯 Semantic Colors

### Success
- **Hex**: `#10B981`
- **Usage**: Success messages, completed actions, positive feedback
- **Access**: `AppColors.success`

### Error
- **Hex**: `#EF4444`
- **Usage**: Error messages, destructive actions, warnings
- **Access**: `AppColors.error`

### Warning
- **Hex**: `#F59E0B`
- **Usage**: Warning messages, caution states
- **Access**: `AppColors.warning`

### Info
- **Hex**: `#8B5CF6`
- **Usage**: Information messages, neutral states
- **Access**: `AppColors.info`

## 🌓 Theme Colors

### Light Theme
- **Background**: `AppColors.lightBackground` (`#FFFFFF`)
- **Surface**: `AppColors.lightSurface` (`#FFFFFF`)
- **Card**: `AppColors.lightCard` (`#FFFFFF`)
- **Text**: `AppColors.lightOnBackground` (`#0F172A`)
- **Secondary Text**: `AppColors.lightOnSurface` (`#334155`)
- **Border**: `AppColors.lightBorder` (`#E2E8F0`)

### Dark Theme
- **Background**: `AppColors.darkBackground` (`#000000`)
- **Surface**: `AppColors.darkSurface` (`#121212`)
- **Card**: `AppColors.darkCard` (`#1E1E1E`)
- **Text**: `AppColors.darkOnBackground` (`#FFFFFF`)
- **Secondary Text**: `AppColors.darkOnSurface` (`#E0E0E0`)
- **Border**: `AppColors.darkBorder` (`#333333`)

## 🏷️ Category Colors

Each product category has its own distinct color:

- **Women**: `AppColors.categoryWomen` (`#2D8A47`)
- **Men**: `AppColors.categoryMen` (`#D97841`)
- **Beauty**: `AppColors.categoryBeauty` (`#FF69B4`)
- **Food & Drinks**: `AppColors.categoryFood` (`#B8A082`)
- **Home**: `AppColors.categoryHome` (`#8B9B8A`)
- **Fitness**: `AppColors.categoryFitness` (`#6B9BD1`)
- **Accessories**: `AppColors.categoryAccessories` (`#00FF51`)
- **Pet**: `AppColors.categoryPet` (`#D2B48C`)
- **Toys & Games**: `AppColors.categoryToys` (`#6A5ACD`)
- **Electronics**: `AppColors.categoryElectronics` (`#2F2F2F`)

## 💳 Payment Colors

- **QPay**: `AppColors.qpayOrange` (`#FF6B35`)
- **Credit Card**: `AppColors.creditCardBlue` (`#2563EB`)
- **Cash**: `AppColors.cashGreen` (`#10B981`)

## 📊 Status Colors

- **Active/Online**: `AppColors.statusActive` (`#10B981`)
- **Pending**: `AppColors.statusPending` (`#F59E0B`)
- **Inactive/Offline**: `AppColors.statusInactive` (`#6B7280`)
- **Cancelled**: `AppColors.statusCancelled` (`#EF4444`)

## 🎨 Gradient Colors

### Primary Gradient
```dart
AppColors.primaryGradient // [brandBlue, brandBlueLight]
```

### Secondary Gradient
```dart
AppColors.secondaryGradient // [success, lightSuccess]
```

### Success Gradient
```dart
AppColors.successGradient // [success, lightSuccess]
```

### Error Gradient
```dart
AppColors.errorGradient // [error, lightError]
```

## 🛠️ Helper Methods

### Theme-Aware Colors
```dart
// Get theme-aware background color
AppColors.getBackgroundColor(context)

// Get theme-aware surface color
AppColors.getSurfaceColor(context)

// Get theme-aware card color
AppColors.getCardColor(context)

// Get theme-aware text color
AppColors.getTextColor(context)

// Get theme-aware secondary text color
AppColors.getSecondaryTextColor(context)

// Get theme-aware border color
AppColors.getBorderColor(context)

// Get theme-aware divider color
AppColors.getDividerColor(context)
```

### Dynamic Colors
```dart
// Get category color by name
AppColors.getCategoryColor('Women') // Returns categoryWomen
AppColors.getCategoryColor('эмэгтэй') // Also returns categoryWomen

// Get status color by status string
AppColors.getStatusColor('active') // Returns statusActive
AppColors.getStatusColor('pending') // Returns statusPending

// Get payment method color
AppColors.getPaymentMethodColor('qpay') // Returns qpayOrange
AppColors.getPaymentMethodColor('card') // Returns creditCardBlue
```

## 📝 Usage Examples

### Basic Color Usage
```dart
import 'package:your_app/core/constants/colors.dart';

// Use brand color for primary buttons
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.brandBlue,
  ),
  onPressed: () {},
  child: Text('Primary Button'),
)

// Use theme-aware colors
Container(
  color: AppColors.getBackgroundColor(context),
  child: Text(
    'Theme-aware text',
    style: TextStyle(
      color: AppColors.getTextColor(context),
    ),
  ),
)
```

### Category-Specific Styling
```dart
// Get category color dynamically
Color categoryColor = AppColors.getCategoryColor(categoryName);

Container(
  decoration: BoxDecoration(
    color: categoryColor,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(categoryName),
)
```

### Status Indicators
```dart
// Use status colors for order status
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: AppColors.getStatusColor(orderStatus),
    borderRadius: BorderRadius.circular(4),
  ),
  child: Text(
    orderStatus,
    style: TextStyle(color: Colors.white),
  ),
)
```

### Payment Method Styling
```dart
// Style payment method icons
Icon(
  Icons.payment,
  color: AppColors.getPaymentMethodColor(paymentMethod),
)
```

## 🔧 Adding New Colors

### 1. Add to AppColors Class
```dart
class AppColors {
  // Add your new color
  static const Color newColor = Color(0xFF123456);
  
  // Add helper method if needed
  static Color getNewColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? newColor.withOpacity(0.8)
        : newColor;
  }
}
```

### 2. Update Documentation
Add the new color to this guide with:
- Hex value
- Usage description
- Access method
- Example usage

### 3. Use Consistently
Always use `AppColors.newColor` instead of hardcoding `Color(0xFF123456)`.

## 🚫 Common Mistakes to Avoid

### ❌ Don't Hardcode Colors
```dart
// Wrong
Container(color: Color(0xFF0053A3))

// Correct
Container(color: AppColors.brandBlue)
```

### ❌ Don't Use Theme Colors Directly
```dart
// Wrong
Text('Hello', style: TextStyle(color: Colors.black))

// Correct
Text('Hello', style: TextStyle(color: AppColors.getTextColor(context)))
```

### ❌ Don't Create Duplicate Colors
```dart
// Wrong - creates duplicate
static const Color myBlue = Color(0xFF0053A3)

// Correct - reuse existing
static const Color myBlue = AppColors.brandBlue
```

## 📋 Color Checklist

When adding new UI elements:

- [ ] Use `AppColors.brandBlue` for primary actions
- [ ] Use `AppColors.getTextColor(context)` for text
- [ ] Use `AppColors.getBackgroundColor(context)` for backgrounds
- [ ] Use `AppColors.getBorderColor(context)` for borders
- [ ] Use semantic colors for status indicators
- [ ] Use category colors for category-specific elements
- [ ] Test in both light and dark themes
- [ ] Ensure sufficient contrast ratios

## 🎨 Design System Integration

This color system integrates with:

- **Material Design**: Follows Material Design color principles
- **Accessibility**: Ensures sufficient contrast ratios
- **Dark Mode**: Provides theme-aware color variants
- **Brand Consistency**: Maintains consistent brand identity
- **Scalability**: Easy to add new colors and themes

## 📚 Additional Resources

- [Material Design Color System](https://material.io/design/color/the-color-system.html)
- [Flutter Color Documentation](https://api.flutter.dev/flutter/dart-ui/Color-class.html)
- [Web Content Accessibility Guidelines (WCAG)](https://www.w3.org/WAI/WCAG21/quickref/#contrast-minimum) 