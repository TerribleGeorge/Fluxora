enum TransactionType { income, expense }

enum FinancialEntryKind {
  otherIncome,
  operatingExpense,
  tax,
  ownerWithdrawal,
  otherExpense,
}

enum EntryPaymentSource { cash, bank, other }

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    required this.type,
    this.notes = '',
    this.businessId = '',
    this.createdBy = '',
    this.updatedAt,
    this.deletedAt,
    this.kind,
    this.paymentSource = EntryPaymentSource.bank,
  });

  final String id;
  final String description;
  final double amount;
  final String category;
  final DateTime date;
  final TransactionType type;
  final String notes;
  final String businessId;
  final String createdBy;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final FinancialEntryKind? kind;
  final EntryPaymentSource paymentSource;

  bool get deleted => deletedAt != null;

  Map<String, Object> toJson() => {
    'id': id,
    'description': description,
    'amount': amount,
    'category': category,
    'date': date.toIso8601String(),
    'type': type.name,
    'notes': notes,
    'businessId': businessId,
    'createdBy': createdBy,
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    'kind': (kind ?? _defaultKind(type)).name,
    'paymentSource': paymentSource.name,
  };

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) {
    final amount = (json['amount'] as num?)?.toDouble();
    final date = DateTime.tryParse(json['date'] as String? ?? '');
    if (json['id'] is! String ||
        json['description'] is! String ||
        amount == null ||
        amount <= 0 ||
        date == null) {
      throw const FormatException('Lançamento inválido.');
    }
    return FinanceTransaction(
      id: json['id'] as String,
      description: json['description'] as String,
      amount: amount,
      category: json['category'] as String? ?? 'Outros',
      date: date,
      type: TransactionType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => TransactionType.expense,
      ),
      notes: json['notes'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? ''),
      kind: FinancialEntryKind.values
          .where((item) => item.name == json['kind'])
          .firstOrNull,
      paymentSource:
          EntryPaymentSource.values
              .where((item) => item.name == json['paymentSource'])
              .firstOrNull ??
          EntryPaymentSource.bank,
    );
  }

  static FinancialEntryKind _defaultKind(TransactionType type) =>
      type == TransactionType.income
      ? FinancialEntryKind.otherIncome
      : FinancialEntryKind.operatingExpense;
}
