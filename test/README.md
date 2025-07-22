# 🧪 **SHOPPY TEST SUITE**

This directory contains the comprehensive test suite for the Shoppy marketplace application.

## **📁 Directory Structure**

```
test/
├── unit/                    # Unit tests for individual components
│   ├── models/             # Data model tests
│   ├── services/           # Service layer tests
│   ├── providers/          # State management tests
│   └── utils/              # Utility function tests
├── widget/                 # Widget tests for UI components
│   ├── pages/              # Page-level widget tests
│   ├── components/         # Reusable component tests
│   └── dialogs/            # Dialog and modal tests
├── integration/            # Integration tests for feature flows
│   ├── auth_flows/         # Authentication flow tests
│   ├── shopping_flows/     # Shopping cart and checkout tests
│   ├── admin_flows/        # Admin panel tests
│   └── payment_flows/      # Payment processing tests
├── e2e/                    # End-to-end tests
│   ├── critical_user_journeys/  # Complete user scenarios
│   └── admin_workflows/         # Admin workflow scenarios
└── helpers/                # Test utilities and helpers
    ├── test_setup.dart     # Test environment setup
    ├── test_data_factory.dart  # Test data generation
    ├── mock_services.dart  # Mock service implementations
    ├── widget_test_helpers.dart # Widget testing utilities
    └── test_config.dart    # Test configuration
```

## **🚀 Getting Started**

### **Prerequisites**
- Flutter SDK (latest stable version)
- Dart SDK
- All test dependencies installed (see `pubspec.yaml`)

### **Running Tests**

#### **Unit Tests**
```bash
# Run all unit tests
flutter test test/unit/

# Run specific unit test file
flutter test test/unit/models/product_model_test.dart

# Run with coverage
flutter test --coverage test/unit/
```

#### **Widget Tests**
```bash
# Run all widget tests
flutter test test/widget/

# Run specific widget test
flutter test test/widget/pages/home_screen_test.dart
```

#### **Integration Tests**
```bash
# Run all integration tests
flutter test test/integration/

# Run specific integration test
flutter test test/integration/auth_flows/login_flow_test.dart
```

#### **E2E Tests**
```bash
# Run all E2E tests
flutter test test/e2e/

# Run with device
flutter drive --target=test/e2e/critical_user_journeys/complete_purchase_test.dart
```

#### **All Tests**
```bash
# Run entire test suite
flutter test

# Run with verbose output
flutter test --verbose

# Run with coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## **🛠️ Test Infrastructure**

### **Test Setup (`test/helpers/test_setup.dart`)**
Provides utilities for setting up test environments:
- Fake Firestore instances
- Mock Firebase Auth
- Network image mocking
- Common test operations

### **Test Data Factory (`test/helpers/test_data_factory.dart`)**
Generates consistent test data for all tests:
- User data
- Store data
- Product data
- Order data
- Cart items
- Notifications
- Reviews

### **Mock Services (`test/helpers/mock_services.dart`)**
Provides mock implementations for external services:
- Firebase services
- Authentication services
- Database services
- Storage services
- Payment services

### **Widget Test Helpers (`test/helpers/widget_test_helpers.dart`)**
Utilities for widget testing:
- Test app creation with providers
- Common widget interactions
- Navigation testing
- Async operation handling

### **Test Configuration (`test/helpers/test_config.dart`)**
Configuration for test environment:
- Test timeouts
- Environment setup
- Test data constants
- Utility functions

## **📝 Writing Tests**

### **Unit Test Example**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:avii/features/products/models/product_model.dart';
import '../../helpers/test_data_factory.dart';

void main() {
  group('ProductModel Tests', () {
    test('should create ProductModel from Firestore document', () {
      // Arrange
      final productData = TestDataFactory.createProductData();
      final documentSnapshot = FakeDocumentSnapshot(
        data: productData,
        id: productData['id'] as String,
      );

      // Act
      final product = ProductModel.fromFirestore(documentSnapshot);

      // Assert
      expect(product.id, equals(productData['id']));
      expect(product.name, equals(productData['name']));
    });
  });
}
```

### **Widget Test Example**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:avii/features/home/presentation/home_screen.dart';
import '../../helpers/widget_test_helpers.dart';

