import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/appointment.dart';
import '../domain/appointment_repository.dart';
import '../domain/customer.dart';

class SupabaseAppointmentRepository implements AppointmentRepository {
  SupabaseAppointmentRepository(this._client, this.businessId, this.userId);

  final SupabaseClient _client;
  final String businessId;
  final String userId;

  @override
  Future<List<Appointment>> getAppointments({
    required DateTime from,
    required DateTime to,
    String? professionalId,
  }) async {
    var query = _client
        .from('appointments')
        .select()
        .eq('business_id', businessId)
        .lt('starts_at', to.toUtc().toIso8601String())
        .gt('ends_at', from.toUtc().toIso8601String());

    if (professionalId != null) {
      query = query.eq('professional_id', professionalId);
    }

    final rows = await query.order('starts_at');
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<void> saveAppointment(Appointment appointment) async {
    await _client.from('appointments').upsert(_toRow(appointment));
  }

  @override
  Future<void> updateStatus(String id, AppointmentStatus status) async {
    await _client
        .from('appointments')
        .update({
          'status': status.name,
          'cancelled_at': status == AppointmentStatus.cancelled
              ? DateTime.now().toUtc().toIso8601String()
              : null,
        })
        .eq('business_id', businessId)
        .eq('id', id);
  }

  Map<String, Object?> _toRow(Appointment appointment) => {
    'id': appointment.id,
    'business_id': businessId,
    'professional_id': appointment.professionalId,
    'service_id': appointment.serviceId,
    'customer_id': appointment.customerId,
    'customer_name': appointment.customerName,
    'customer_email': appointment.customerEmail,
    'customer_phone': appointment.customerPhone,
    'starts_at': appointment.startsAt.toUtc().toIso8601String(),
    'ends_at': appointment.endsAt.toUtc().toIso8601String(),
    'status': appointment.status.name,
    'source': appointment.source.name,
    'loyalty_tier_applied': appointment.loyaltyTierApplied.storageName,
    'service_base_price': appointment.serviceBasePrice,
    'discount_percent_applied': appointment.discountPercentApplied,
    'discount_amount': appointment.discountAmount,
    'service_final_price': appointment.serviceFinalPrice,
    'pricing_locked_at': appointment.pricingLockedAt?.toUtc().toIso8601String(),
    'notes': appointment.notes,
    'created_by': userId,
    'cancelled_at': appointment.cancelledAt?.toUtc().toIso8601String(),
  };

  Appointment _fromRow(Map<String, dynamic> row) => Appointment(
    id: row['id'] as String,
    businessId: row['business_id'] as String,
    professionalId: row['professional_id'] as String,
    serviceId: row['service_id'] as String,
    customerId: row['customer_id'] as String?,
    customerName: row['customer_name'] as String,
    customerEmail: row['customer_email'] as String? ?? '',
    customerPhone: row['customer_phone'] as String? ?? '',
    startsAt: DateTime.parse(row['starts_at'] as String).toLocal(),
    endsAt: DateTime.parse(row['ends_at'] as String).toLocal(),
    status: AppointmentStatus.values.byName(row['status'] as String),
    source: AppointmentSource.values.byName(row['source'] as String),
    loyaltyTierApplied: CustomerLoyaltyTierStorage.fromStorage(
      row['loyalty_tier_applied'] as String?,
    ),
    serviceBasePrice: (row['service_base_price'] as num?)?.toDouble() ?? 0,
    discountPercentApplied:
        (row['discount_percent_applied'] as num?)?.toDouble() ?? 0,
    discountAmount: (row['discount_amount'] as num?)?.toDouble() ?? 0,
    serviceFinalPrice: (row['service_final_price'] as num?)?.toDouble() ?? 0,
    pricingLockedAt: DateTime.tryParse(
      row['pricing_locked_at'] as String? ?? '',
    )?.toLocal(),
    notes: row['notes'] as String? ?? '',
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    cancelledAt: DateTime.tryParse(row['cancelled_at'] as String? ?? '')
        ?.toLocal(),
    updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '')?.toLocal(),
  );
}
