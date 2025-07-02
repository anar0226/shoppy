# Personalized Recommendation System

This module implements a TikTok-style "For You" algorithm to show users personalized store recommendations.

## Features

### 1. User Preferences
- Gender targeting (Male, Female, Non-binary, No preference)
- Age group preferences
- Interest categories
- Shopping styles
- Price range preferences

### 2. Store Metadata
- Target demographics
- Category distribution
- Style keywords
- Price range classification
- Popularity scoring

### 3. Smart Recommendation Algorithm
- Gender matching (40% weight)
- Category interest matching (30% weight)
- Behavioral scoring (20% weight)
- Store quality & popularity (10% weight)
- Diversity filtering to avoid similar stores

### 4. Behavioral Learning
- Tracks user views, purchases, follows
- Updates preference scores automatically
- Learns from user interactions

## Usage

```dart
// Get personalized recommendations
final recommendations = await RecommendationService()
    .getPersonalizedRecommendations(
        userId: 'user123',
        limit: 10,
    );

// Update user behavior
await RecommendationService().updateUserBehavior(
    userId: 'user123',
    action: 'view',
    storeId: 'store456',
    category: 'Women',
);
```

## Database Collections

- `user_preferences` - User preference data
- `store_metadata` - Store targeting information  
- Auto-generated metadata for existing stores

## Key Benefits

✅ **Personalized Experience** - Shows relevant stores for each user
✅ **Gender-Appropriate** - Avoids showing male products to female users  
✅ **Behavioral Learning** - Gets smarter over time
✅ **Diversity** - Prevents showing too many similar stores
✅ **Fallback Support** - Works even without user preferences 