void main() {
  group('HomeScreen Tests', () {
    testWidgets('should display stores list', (WidgetTester tester) async {
      // Arrange
      final widget = WidgetTestHelpers.createTestAppWithProviders(
        child: const HomeScreen(),
      );

      // Act
      await WidgetTestHelpers.pumpAndSettle(tester, widget);

      // Assert
      expect(find.text('Stores'), findsOneWidget);
    });
  });
}
```

### **Integration Test Example**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:avii/features/auth/presentation/login_page.dart';
import '../../helpers/test_config.dart';

void main() {
  group('Login Flow Tests', () {
    testWidgets('should login successfully with valid credentials', 
        (WidgetTester tester) async {
      // Arrange
      TestConfig.setupTestEnvironment();
      
      // Act & Assert
      // Test implementation here
    });
  });
}
```

## **🎯 Test Categories**

### **Critical Tests (Must Pass)**
- Authentication flows
- Payment processing
- Order creation/management
- Product CRUD operations
- User data security

### **High Priority Tests**
- Shopping cart functionality
- Search and filtering
- Notifications
- Admin panel operations
- Error handling

### **Medium Priority Tests**
- UI components
- Analytics tracking
- Performance monitoring
- Edge cases

## **📊 Test Coverage Targets**

- **Unit Tests**: 80%+ coverage
- **Widget Tests**: 70%+ coverage
- **Integration Tests**: 60%+ coverage
- **E2E Tests**: Critical paths only

## **🔧 Test Utilities**

### **Common Test Operations**
```dart
// Wait for async operations
await WidgetTestHelpers.waitForAsync(tester);

// Tap and wait
await WidgetTestHelpers.tapAndSettle(tester, finder);

// Enter text and wait
await WidgetTestHelpers.enterTextAndSettle(tester, finder, 'text');

// Find widgets
final finder = WidgetTestHelpers.findText('Search');
final widgetFinder = WidgetTestHelpers.findWidgetByType<ElevatedButton>();
```

### **Test Data Creation**
```dart
// Create test data
final userData = TestDataFactory.createUserData();
final productData = TestDataFactory.createProductData();
final orderData = TestDataFactory.createOrderData();

// Create model instances
final product = TestDataFactory.createProductModel();
final store = TestDataFactory.createStoreModel();
```

### **Mock Service Setup**
```dart
// Setup mock services
final mockProvider = MockServiceProvider();
mockProvider.initialize();
mockProvider.setupCommonMocks();

// Use mock services in tests
when(mockProvider.authService.signIn(any, any))
    .thenAnswer((_) async => MockUserCredential());
```

## **🚨 Best Practices**

### **Test Organization**
1. **Group related tests** using `group()`
2. **Use descriptive test names** that explain the scenario
3. **Follow AAA pattern**: Arrange, Act, Assert
4. **Keep tests independent** and isolated
5. **Use setup and teardown** for common operations

### **Test Data Management**
1. **Use TestDataFactory** for consistent test data
2. **Avoid hardcoded values** in tests
3. **Clean up test data** after each test
4. **Use realistic test scenarios**

### **Mocking Guidelines**
1. **Mock external dependencies** (Firebase, APIs)
2. **Don't mock internal business logic**
3. **Use realistic mock responses**
4. **Verify mock interactions** when necessary

### **Performance Considerations**
1. **Keep tests fast** (under 1 second each)
2. **Use appropriate timeouts**
3. **Avoid unnecessary async operations**
4. **Mock expensive operations**

## **📈 Continuous Integration**

### **CI/CD Integration**
The test suite is integrated with CI/CD pipelines:
- **Unit tests** run on every commit
- **Widget tests** run on pull requests
- **Integration tests** run on staging deployments
- **E2E tests** run on production deployments

### **Test Reports**
- Coverage reports generated automatically
- Test results published to CI dashboard
- Failed tests block deployments
- Performance metrics tracked over time

## **🔄 Maintenance**

### **Regular Tasks**
- **Update test dependencies** monthly
- **Review test coverage** weekly
- **Refactor flaky tests** immediately
- **Add tests for new features** before deployment

### **Test Review Process**
1. **Code review** includes test review
2. **Test coverage** must meet minimum thresholds
3. **Performance impact** of tests is monitored
4. **Test documentation** is kept up to date

## **📚 Additional Resources**

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Mockito Documentation](https://pub.dev/packages/mockito)
- [Fake Cloud Firestore](https://pub.dev/packages/fake_cloud_firestore)
- [Firebase Auth Mocks](https://pub.dev/packages/firebase_auth_mocks)

## **🤝 Contributing**

When adding new tests:
1. **Follow existing patterns** and conventions
2. **Update this README** if adding new test categories
3. **Ensure tests pass** before submitting
4. **Add appropriate documentation** for complex tests
5. **Consider test performance** impact

---

**Happy Testing! 🎉** 