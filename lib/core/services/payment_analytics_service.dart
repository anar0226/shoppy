import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment_monitoring_service.dart';

/// Payment Analytics Configuration
class PaymentAnalyticsConfig {
  final Duration analysisInterval;
  final Duration reportGenerationInterval;
  final bool enableRealTimeAnalytics;
  final bool enablePredictiveAnalytics;
  final bool enableAlerts;
  final int maxDataPoints;
  final Duration dataRetentionPeriod;
  final List<String> enabledMetrics;

  const PaymentAnalyticsConfig({
    this.analysisInterval = const Duration(minutes: 5),
    this.reportGenerationInterval = const Duration(hours: 1),
    this.enableRealTimeAnalytics = true,
    this.enablePredictiveAnalytics = true,
    this.enableAlerts = true,
    this.maxDataPoints = 10000,
    this.dataRetentionPeriod = const Duration(days: 365),
    this.enabledMetrics = const [
      'volume',
      'success_rate',
      'response_time',
      'error_rate',
      'revenue',
      'customer_patterns',
      'geographic_distribution',
      'method_performance',
    ],
  });
}

/// Payment Analytics Time Period
enum AnalyticsTimePeriod {
  realTime,
  hour,
  day,
  week,
  month,
  quarter,
  year,
  custom,
}

/// Payment Analytics Metric Type
enum AnalyticsMetricType {
  volume,
  revenue,
  successRate,
  failureRate,
  averageAmount,
  responseTime,
  errorRate,
  customerCount,
  conversionRate,
  refundRate,
}

/// Payment Analytics Dimension
enum AnalyticsDimension {
  time,
  paymentMethod,
  currency,
  geography,
  customer,
  store,
  device,
  channel,
  errorType,
  status,
}

/// Payment Analytics Data Point
class PaymentAnalyticsDataPoint {
  final DateTime timestamp;
  final AnalyticsMetricType metric;
  final double value;
  final String? dimension;
  final Map<String, dynamic> metadata;

  const PaymentAnalyticsDataPoint({
    required this.timestamp,
    required this.metric,
    required this.value,
    this.dimension,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'metric': metric.toString(),
      'value': value,
      'dimension': dimension,
      'metadata': metadata,
    };
  }
}

/// Payment Analytics Report
class PaymentAnalyticsReport {
  final String id;
  final DateTime generatedAt;
  final AnalyticsTimePeriod period;
  final DateTime startTime;
  final DateTime endTime;
  final Map<String, dynamic> summary;
  final Map<String, List<PaymentAnalyticsDataPoint>> metrics;
  final List<PaymentAnalyticsInsight> insights;
  final List<PaymentAnalyticsAlert> alerts;

  const PaymentAnalyticsReport({
    required this.id,
    required this.generatedAt,
    required this.period,
    required this.startTime,
    required this.endTime,
    required this.summary,
    required this.metrics,
    required this.insights,
    required this.alerts,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'period': period.toString(),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'summary': summary,
      'metricsCount': metrics.length,
      'insightsCount': insights.length,
      'alertsCount': alerts.length,
    };
  }
}

/// Payment Analytics Insight
class PaymentAnalyticsInsight {
  final String id;
  final String title;
  final String description;
  final String category;
  final double confidence;
  final Map<String, dynamic> data;
  final DateTime generatedAt;

  const PaymentAnalyticsInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.confidence,
    required this.data,
    required this.generatedAt,
  });
}

/// Payment Analytics Alert
class PaymentAnalyticsAlert {
  final String id;
  final String title;
  final String message;
  final String severity;
  final AnalyticsMetricType metric;
  final double threshold;
  final double actualValue;
  final DateTime triggeredAt;

  const PaymentAnalyticsAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.metric,
    required this.threshold,
    required this.actualValue,
    required this.triggeredAt,
  });
}

/// Payment Analytics Service
class PaymentAnalyticsService {
  static final PaymentAnalyticsService _instance =
      PaymentAnalyticsService._internal();
  factory PaymentAnalyticsService() => _instance;
  PaymentAnalyticsService._internal();

  final PaymentMonitoringService _monitoringService =
      PaymentMonitoringService();

  PaymentAnalyticsConfig _config = const PaymentAnalyticsConfig();
  Timer? _analysisTimer;
  Timer? _reportTimer;

  final Map<String, List<PaymentAnalyticsDataPoint>> _realTimeData = {};
  final Map<String, PaymentAnalyticsAlert> _activeAlerts = {};

