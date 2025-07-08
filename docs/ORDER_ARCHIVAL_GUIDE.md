# Order Archival System Guide

## Overview

The Order Archival System is designed to manage database storage costs and performance by automatically moving old orders through a tiered retention strategy. This system ensures that important order data is preserved while reducing storage costs for older, less frequently accessed orders.

## Architecture

### Three-Tier Storage System

1. **Active Orders** (`orders` collection)
   - Recent orders (0-30 days after delivery)
   - Full order data with all details
   - Real-time access for customer service

2. **Archived Orders** (`archived_orders` collection)
   - Orders 30-90 days after delivery
   - Reduced data (removed images, detailed addresses)
   - Still accessible for customer service

3. **Historical Orders** (`historical_orders` collection)
   - Orders 90-365 days after delivery
   - Minimal data for analytics only
   - Basic order information preserved

4. **Permanent Deletion**
   - Orders older than 1 year
   - Completely removed from database
   - Only aggregated analytics data preserved

## Configuration

### Retention Periods

```dart
// In OrderService
static const int _archiveAfterDays = 30;    // Archive after 30 days
static const int _compressAfterDays = 90;   // Compress after 90 days  
static const int _deleteAfterDays = 365;    // Delete after 1 year
```

### Cloud Function Schedule

- **Daily at 2 AM**: Archive old delivered orders
- **Weekly on Sunday at 3 AM**: Compress old archived orders
- **Monthly on 1st at 4 AM**: Delete old historical orders

## Data Structure

### Active Order (Full Data)
```json
{
  "id": "order_123",
  "status": "delivered",
  "total": 15000,
  "subtotal": 14000,
  "shippingCost": 1000,
  "tax": 0,
  "storeId": "store_456",
  "storeName": "My Store",
  "vendorId": "vendor_789",
  "userId": "user_123",
  "userEmail": "user@example.com",
  "customerName": "John Doe",
  "createdAt": "2024-01-01T10:00:00Z",
  "updatedAt": "2024-01-02T15:30:00Z",
  "items": [
    {
      "name": "Product Name",
      "price": 7000,
      "quantity": 2,
      "variant": "Large",
      "imageUrl": "https://example.com/image.jpg"
    }
  ],
  "deliveryAddress": {
    "firstName": "John",
    "lastName": "Doe",
    "line1": "123 Main St",
    "city": "Ulaanbaatar",
    "postalCode": "12345"
  },
  "analytics": {
    "category": "Electronics",
    "commission": 750
  }
}
```

### Archived Order (Reduced Data)
```json
{
  "orderId": "order_123",
  "status": "delivered",
  "total": 15000,
  "subtotal": 14000,
  "shippingCost": 1000,
  "tax": 0,
  "storeId": "store_456",
  "storeName": "My Store",
  "vendorId": "vendor_789",
  "userId": "user_123",
  "userEmail": "user@example.com",
  "customerName": "John Doe",
  "createdAt": "2024-01-01T10:00:00Z",
  "deliveredAt": "2024-01-02T15:30:00Z",
  "archivedAt": "2024-02-01T02:00:00Z",
  "itemCount": 2,
  "items": [
    {
      "name": "Product Name",
      "price": 7000,
      "quantity": 2,
      "variant": "Large"
      // imageUrl removed
    }
  ],
  "analytics": {
    "category": "Electronics",
    "commission": 750
  }
}
```

### Historical Order (Minimal Data)
```json
{
  "orderId": "order_123",
  "status": "delivered",
  "total": 15000,
  "storeId": "store_456",
  "vendorId": "vendor_789",
  "userId": "user_123",
  "createdAt": "2024-01-01T10:00:00Z",
  "deliveredAt": "2024-01-02T15:30:00Z",
  "compressedAt": "2024-04-01T03:00:00Z",
  "itemCount": 2,
  "analytics": {
    "category": "Electronics",
    "commission": 750
  }
}
```

## Implementation

### OrderService Methods

