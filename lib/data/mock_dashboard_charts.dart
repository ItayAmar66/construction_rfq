import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Static mock analytics for dashboard charts (Firestore wiring later).
class ChartDataPoint {
  const ChartDataPoint({required this.label, required this.value});

  final String label;
  final double value;
}

class StatusSlice {
  const StatusSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

class MockCustomerCharts {
  static const mockBadge = 'נתוני הדגמה';

  static const monthlySpending = [
    ChartDataPoint(label: 'דצמ׳', value: 12400),
    ChartDataPoint(label: 'נוב׳', value: 9800),
    ChartDataPoint(label: 'אוק׳', value: 15200),
    ChartDataPoint(label: 'ספט׳', value: 11300),
    ChartDataPoint(label: 'אוג׳', value: 8700),
    ChartDataPoint(label: 'יולי', value: 10200),
  ];

  static const requestsPerWeek = [
    ChartDataPoint(label: 'א׳', value: 2),
    ChartDataPoint(label: 'ב׳', value: 4),
    ChartDataPoint(label: 'ג׳', value: 1),
    ChartDataPoint(label: 'ד׳', value: 5),
    ChartDataPoint(label: 'ה׳', value: 3),
    ChartDataPoint(label: 'ו׳', value: 2),
    ChartDataPoint(label: 'ש׳', value: 0),
  ];

  static const quoteComparison = [
    ChartDataPoint(label: 'ספק א׳', value: 23400),
    ChartDataPoint(label: 'ספק ב׳', value: 25800),
    ChartDataPoint(label: 'ספק ג׳', value: 24100),
  ];

  static const ordersByStatus = [
    StatusSlice(label: 'פעילות', value: 5, color: AppTheme.navy),
    StatusSlice(label: 'הוזמנה', value: 3, color: AppTheme.teal),
    StatusSlice(label: 'נשלחה', value: 2, color: AppTheme.emerald),
    StatusSlice(label: 'הושלמה', value: 4, color: AppTheme.navyLight),
  ];
}

class MockSupplierCharts {
  static const mockBadge = 'נתוני הדגמה';

  static const monthlyRevenue = [
    ChartDataPoint(label: 'דצמ׳', value: 45200),
    ChartDataPoint(label: 'נוב׳', value: 38100),
    ChartDataPoint(label: 'אוק׳', value: 52800),
    ChartDataPoint(label: 'ספט׳', value: 41500),
    ChartDataPoint(label: 'אוג׳', value: 36200),
    ChartDataPoint(label: 'יולי', value: 39800),
  ];

  static const sentQuotesPerWeek = [
    ChartDataPoint(label: 'א׳', value: 3),
    ChartDataPoint(label: 'ב׳', value: 5),
    ChartDataPoint(label: 'ג׳', value: 2),
    ChartDataPoint(label: 'ד׳', value: 7),
    ChartDataPoint(label: 'ה׳', value: 4),
    ChartDataPoint(label: 'ו׳', value: 6),
    ChartDataPoint(label: 'ש׳', value: 1),
  ];

  static const winRate = [
    StatusSlice(label: 'זכיות', value: 38, color: AppTheme.emerald),
    StatusSlice(label: 'הפסדים', value: 62, color: AppTheme.borderColor),
  ];

  static const ordersByStatus = [
    StatusSlice(label: 'לביצוע', value: 4, color: AppTheme.amber),
    StatusSlice(label: 'נשלחו', value: 9, color: AppTheme.teal),
    StatusSlice(label: 'נדחו', value: 2, color: AppTheme.navyLight),
    StatusSlice(label: 'ממתין', value: 3, color: AppTheme.navy),
  ];
}
