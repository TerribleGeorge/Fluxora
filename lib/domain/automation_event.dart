enum AutomationEventStatus { pending, processing, processed, failed }

class AutomationEvent {
  const AutomationEvent({
    required this.id,
    required this.businessId,
    required this.eventType,
    required this.aggregateType,
    required this.aggregateId,
    required this.payload,
    required this.status,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
    this.availableAt,
    this.processedAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String eventType;
  final String aggregateType;
  final String aggregateId;
  final Map<String, Object?> payload;
  final AutomationEventStatus status;
  final int attempts;
  final String? lastError;
  final DateTime? availableAt;
  final DateTime? processedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get done => status == AutomationEventStatus.processed;

  Map<String, Object?> toJson() => {
    'id': id,
    'businessId': businessId,
    'eventType': eventType,
    'aggregateType': aggregateType,
    'aggregateId': aggregateId,
    'payload': payload,
    'status': status.name,
    'attempts': attempts,
    'lastError': lastError,
    'availableAt': availableAt?.toIso8601String(),
    'processedAt': processedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory AutomationEvent.fromJson(Map<String, dynamic> json) {
    return AutomationEvent(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      eventType: json['eventType'] as String,
      aggregateType: json['aggregateType'] as String,
      aggregateId: json['aggregateId'] as String,
      payload: (json['payload'] as Map<dynamic, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key.toString(), value as Object?)),
      status: AutomationEventStatus.values.byName(
        json['status'] as String? ?? AutomationEventStatus.pending.name,
      ),
      attempts: json['attempts'] as int? ?? 0,
      lastError: json['lastError'] as String?,
      availableAt: DateTime.tryParse(json['availableAt'] as String? ?? ''),
      processedAt: DateTime.tryParse(json['processedAt'] as String? ?? ''),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}
