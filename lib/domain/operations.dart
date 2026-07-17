import 'sale.dart';

enum CashSessionStatus { open, closed }

class CommissionPayout {
  const CommissionPayout({
    required this.id,
    required this.businessId,
    required this.professionalId,
    required this.amount,
    required this.periodStart,
    required this.periodEnd,
    required this.paidAt,
    required this.method,
    required this.createdBy,
    this.notes = '',
  });

  final String id;
  final String businessId;
  final String professionalId;
  final double amount;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime paidAt;
  final PaymentMethod method;
  final String createdBy;
  final String notes;

  Map<String, Object> toJson() => {
    'id': id,
    'businessId': businessId,
    'professionalId': professionalId,
    'amount': amount,
    'periodStart': periodStart.toIso8601String(),
    'periodEnd': periodEnd.toIso8601String(),
    'paidAt': paidAt.toIso8601String(),
    'method': method.name,
    'createdBy': createdBy,
    'notes': notes,
  };

  factory CommissionPayout.fromJson(Map<String, dynamic> json) =>
      CommissionPayout(
        id: json['id'] as String,
        businessId: json['businessId'] as String,
        professionalId: json['professionalId'] as String,
        amount: (json['amount'] as num).toDouble(),
        periodStart: DateTime.parse(json['periodStart'] as String),
        periodEnd: DateTime.parse(json['periodEnd'] as String),
        paidAt: DateTime.parse(json['paidAt'] as String),
        method: PaymentMethod.values.byName(json['method'] as String),
        createdBy: json['createdBy'] as String,
        notes: json['notes'] as String? ?? '',
      );
}

class CashSession {
  const CashSession({
    required this.id,
    required this.businessId,
    required this.openingBalance,
    required this.openedAt,
    required this.openedBy,
    this.status = CashSessionStatus.open,
    this.closedAt,
    this.closedBy,
    this.expectedClosing,
    this.countedClosing,
    this.notes = '',
  });

  final String id;
  final String businessId;
  final double openingBalance;
  final DateTime openedAt;
  final String openedBy;
  final CashSessionStatus status;
  final DateTime? closedAt;
  final String? closedBy;
  final double? expectedClosing;
  final double? countedClosing;
  final String notes;

  double? get difference => expectedClosing == null || countedClosing == null
      ? null
      : countedClosing! - expectedClosing!;

  CashSession close({
    required String userId,
    required double expected,
    required double counted,
    String notes = '',
  }) => CashSession(
    id: id,
    businessId: businessId,
    openingBalance: openingBalance,
    openedAt: openedAt,
    openedBy: openedBy,
    status: CashSessionStatus.closed,
    closedAt: DateTime.now(),
    closedBy: userId,
    expectedClosing: expected,
    countedClosing: counted,
    notes: notes,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'businessId': businessId,
    'openingBalance': openingBalance,
    'openedAt': openedAt.toIso8601String(),
    'openedBy': openedBy,
    'status': status.name,
    'closedAt': closedAt?.toIso8601String(),
    'closedBy': closedBy,
    'expectedClosing': expectedClosing,
    'countedClosing': countedClosing,
    'notes': notes,
  };

  factory CashSession.fromJson(Map<String, dynamic> json) => CashSession(
    id: json['id'] as String,
    businessId: json['businessId'] as String,
    openingBalance: (json['openingBalance'] as num).toDouble(),
    openedAt: DateTime.parse(json['openedAt'] as String),
    openedBy: json['openedBy'] as String,
    status: CashSessionStatus.values.byName(json['status'] as String),
    closedAt: DateTime.tryParse(json['closedAt'] as String? ?? ''),
    closedBy: json['closedBy'] as String?,
    expectedClosing: (json['expectedClosing'] as num?)?.toDouble(),
    countedClosing: (json['countedClosing'] as num?)?.toDouble(),
    notes: json['notes'] as String? ?? '',
  );
}
