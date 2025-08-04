import 'package:flutter/material.dart';

/// Centralized color constants for the entire application
///
/// This file contains all brand colors, theme colors, and semantic colors
/// used throughout the website. All colors should be defined here for
/// consistency and easy maintenance.
class AppColors {
  // ===== BRAND COLORS =====

  /// Primary brand color - Avii.mn blue
  /// Used for: Primary buttons, links, brand elements, focus states
  static const Color brandBlue = Color(0xFF4285F4);

  /// Secondary brand color - Light blue variant
  /// Used for: Secondary buttons, highlights, backgrounds
  static const Color brandBlueLight = Color(0xFF4F46E5);

  /// Brand blue with opacity for overlays and backgrounds
  static const Color brandBlueOverlay = Color(0x1A0053A3);

  // ===== SEMANTIC COLORS =====

  /// Success color - Green
  /// Used for: Success messages, completed actions, positive feedback
  static const Color success = Color(0xFF10B981);

  /// Error color - Red
  /// Used for: Error messages, destructive actions, warnings
  static const Color error = Color(0xFFEF4444);

  /// Warning color - Amber/Orange
  /// Used for: Warning messages, caution states
  static const Color warning = Color(0xFFF59E0B);

  /// Info color - Purple
  /// Used for: Information messages, neutral states
  static const Color info = Color(0xFF8B5CF6);

  // ===== LIGHT THEME COLORS =====

  /// Light theme background - Pure white
  static const Color lightBackground = Color(0xFFFFFFFF);

  /// Light theme surface - Pure white
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Light theme card background
  static const Color lightCard = Color(0xFFFFFFFF);

  /// Light theme surface variant
  static const Color lightSurfaceVariant = Color(0xFFFFFFFF);

  /// Light theme text on background
  static const Color lightOnBackground = Color(0xFF0F172A);

  /// Light theme text on surface
  static const Color lightOnSurface = Color(0xFF334155);

  /// Light theme secondary text
  static const Color lightOnSurfaceVariant = Color(0xFF64748B);

  /// Light theme border
  static const Color lightBorder = Color(0xFFE2E8F0);

  /// Light theme divider
  static const Color lightDivider = Color(0xFFE2E8F0);

  // ===== DARK THEME COLORS =====

  /// Dark theme background - Pure black
  static const Color darkBackground = Color(0xFF000000);

  /// Dark theme surface - Very dark gray
  static const Color darkSurface = Color(0xFF121212);

  /// Dark theme card background
  static const Color darkCard = Color(0xFF1E1E1E);

  /// Dark theme surface variant
  static const Color darkSurfaceVariant = Color(0xFF2D2D2D);

  /// Dark theme text on background - White
  static const Color darkOnBackground = Color(0xFFFFFFFF);

  /// Dark theme text on surface
  static const Color darkOnSurface = Color(0xFFE0E0E0);

  /// Dark theme secondary text
  static const Color darkOnSurfaceVariant = Color(0xFFB0B0B0);

  /// Dark theme border
  static const Color darkBorder = Color(0xFF333333);

  /// Dark theme divider
  static const Color darkDivider = Color(0xFF333333);

  // ===== CATEGORY COLORS =====

  /// All categories now use grey color
  static const Color categoryGrey = Color(0xFF808080);

  /// Women's category color
  static const Color categoryWomen = categoryGrey;

  /// Men's category color
  static const Color categoryMen = categoryGrey;

  /// Beauty category color
  static const Color categoryBeauty = categoryGrey;

  /// Food & Drinks category color
  static const Color categoryFood = categoryGrey;

  /// Home category color
  static const Color categoryHome = categoryGrey;

  /// Fitness category color
  static const Color categoryFitness = categoryGrey;

  /// Accessories category color
  static const Color categoryAccessories = categoryGrey;

  /// Pet category color
  static const Color categoryPet = categoryGrey;

  /// Toys & Games category color
  static const Color categoryToys = categoryGrey;

  /// Electronics category color
  static const Color categoryElectronics = categoryGrey;

  // ===== PAYMENT COLORS =====

  /// QPay brand color
  static const Color qpayOrange = Color(0xFF2563EB);

  /// Credit card color
  static const Color creditCardBlue = Color(0xFF2563EB);

  /// Cash payment color
  static const Color cashGreen = Color(0xFF10B981);

  // ===== STATUS COLORS =====

  /// Active/Online status
  static const Color statusActive = Color(0xFF10B981);

  /// Pending status
  static const Color statusPending = Color(0xFFF59E0B);

  /// Inactive/Offline status
  static const Color statusInactive = Color(0xFF6B7280);

  /// Cancelled status
  static const Color statusCancelled = Color(0xFFEF4444);

  // ===== GRADIENT COLORS =====

  /// Primary gradient colors
  static const List<Color> primaryGradient = [
    brandBlue,
    brandBlueLight,
  ];

  /// Secondary gradient colors
  static const List<Color> secondaryGradient = [
    Color(0xFF10B981),
    Color(0xFF34D399),
  ];

  /// Success gradient colors
  static const List<Color> successGradient = [
    Color(0xFF10B981),
    Color(0xFF6EE7B7),
  ];

  /// Error gradient colors
  static const List<Color> errorGradient = [
    Color(0xFFEF4444),
    Color(0xFFF87171),
  ];

  // ===== HELPER METHODS =====

  /// Get theme-aware background color
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : lightBackground;
  }

  /// Get theme-aware surface color
  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : lightSurface;
  }

  /// Get theme-aware card color
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCard
        : lightCard;
  }

  /// Get theme-aware text color
  static Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkOnBackground
        : lightOnBackground;
  }

  /// Get theme-aware secondary text color
  static Color getSecondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkOnSurface
        : lightOnSurface;
  }

  /// Get theme-aware border color
  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBorder
        : lightBorder;
  }

  /// Get theme-aware divider color
  static Color getDividerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkDivider
        : lightDivider;
  }

  /// Get category color by name
  static Color getCategoryColor(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'women':
      case 'эмэгтэй':
        return categoryWomen;
      case 'men':
      case 'эрэгтэй':
        return categoryMen;
      case 'beauty':
      case 'гоо сайхан':
        return categoryBeauty;
      case 'food':
      case 'хоол хүнс':
        return categoryFood;
      case 'home':
      case 'гэр ахуй':
        return categoryHome;
      case 'fitness':
      case 'фитнесс':
        return categoryFitness;
      case 'accessories':
      case 'аксессуары':
        return categoryAccessories;
      case 'pet':
      case 'амьтдын бүтээгдэхүүн':
        return categoryPet;
      case 'toys':
      case 'тоглоомнууд':
        return categoryToys;
      case 'electronics':
      case 'цахилгаан бараа':
        return categoryElectronics;
      default:
        return brandBlue;
    }
  }

  /// Get status color by status string
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'online':
      case 'confirmed':
      case 'delivered':
        return statusActive;
      case 'pending':
      case 'placed':
      case 'processing':
        return statusPending;
      case 'inactive':
      case 'offline':
      case 'shipped':
        return statusInactive;
      case 'cancelled':
        return statusCancelled;
      default:
        return statusInactive;
    }
  }

  /// Get payment method color
  static Color getPaymentMethodColor(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'qpay':
        return qpayOrange;
      case 'card':
      case 'visa':
      case 'mastercard':
        return creditCardBlue;
      case 'cash':
        return cashGreen;
      default:
        return brandBlue;
    }
  }
}
