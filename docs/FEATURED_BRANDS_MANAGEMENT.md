# Featured Brands Management System

## Overview

The Featured Brands Management System allows super admins to select and manage which stores/brands are featured within specific categories and subcategories. This system provides monetization opportunities by allowing you to highlight specific brands in different category contexts.

## Features

### 🎯 **Category-Based Brand Selection**
- Select brands to feature within specific categories
- Support for main categories, subcategories, and leaf categories
- Up to 4 brands can be featured per category combination

### 🏪 **Store Management**
- Only active stores are available for selection
- Visual store information including logos, names, and descriptions
- Drag-and-drop style interface for easy brand selection

### 💾 **Persistent Storage**
- Featured brands are stored in Firestore under `featured_brands/{categoryPath}`
- Automatic path generation based on category hierarchy
- Audit trail with timestamps and admin information

## How to Use

### 1. Access the Featured Brands Page

1. Log in to the Super Admin panel
2. Navigate to "Featured Brands" in the side menu
3. The page will load with category selection options

### 2. Select Categories

1. **Main Category**: Choose a primary category (e.g., "Women", "Men", "Electronics")
2. **Subcategory** (Optional): Select a subcategory if available
3. **Leaf Category** (Optional): Select a leaf category for more granular control

### 3. Manage Featured Brands

#### Available Brands Panel (Left Side)
- Shows all active stores not currently featured
- Click the green "+" button to add a brand to featured list
- Displays store logo, name, and description

#### Featured Brands Panel (Right Side)
- Shows currently selected brands for the category
- Click the red "-" button to remove a brand
- Maximum of 4 brands allowed per category

### 4. Save Changes

1. Click "Save Featured Brands" button
2. Success message will confirm the update
3. Changes are immediately available in the frontend

## Data Structure

### Firestore Collection: `featured_brands`

```javascript
// Document ID: {category}_{subcategory}_{leafCategory}
// Example: "Women_Tops_Shirts"

{
  "storeIds": ["store1", "store2", "store3"],
  "categoryId": "Women",
  "subcategoryId": "Tops", 
  "leafCategoryId": "Shirts",
  "updatedAt": Timestamp,
  "updatedBy": "super_admin"
}
```

### Path Examples

| Category Path | Document ID | Description |
|---------------|-------------|-------------|
| Women only | `Women` | Featured brands for Women category |
| Women > Tops | `Women_Tops` | Featured brands for Women > Tops |
| Women > Tops > Shirts | `Women_Tops_Shirts` | Featured brands for Women > Tops > Shirts |

## Frontend Integration

### Loading Featured Brands

```dart
import 'package:avii/features/categories/services/featured_brands_service.dart';

final featuredBrandsService = FeaturedBrandsService();

// Load featured brand IDs
final brandIds = await featuredBrandsService.getFeaturedBrandIds(
  category: 'Women',
  subCategory: 'Tops',
  leafCategory: 'Shirts',
);

// Load full brand details
final brands = await featuredBrandsService.getFeaturedBrands(
  category: 'Women',
  subCategory: 'Tops',
  leafCategory: 'Shirts',
);

// Check if a specific store is featured
final isFeatured = await featuredBrandsService.isStoreFeatured(
  storeId: 'store123',
  category: 'Women',
);
```

### Displaying Featured Brands

```dart
// Example: Display featured brands in a category page
Widget buildFeaturedBrandsSection(List<Map<String, dynamic>> brands) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Featured Brands',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 16),
      GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: brands.length,
        itemBuilder: (context, index) {
          final brand = brands[index];
          return BrandCard(brand: brand);
        },
      ),
    ],
  );
}
```

## Security Rules

The `featured_brands` collection has the following Firestore security rules:

```javascript
match /featured_brands/{categoryPath} {
  allow read, list: if true;  // Public read access
  allow write, create, delete: if isSuperAdmin() || isAdmin();  // Admin only
}
```

## Best Practices

### 1. **Category Strategy**
- Start with main categories for broad brand exposure
- Use subcategories for more targeted brand placement
- Consider seasonal or trending categories for dynamic content

### 2. **Brand Selection**
- Choose brands that align with the category theme
- Ensure brands have good product variety in the category
- Consider brand performance and customer satisfaction

### 3. **Content Management**
- Regularly review and update featured brands
- Monitor brand performance in featured positions
- Rotate brands to provide variety and opportunities

### 4. **Performance Optimization**
- Featured brands are cached for better performance
- Use the service methods to avoid direct Firestore calls
- Handle errors gracefully with fallback content

## Troubleshooting

### Common Issues

1. **"No brands available"**
   - Check if stores are active (`status: 'active'` or `isActive: true`)
   - Verify store documents exist in Firestore

2. **"Permission denied"**
   - Ensure you're logged in as a super admin
   - Check Firestore security rules
   - Verify super admin document exists

3. **"Save failed"**
   - Check network connectivity
   - Verify Firestore write permissions
   - Ensure category path is valid

### Error Handling

The system includes comprehensive error handling:

- **Authentication errors**: Redirect to login
- **Permission errors**: Show appropriate error messages
- **Network errors**: Retry functionality available
- **Data errors**: Graceful fallbacks to empty states

## API Reference

### FeaturedBrandsService Methods

| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `getFeaturedBrandIds()` | Get featured brand IDs | `category`, `subCategory`, `leafCategory` | `List<String>` |
| `getFeaturedBrands()` | Get full brand details | `category`, `subCategory`, `leafCategory` | `List<Map<String, dynamic>>` |
| `isStoreFeatured()` | Check if store is featured | `storeId`, `category`, `subCategory`, `leafCategory` | `bool` |
| `getAllFeaturedBrands()` | Get all featured brands | None | `Map<String, List<String>>` |

## Future Enhancements

### Planned Features

1. **Scheduling**: Set featured brands for specific time periods
2. **Analytics**: Track performance of featured brands
3. **A/B Testing**: Test different brand combinations
4. **Automated Selection**: AI-powered brand recommendations
5. **Bulk Operations**: Manage multiple categories at once

### Integration Opportunities

1. **Recommendation Engine**: Use featured brands in product recommendations
2. **Search Enhancement**: Boost featured brands in search results
3. **Email Marketing**: Include featured brands in promotional emails
4. **Mobile App**: Featured brands in push notifications

## Support

For technical support or questions about the Featured Brands Management System:

1. Check this documentation first
2. Review Firestore security rules
3. Verify super admin permissions
4. Contact the development team

---

**Last Updated**: December 2024  
**Version**: 1.0.0  
**Maintainer**: Super Admin Team 