```dart
// Archive old delivered orders
Future<void> archiveOldOrders()

// Compress old archived orders
Future<void> compressOldArchivedOrders()

// Delete old historical orders
Future<void> deleteOldHistoricalOrders()

// Get order from appropriate collection
Future<Map<String, dynamic>?> getOrderById(String orderId)

// Get store orders from all collections
Future<List<Map<String, dynamic>>> getStoreOrders(String storeId, {
  String? status,
  DateTime? startDate,
  DateTime? endDate,
})

// Run complete cleanup process
Future<void> runOrderCleanup()
```

### Cloud Functions

#### Automated Functions
- `archiveOldOrders`: Daily scheduled function
- `compressOldArchivedOrders`: Weekly scheduled function
- `deleteOldHistoricalOrders`: Monthly scheduled function

#### Manual Function
- `manualOrderCleanup`: HTTP callable function for manual cleanup

### Admin Panel Integration

The admin panel includes an Order Cleanup page (`OrderCleanupPage`) that provides:

- Visual representation of cleanup rules
- Manual trigger buttons for each cleanup stage
- Real-time status updates
- Historical cleanup results

## Usage

### Automatic Cleanup

The system runs automatically based on the configured schedule. No manual intervention is required.

### Manual Cleanup

Admins can trigger manual cleanup through the admin panel:

1. Navigate to "Захиалгын цэвэрлэлт" in the admin panel
2. Click on individual cleanup actions or "Бүгдийг цэвэрлэх"
3. Monitor the status in real-time

### Programmatic Access

```dart
// Get order from any collection
final orderService = OrderService();
final order = await orderService.getOrderById('order_123');

// Get store orders with date range
final orders = await orderService.getStoreOrders(
  'store_456',
  startDate: DateTime.now().subtract(Duration(days: 30)),
  endDate: DateTime.now(),
);

// Manual cleanup
await orderService.runOrderCleanup();
```

## Benefits

### Storage Cost Reduction
- **Active Orders**: Full data for immediate access
- **Archived Orders**: ~40% data reduction
- **Historical Orders**: ~80% data reduction
- **Permanent Deletion**: 100% cost elimination for old data

### Performance Improvements
- Faster queries on active orders
- Reduced index sizes
- Better cache efficiency
- Improved backup times

### Data Preservation
- Essential analytics data preserved
- Customer service access maintained
- Compliance with data retention policies
- Audit trail available

## Monitoring

### Cloud Function Logs
Monitor the scheduled functions in Firebase Console:
- Function execution times
- Success/failure rates
- Number of orders processed
- Error messages

### Admin Panel Metrics
The Order Cleanup page shows:
- Last cleanup execution time
- Number of orders processed
- Success/failure status
- Manual trigger history

## Troubleshooting

### Common Issues

1. **Function Timeout**
   - Increase function timeout in Firebase Console
   - Reduce batch size in cleanup functions

2. **Permission Errors**
   - Ensure Cloud Functions have proper Firestore permissions
   - Check authentication for manual triggers

3. **Data Inconsistency**
   - Verify order status before archival
   - Check for missing required fields

### Recovery Procedures

1. **Restore Archived Order**
   ```dart
   // Copy from archived_orders back to orders
   final archivedOrder = await db.collection('archived_orders').doc(orderId).get();
   if (archivedOrder.exists) {
     await db.collection('orders').doc(orderId).set(archivedOrder.data()!);
   }
   ```

2. **Skip Cleanup for Specific Orders**
   - Add `skipCleanup: true` field to orders that should not be archived
   - Modify cleanup functions to check this field

## Future Enhancements

### Planned Features
- Configurable retention periods per store
- Customer notification before archival
- Data export before deletion
- Advanced analytics on archived data
- Integration with external backup systems

### Performance Optimizations
- Parallel processing for large datasets
- Incremental cleanup to reduce function duration
- Smart batching based on order volume
- Caching frequently accessed archived data

## Security Considerations

- All cleanup operations are logged
- Only authenticated users can trigger manual cleanup
- Data is permanently deleted after 1 year
- Backup systems preserve critical data
- Audit trail maintained for compliance

## Compliance

This system is designed to comply with:
- Data protection regulations
- Financial record keeping requirements
- Customer service obligations
- Business continuity needs

The tiered approach ensures that data is retained for appropriate periods while minimizing storage costs and maintaining system performance. 