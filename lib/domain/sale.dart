enum SaleItemType { service, product }

enum PaymentMethod { cash, pix, debitCard, creditCard, other }

enum SaleStatus { completed, cancelled }

class SaleItem {
  const SaleItem({
    required this.id,
    required this.type,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.serviceId,
  });

  final String id;
  final SaleItemType type;
  final String description;
  final int quantity;
  final double unitPrice;
  final String? serviceId;

  double get total => quantity * unitPrice;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'description': description,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'serviceId': serviceId,
  };

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
    id: json['id'] as String,
    type: SaleItemType.values.byName(json['type'] as String),
    description: json['description'] as String,
    quantity: json['quantity'] as int,
    unitPrice: (json['unitPrice'] as num).toDouble(),
    serviceId: json['serviceId'] as String?,
  );
}

class SalePayment {
  const SalePayment({
    required this.method,
    required this.amount,
    this.feePercent = 0,
    this.installments = 1,
  });

  final PaymentMethod method;
  final double amount;
  final double feePercent;
  final int installments;

  double get feeAmount => amount * feePercent / 100;
  double get netAmount => amount - feeAmount;

  Map<String, Object> toJson() => {
    'method': method.name,
    'amount': amount,
    'feePercent': feePercent,
    'installments': installments,
  };

  factory SalePayment.fromJson(Map<String, dynamic> json) => SalePayment(
    method: PaymentMethod.values.byName(json['method'] as String),
    amount: (json['amount'] as num).toDouble(),
    feePercent: (json['feePercent'] as num?)?.toDouble() ?? 0,
    installments: json['installments'] as int? ?? 1,
  );
}

class Sale {
  const Sale({
    required this.id,
    required this.businessId,
    required this.professionalId,
    required this.items,
    required this.payment,
    required this.occurredAt,
    required this.createdBy,
    required this.createdAt,
    this.customerName = '',
    this.notes = '',
    this.status = SaleStatus.completed,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String professionalId;
  final List<SaleItem> items;
  final SalePayment payment;
  final DateTime occurredAt;
  final String createdBy;
  final DateTime createdAt;
  final String customerName;
  final String notes;
  final SaleStatus status;
  final DateTime? updatedAt;

  double get grossTotal => items.fold(0, (sum, item) => sum + item.total);
  double get netTotal => grossTotal - payment.feeAmount;

  Sale copyWith({SaleStatus? status}) => Sale(
    id: id,
    businessId: businessId,
    professionalId: professionalId,
    items: items,
    payment: payment,
    occurredAt: occurredAt,
    createdBy: createdBy,
    createdAt: createdAt,
    customerName: customerName,
    notes: notes,
    status: status ?? this.status,
    updatedAt: DateTime.now(),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'businessId': businessId,
    'professionalId': professionalId,
    'items': items.map((item) => item.toJson()).toList(),
    'payment': payment.toJson(),
    'occurredAt': occurredAt.toIso8601String(),
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'customerName': customerName,
    'notes': notes,
    'status': status.name,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
    id: json['id'] as String,
    businessId: json['businessId'] as String,
    professionalId: json['professionalId'] as String,
    items: (json['items'] as List<dynamic>)
        .map((item) => SaleItem.fromJson(item as Map<String, dynamic>))
        .toList(),
    payment: SalePayment.fromJson(json['payment'] as Map<String, dynamic>),
    occurredAt: DateTime.parse(json['occurredAt'] as String),
    createdBy: json['createdBy'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    customerName: json['customerName'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    status: SaleStatus.values.byName(
      json['status'] as String? ?? SaleStatus.completed.name,
    ),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
  );
}