  final StreamController<PaymentAnalyticsReport> _reportController =
      StreamController.broadcast();
  final StreamController<PaymentAnalyticsDataPoint> _dataController =
      StreamController.broadcast();
  final StreamController<PaymentAnalyticsInsight> _insightController =
      StreamController.broadcast();
  final StreamController<PaymentAnalyticsAlert> _alertController =
      StreamController.broadcast();

  /// Initialize the payment analytics service
  Future<void> initialize({PaymentAnalyticsConfig? config}) async {
    _config = config ?? const PaymentAnalyticsConfig();

    log('PaymentAnalyticsService: Initialized with config: '
        'analysis=${_config.analysisInterval.inMinutes}min, '
        'reporting=${_config.reportGenerationInterval.inHours}h, '
        'realTime=${_config.enableRealTimeAnalytics}');

    if (_config.enableRealTimeAnalytics) {
      await _startRealTimeAnalytics();
    }

    // Start periodic analysis
    _startPeriodicAnalysis();

    // Start periodic reporting
    _startPeriodicReporting();

    // Subscribe to payment events
    _subscribeToPaymentEvents();
  }

  /// Get analytics reports stream
  Stream<PaymentAnalyticsReport> get analyticsReports =>
      _reportController.stream;

  /// Get analytics data stream
  Stream<PaymentAnalyticsDataPoint> get analyticsData => _dataController.stream;

  /// Get analytics insights stream
  Stream<PaymentAnalyticsInsight> get analyticsInsights =>
      _insightController.stream;

  /// Get analytics alerts stream
  Stream<PaymentAnalyticsAlert> get analyticsAlerts => _alertController.stream;

  /// Generate comprehensive analytics report
  Future<PaymentAnalyticsReport> generateAnalyticsReport({
    required AnalyticsTimePeriod period,
    DateTime? startTime,
    DateTime? endTime,
    List<AnalyticsMetricType>? metrics,
    List<AnalyticsDimension>? dimensions,
  }) async {
    final reportId = 'report_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    try {
      log('PaymentAnalyticsService: Generating analytics report $reportId for period $period');

      // Calculate time range
      final timeRange = _calculateTimeRange(period, startTime, endTime);
      final reportStartTime = timeRange['start'] as DateTime;
      final reportEndTime = timeRange['end'] as DateTime;

      // Collect raw data
      final rawData = await _collectRawData(reportStartTime, reportEndTime);

      // Process metrics
      final processedMetrics = await _processMetrics(
        rawData,
        metrics ?? AnalyticsMetricType.values,
        dimensions ?? AnalyticsDimension.values,
      );

      // Generate summary
      final summary = await _generateSummary(rawData, processedMetrics);

      // Generate insights
      final insights = await _generateInsights(rawData, processedMetrics);

      // Check for alerts
      final alerts = await _checkAnalyticsAlerts(processedMetrics);

      // Create report
      final report = PaymentAnalyticsReport(
        id: reportId,
        generatedAt: now,
        period: period,
        startTime: reportStartTime,
        endTime: reportEndTime,
        summary: summary,
        metrics: processedMetrics,
        insights: insights,
        alerts: alerts,
      );

      // Store report
      await _storeAnalyticsReport(report);

      // Emit report
      _reportController.add(report);

      log('PaymentAnalyticsService: Analytics report $reportId generated successfully');
      return report;
    } catch (e) {
      log('PaymentAnalyticsService: Error generating analytics report: $e');
      throw Exception('Failed to generate analytics report: $e');
    }
  }

  /// Get real-time analytics dashboard data
  Future<Map<String, dynamic>> getRealTimeDashboardData() async {
    try {
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));

      // Get recent payment events
      final recentPayments = await _getPaymentEvents(oneHourAgo, now);

      // Calculate real-time metrics
      final totalPayments = recentPayments.length;
      final successfulPayments =
          recentPayments.where((p) => p['status'] == 'PAID').length;
      final failedPayments =
          recentPayments.where((p) => p['status'] == 'FAILED').length;

      final totalAmount = recentPayments.fold<double>(
        0,
        (accumulator, payment) =>
            accumulator + ((payment['amount'] as num?)?.toDouble() ?? 0),
      );

      final successRate =
          totalPayments > 0 ? (successfulPayments / totalPayments) * 100 : 0.0;
      final failureRate =
          totalPayments > 0 ? (failedPayments / totalPayments) * 100 : 0.0;

      // Calculate response time metrics
      final responseTimes = recentPayments
          .where((p) => p['processingTime'] != null)
          .map((p) => (p['processingTime'] as num).toDouble())
          .toList();

      final avgResponseTime = responseTimes.isNotEmpty
          ? responseTimes.reduce((a, b) => a + b) / responseTimes.length
          : 0.0;

      // Payment method breakdown
      final methodBreakdown = <String, int>{};
      for (final payment in recentPayments) {
        final method = payment['method'] as String? ?? 'unknown';
        methodBreakdown[method] = (methodBreakdown[method] ?? 0) + 1;
      }

      // Currency breakdown
      final currencyBreakdown = <String, double>{};
      for (final payment in recentPayments) {
        final currency = payment['currency'] as String? ?? 'MNT';
        final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
        currencyBreakdown[currency] =
            (currencyBreakdown[currency] ?? 0) + amount;
      }

      return {
        'timestamp': now.toIso8601String(),
        'period': 'last_hour',
        'totalPayments': totalPayments,
        'successfulPayments': successfulPayments,
        'failedPayments': failedPayments,
        'totalAmount': totalAmount,
        'successRate': successRate,
        'failureRate': failureRate,
        'averageResponseTime': avgResponseTime,
        'methodBreakdown': methodBreakdown,
        'currencyBreakdown': currencyBreakdown,
        'averagePaymentAmount':
            totalPayments > 0 ? totalAmount / totalPayments : 0,
      };
    } catch (e) {
      log('PaymentAnalyticsService: Error getting real-time dashboard data: $e');
      return {};
    }
  }

  /// Get payment performance metrics
  Future<Map<String, dynamic>> getPaymentPerformanceMetrics({
    required DateTime startTime,
    required DateTime endTime,
    AnalyticsDimension? groupBy,
  }) async {
    try {
      final rawData = await _collectRawData(startTime, endTime);

      // Calculate performance metrics
      final totalTransactions = rawData.length;
      final successfulTransactions =
          rawData.where((p) => p['status'] == 'PAID').length;
      final failedTransactions =
          rawData.where((p) => p['status'] == 'FAILED').length;

      final totalAmount = rawData.fold<double>(
        0,
        (accumulator, payment) =>
            accumulator + ((payment['amount'] as num?)?.toDouble() ?? 0),
      );

      final successRate = totalTransactions > 0
          ? (successfulTransactions / totalTransactions) * 100
          : 0.0;
      final failureRate = totalTransactions > 0
          ? (failedTransactions / totalTransactions) * 100
          : 0.0;

      // Response time analysis
      final responseTimes = rawData
          .where((p) => p['processingTime'] != null)
          .map((p) => (p['processingTime'] as num).toDouble())
          .toList();

      responseTimes.sort();

      final avgResponseTime = responseTimes.isNotEmpty
          ? responseTimes.reduce((a, b) => a + b) / responseTimes.length
          : 0.0;

      final medianResponseTime = responseTimes.isNotEmpty
          ? responseTimes[responseTimes.length ~/ 2]
          : 0.0;

      final p95ResponseTime = responseTimes.isNotEmpty
          ? responseTimes[(responseTimes.length * 0.95).floor()]
          : 0.0;

      final p99ResponseTime = responseTimes.isNotEmpty
          ? responseTimes[(responseTimes.length * 0.99).floor()]
          : 0.0;

      // Error breakdown
      final errorBreakdown = <String, int>{};
      for (final payment in rawData.where((p) => p['status'] == 'FAILED')) {
        final error = payment['error'] as String? ?? 'unknown';
        errorBreakdown[error] = (errorBreakdown[error] ?? 0) + 1;
      }

      // Method performance
      final methodPerformance = <String, Map<String, dynamic>>{};
      for (final method
          in rawData.map((p) => p['method'] as String? ?? 'unknown').toSet()) {
        final methodPayments = rawData
            .where((p) => (p['method'] as String? ?? 'unknown') == method)
            .toList();
        final methodSuccess =
            methodPayments.where((p) => p['status'] == 'PAID').length;
        final methodTotal = methodPayments.length;

        methodPerformance[method] = {
          'totalTransactions': methodTotal,
          'successfulTransactions': methodSuccess,
          'successRate':
              methodTotal > 0 ? (methodSuccess / methodTotal) * 100 : 0.0,
          'totalAmount': methodPayments.fold<double>(
            0,
            (accumulator, payment) =>
                accumulator + ((payment['amount'] as num?)?.toDouble() ?? 0),
          ),
        };
      }

      return {
        'period': {
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
        },
        'totalTransactions': totalTransactions,
        'successfulTransactions': successfulTransactions,
        'failedTransactions': failedTransactions,
        'totalAmount': totalAmount,
        'successRate': successRate,
        'failureRate': failureRate,
        'averageAmount':
            totalTransactions > 0 ? totalAmount / totalTransactions : 0,
        'responseTime': {
          'average': avgResponseTime,
          'median': medianResponseTime,
          'p95': p95ResponseTime,
          'p99': p99ResponseTime,
        },
        'errorBreakdown': errorBreakdown,
        'methodPerformance': methodPerformance,
      };
    } catch (e) {
      log('PaymentAnalyticsService: Error getting payment performance metrics: $e');
      return {};
    }
  }

  /// Get customer payment patterns
  Future<Map<String, dynamic>> getCustomerPaymentPatterns({
    required DateTime startTime,
    required DateTime endTime,
    int? limit,
  }) async {
    try {
      final rawData = await _collectRawData(startTime, endTime);

      // Group by customer
      final customerData = <String, List<Map<String, dynamic>>>{};
      for (final payment in rawData) {
        final customerId = payment['userId'] as String? ?? 'anonymous';
        customerData.putIfAbsent(customerId, () => []).add(payment);
      }

      // Analyze customer patterns
      final customerPatterns = <String, Map<String, dynamic>>{};
      for (final entry in customerData.entries) {
        final customerId = entry.key;
        final payments = entry.value;

        final totalAmount = payments.fold<double>(
          0,
          (accumulator, payment) =>
              accumulator + ((payment['amount'] as num?)?.toDouble() ?? 0),
        );

        final successfulPayments =
            payments.where((p) => p['status'] == 'PAID').length;
        final failedPayments =
            payments.where((p) => p['status'] == 'FAILED').length;

        // Calculate payment frequency
        final paymentDates = payments
            .map((p) => (p['timestamp'] as Timestamp).toDate())
            .toList();
        paymentDates.sort();

        final daysBetweenPayments = paymentDates.isNotEmpty
            ? paymentDates.last.difference(paymentDates.first).inDays /
                (paymentDates.length - 1)
            : 0.0;

        // Preferred payment method
        final methodCounts = <String, int>{};
        for (final payment in payments) {
          final method = payment['method'] as String? ?? 'unknown';
          methodCounts[method] = (methodCounts[method] ?? 0) + 1;
        }

        final preferredMethod = methodCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;

        customerPatterns[customerId] = {
          'totalPayments': payments.length,
          'successfulPayments': successfulPayments,
          'failedPayments': failedPayments,
          'totalAmount': totalAmount,
          'averageAmount':
              payments.isNotEmpty ? totalAmount / payments.length : 0,
          'successRate': payments.isNotEmpty
              ? (successfulPayments / payments.length) * 100
              : 0,
          'daysBetweenPayments': daysBetweenPayments,
          'preferredMethod': preferredMethod,
          'firstPayment': paymentDates.isNotEmpty
              ? paymentDates.first.toIso8601String()
              : null,
          'lastPayment': paymentDates.isNotEmpty
              ? paymentDates.last.toIso8601String()
              : null,
        };
      }

      // Sort by total amount and limit results
      final sortedPatterns = customerPatterns.entries.toList()
        ..sort((a, b) => (b.value['totalAmount'] as double)
            .compareTo(a.value['totalAmount'] as double));

      final limitedPatterns = limit != null && limit > 0
          ? sortedPatterns.take(limit).toList()
          : sortedPatterns;

      // Calculate aggregate statistics
      final totalCustomers = customerPatterns.length;
      final activeCustomers =
          customerPatterns.values.where((p) => p['totalPayments'] > 0).length;
      final highValueCustomers = customerPatterns.values
          .where((p) => p['totalAmount'] > 100000)
          .length;

      final avgPaymentsPerCustomer = totalCustomers > 0
          ? customerPatterns.values.fold<int>(
                  0,
                  (accumulator, p) =>
                      accumulator + (p['totalPayments'] as int)) /
              totalCustomers
          : 0.0;

      return {
        'period': {
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
        },
        'summary': {
          'totalCustomers': totalCustomers,
          'activeCustomers': activeCustomers,
          'highValueCustomers': highValueCustomers,
          'averagePaymentsPerCustomer': avgPaymentsPerCustomer,
        },
        'customerPatterns': Map.fromEntries(limitedPatterns),
      };
    } catch (e) {
      log('PaymentAnalyticsService: Error getting customer payment patterns: $e');
      return {};
    }
  }

  /// Get payment trends analysis
  Future<Map<String, dynamic>> getPaymentTrends({
    required DateTime startTime,
    required DateTime endTime,
    required AnalyticsTimePeriod granularity,
  }) async {
    try {
      final rawData = await _collectRawData(startTime, endTime);

      // Group data by time periods
      final timeGroups = <String, List<Map<String, dynamic>>>{};
      for (final payment in rawData) {
        final timestamp = (payment['timestamp'] as Timestamp).toDate();
        final timeKey = _getTimeKey(timestamp, granularity);
        timeGroups.putIfAbsent(timeKey, () => []).add(payment);
      }

      // Calculate trends for each time period
      final trends = <String, Map<String, dynamic>>{};
      for (final entry in timeGroups.entries) {
        final timeKey = entry.key;
        final payments = entry.value;

        final totalAmount = payments.fold<double>(
          0,
          (accumulator, payment) =>
              accumulator + ((payment['amount'] as num?)?.toDouble() ?? 0),
        );

        final successfulPayments =
            payments.where((p) => p['status'] == 'PAID').length;
        final failedPayments =
            payments.where((p) => p['status'] == 'FAILED').length;

        trends[timeKey] = {
          'totalPayments': payments.length,
          'successfulPayments': successfulPayments,
          'failedPayments': failedPayments,
          'totalAmount': totalAmount,
          'averageAmount':
              payments.isNotEmpty ? totalAmount / payments.length : 0,
          'successRate': payments.isNotEmpty
              ? (successfulPayments / payments.length) * 100
              : 0,
        };
      }

      // Calculate period-over-period changes
      final sortedTrends = trends.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      final trendsWithChanges = <String, Map<String, dynamic>>{};
      for (int i = 0; i < sortedTrends.length; i++) {
        final current = sortedTrends[i];
        final previous = i > 0 ? sortedTrends[i - 1] : null;

        final currentData = current.value;
        final changes = <String, dynamic>{};

        if (previous != null) {
          final previousData = previous.value;

          changes['paymentsChange'] = _calculatePercentageChange(
            previousData['totalPayments'] as int,
            currentData['totalPayments'] as int,
          );

          changes['amountChange'] = _calculatePercentageChange(
            previousData['totalAmount'] as double,
            currentData['totalAmount'] as double,
          );

          changes['successRateChange'] = _calculatePercentageChange(
            previousData['successRate'] as double,
            currentData['successRate'] as double,
          );
        }

        trendsWithChanges[current.key] = {
          ...currentData,
          'changes': changes,
        };
      }

      return {
        'period': {
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'granularity': granularity.toString(),
        },
        'trends': trendsWithChanges,
      };
    } catch (e) {
      log('PaymentAnalyticsService: Error getting payment trends: $e');
      return {};
    }
  }

  /// Start real-time analytics
  Future<void> _startRealTimeAnalytics() async {
    // Subscribe to payment events for real-time processing
    // This would integrate with the payment monitoring service
    log('PaymentAnalyticsService: Real-time analytics started');
  }

  /// Start periodic analysis
  void _startPeriodicAnalysis() {
    _analysisTimer = Timer.periodic(_config.analysisInterval, (timer) {
      _performPeriodicAnalysis();
    });
  }

  /// Start periodic reporting
  void _startPeriodicReporting() {
    _reportTimer = Timer.periodic(_config.reportGenerationInterval, (timer) {
      _generatePeriodicReport();
    });
  }

  /// Subscribe to payment events
  void _subscribeToPaymentEvents() {
    // Subscribe to monitoring service events
    try {
      _monitoringService.paymentEvents.listen((event) {
        _processPaymentEvent(event);
      });
    } catch (e) {
      log('PaymentAnalyticsService: Error subscribing to payment events: $e');
    }
  }

  /// Process payment event for analytics
  void _processPaymentEvent(dynamic event) {
    // Process real-time payment events
    // This would extract analytics data and emit insights
  }

  /// Perform periodic analysis
  void _performPeriodicAnalysis() {
    // Perform scheduled analysis tasks
    log('PaymentAnalyticsService: Performing periodic analysis');
  }

  /// Generate periodic report
  void _generatePeriodicReport() {
    // Generate scheduled reports
    log('PaymentAnalyticsService: Generating periodic report');
  }

  /// Calculate time range for analytics
  Map<String, DateTime> _calculateTimeRange(
    AnalyticsTimePeriod period,
    DateTime? startTime,
    DateTime? endTime,
  ) {
    final now = DateTime.now();

    if (period == AnalyticsTimePeriod.custom) {
      return {
        'start': startTime ?? now.subtract(const Duration(days: 1)),
        'end': endTime ?? now,
      };
    }

    switch (period) {
      case AnalyticsTimePeriod.realTime:
        return {
          'start': now.subtract(const Duration(hours: 1)),
          'end': now,
        };
      case AnalyticsTimePeriod.hour:
        return {
          'start': now.subtract(const Duration(hours: 1)),
          'end': now,
        };
      case AnalyticsTimePeriod.day:
        return {
          'start': now.subtract(const Duration(days: 1)),
          'end': now,
        };
      case AnalyticsTimePeriod.week:
        return {
          'start': now.subtract(const Duration(days: 7)),
          'end': now,
        };
      case AnalyticsTimePeriod.month:
        return {
          'start': now.subtract(const Duration(days: 30)),
          'end': now,
        };
      case AnalyticsTimePeriod.quarter:
        return {
          'start': now.subtract(const Duration(days: 90)),
          'end': now,
        };
      case AnalyticsTimePeriod.year:
        return {
          'start': now.subtract(const Duration(days: 365)),
          'end': now,
        };
      default:
        return {
          'start': now.subtract(const Duration(days: 1)),
          'end': now,
        };
    }
  }

  /// Collect raw data for analytics
  Future<List<Map<String, dynamic>>> _collectRawData(
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('payment_events')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startTime))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endTime))
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      log('PaymentAnalyticsService: Error collecting raw data: $e');
      return [];
    }
  }

  /// Get payment events for a time range
  Future<List<Map<String, dynamic>>> _getPaymentEvents(
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('payment_events')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startTime))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endTime))
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      log('PaymentAnalyticsService: Error getting payment events: $e');
      return [];
    }
  }

  /// Process metrics
  Future<Map<String, List<PaymentAnalyticsDataPoint>>> _processMetrics(
    List<Map<String, dynamic>> rawData,
    List<AnalyticsMetricType> metrics,
    List<AnalyticsDimension> dimensions,
  ) async {
    final processedMetrics = <String, List<PaymentAnalyticsDataPoint>>{};

    for (final metric in metrics) {
      processedMetrics[metric.toString()] =
          _calculateMetricDataPoints(rawData, metric);
    }

    return processedMetrics;
  }

  /// Calculate metric data points
  List<PaymentAnalyticsDataPoint> _calculateMetricDataPoints(
    List<Map<String, dynamic>> rawData,
    AnalyticsMetricType metric,
  ) {
    final dataPoints = <PaymentAnalyticsDataPoint>[];

    switch (metric) {
      case AnalyticsMetricType.volume:
        dataPoints.add(PaymentAnalyticsDataPoint(
          timestamp: DateTime.now(),
          metric: metric,
          value: rawData.length.toDouble(),
        ));
        break;
      case AnalyticsMetricType.revenue:
        final totalAmount = rawData.fold<double>(
          0,
          (accumulator, payment) =>
              accumulator + ((payment['amount'] as num?)?.toDouble() ?? 0),
        );
        dataPoints.add(PaymentAnalyticsDataPoint(
          timestamp: DateTime.now(),
          metric: metric,
          value: totalAmount,
        ));
        break;
      case AnalyticsMetricType.successRate:
        final successfulPayments =
            rawData.where((p) => p['status'] == 'PAID').length;
        final successRate = rawData.isNotEmpty
            ? (successfulPayments / rawData.length) * 100
            : 0.0;
        dataPoints.add(PaymentAnalyticsDataPoint(
          timestamp: DateTime.now(),
          metric: metric,
          value: successRate,
        ));
        break;
      default:
        // Add other metric calculations as needed
        break;
    }

    return dataPoints;
  }

  /// Generate summary
  Future<Map<String, dynamic>> _generateSummary(
    List<Map<String, dynamic>> rawData,
    Map<String, List<PaymentAnalyticsDataPoint>> metrics,
  ) async {
    final totalPayments = rawData.length;
    final successfulPayments =
        rawData.where((p) => p['status'] == 'PAID').length;
    final failedPayments = rawData.where((p) => p['status'] == 'FAILED').length;

    final totalAmount = rawData.fold<double>(
      0,
      (accumulator, payment) =>
          accumulator + ((payment['amount'] as num?)?.toDouble() ?? 0),
    );

    return {
      'totalPayments': totalPayments,
      'successfulPayments': successfulPayments,
      'failedPayments': failedPayments,
      'totalAmount': totalAmount,
      'successRate':
          totalPayments > 0 ? (successfulPayments / totalPayments) * 100 : 0.0,
      'averageAmount': totalPayments > 0 ? totalAmount / totalPayments : 0.0,
    };
  }

  /// Generate insights
  Future<List<PaymentAnalyticsInsight>> _generateInsights(
    List<Map<String, dynamic>> rawData,
    Map<String, List<PaymentAnalyticsDataPoint>> metrics,
  ) async {
    final insights = <PaymentAnalyticsInsight>[];

    // Generate various insights based on the data
    // This is a simplified example - real implementation would be more sophisticated

    return insights;
  }

  /// Check for analytics alerts
  Future<List<PaymentAnalyticsAlert>> _checkAnalyticsAlerts(
    Map<String, List<PaymentAnalyticsDataPoint>> metrics,
  ) async {
    final alerts = <PaymentAnalyticsAlert>[];

    // Check for alert conditions
    // This is a simplified example - real implementation would be more sophisticated

    return alerts;
  }

  /// Store analytics report
  Future<void> _storeAnalyticsReport(PaymentAnalyticsReport report) async {
    try {
      await FirebaseFirestore.instance
          .collection('payment_analytics_reports')
          .doc(report.id)
          .set(report.toMap());
    } catch (e) {
      log('PaymentAnalyticsService: Error storing analytics report: $e');
    }
  }

  /// Get time key for grouping
  String _getTimeKey(DateTime timestamp, AnalyticsTimePeriod granularity) {
    switch (granularity) {
      case AnalyticsTimePeriod.hour:
        return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}';
      case AnalyticsTimePeriod.day:
        return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
      case AnalyticsTimePeriod.week:
        final weekOfYear = _getWeekOfYear(timestamp);
        return '${timestamp.year}-W${weekOfYear.toString().padLeft(2, '0')}';
      case AnalyticsTimePeriod.month:
        return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}';
      case AnalyticsTimePeriod.quarter:
        final quarter = ((timestamp.month - 1) ~/ 3) + 1;
        return '${timestamp.year}-Q$quarter';
      case AnalyticsTimePeriod.year:
        return timestamp.year.toString();
      default:
        return timestamp.toIso8601String();
    }
  }

  /// Get week of year
  int _getWeekOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(startOfYear).inDays + 1;
    return ((dayOfYear - 1) ~/ 7) + 1;
  }

  /// Calculate percentage change
  double _calculatePercentageChange(num previous, num current) {
    if (previous == 0) return current == 0 ? 0.0 : 100.0;
    return ((current - previous) / previous) * 100;
  }

  /// Get comprehensive analytics overview
  Future<Map<String, dynamic>> getAnalyticsOverview() async {
    try {
      final now = DateTime.now();

      // Get data for different time periods
      final last24h = await getRealTimeDashboardData();
      final last7d = await getPaymentPerformanceMetrics(
        startTime: now.subtract(const Duration(days: 7)),
        endTime: now,
      );
      final last30d = await getPaymentPerformanceMetrics(
        startTime: now.subtract(const Duration(days: 30)),
        endTime: now,
      );

      return {
        'timestamp': now.toIso8601String(),
        'last24h': last24h,
        'last7d': last7d,
        'last30d': last30d,
        'systemHealth': {
          'activeMonitors': _monitoringService.activeMonitorsCount,
          'activeAlerts': _monitoringService.activeAlertsCount,
          'healthStatus': _monitoringService.currentHealthStatus.toString(),
        },
      };
    } catch (e) {
      log('PaymentAnalyticsService: Error getting analytics overview: $e');
      return {};
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _analysisTimer?.cancel();
    _reportTimer?.cancel();

    _realTimeData.clear();
    _activeAlerts.clear();

    await _reportController.close();
    await _dataController.close();
    await _insightController.close();
    await _alertController.close();
  }
}
