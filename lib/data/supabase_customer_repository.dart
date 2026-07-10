import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/customer.dart';
import '../domain/customer_repository.dart';

class SupabaseCustomerRepository implements CustomerRepository {
  SupabaseCustomerRepository(this._client, this.businessId);

  final SupabaseClient _client;
  final String businessId;

  @override
  Future<LoyaltySettings> getLoyaltySettings() async {
    final row = await _client
        .from('business_loyalty_settings')
        .select()
        .eq('business_id', businessId)
        .maybeSingle();
    if (row == null) return LoyaltySettings(businessId: businessId);
    return LoyaltySettings(
      businessId: row['business_id'] as String,
      enabled: row['enabled'] as bool? ?? false,
      standardDiscountPercent:
          (row['standard_discount_percent'] as num?)?.toDouble() ?? 0,
      goldDiscountPercent:
          (row['gold_discount_percent'] as num?)?.toDouble() ?? 0,
      premiumDiscountPercent:
          (row['premium_discount_percent'] as num?)?.toDouble() ?? 0,
      inactiveAfterDays: row['inactive_after_days'] as int? ?? 90,
    );
  }

  @override
  Future<void> saveLoyaltySettings(LoyaltySettings settings) async {
    await _client.from('business_loyalty_settings').upsert({
      'business_id': businessId,
      'enabled': settings.enabled,
      'standard_discount_percent': settings.standardDiscountPercent,
      'gold_discount_percent': settings.goldDiscountPercent,
      'premium_discount_percent': settings.premiumDiscountPercent,
      'inactive_after_days': settings.inactiveAfterDays,
    });
  }

  @override
  Future<List<Customer>> getCustomers() async {
    final rows = await _client
        .from('customers')
        .select()
        .eq('business_id', businessId)
        .isFilter('deleted_at', null)
        .order('name');
    return rows.map(_customerFromRow).toList(growable: false);
  }

  @override
  Future<void> saveCustomer(Customer customer) async {
    await _client.from('customers').upsert({
      'id': customer.id,
      'business_id': businessId,
      'name': customer.name,
      'normalized_name': customer.name.trim().toLowerCase(),
      'email': customer.email,
      'normalized_email': customer.email.trim().toLowerCase(),
      'phone': customer.phone,
      'normalized_phone': customer.phone.replaceAll(RegExp(r'[^0-9]'), ''),
      'loyalty_tier': customer.loyaltyTier.storageName,
      'manual_tier_override': customer.manualTierOverride?.storageName,
      'manual_tier_reason': customer.manualTierReason,
      'relationship_started_at': customer.relationshipStartedAt
          ?.toUtc()
          .toIso8601String(),
      'last_completed_at': customer.lastCompletedAt?.toUtc().toIso8601String(),
      'completed_visits_count': customer.completedVisitsCount,
    });
  }

  @override
  Future<BookingPriceQuote> resolveBookingPrice({
    required String serviceId,
    required String name,
    required String email,
    required String phone,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'resolve_booking_price',
      params: {
        'target_business_id': businessId,
        'target_service_id': serviceId,
        'raw_name': name,
        'raw_email': email,
        'raw_phone': phone,
      },
    );
    return BookingPriceQuote(
      customerId: row['customer_id'] as String,
      tier: CustomerLoyaltyTierStorage.fromStorage(
        row['loyalty_tier'] as String?,
      ),
      basePrice: (row['base_price'] as num).toDouble(),
      discountPercent: (row['discount_percent'] as num).toDouble(),
      discountAmount: (row['discount_amount'] as num).toDouble(),
      finalPrice: (row['final_price'] as num).toDouble(),
    );
  }

  @override
  Future<void> linkAppointmentToCustomer({
    required String appointmentId,
    required String customerId,
  }) async {
    await _client.rpc<void>(
      'link_appointment_to_customer',
      params: {
        'target_appointment_id': appointmentId,
        'target_customer_id': customerId,
      },
    );
  }

  Customer _customerFromRow(Map<String, dynamic> row) => Customer(
    id: row['id'] as String,
    businessId: row['business_id'] as String,
    name: row['name'] as String,
    email: row['email'] as String? ?? '',
    phone: row['phone'] as String? ?? '',
    loyaltyTier: CustomerLoyaltyTierStorage.fromStorage(
      row['loyalty_tier'] as String?,
    ),
    manualTierOverride: row['manual_tier_override'] == null
        ? null
        : CustomerLoyaltyTierStorage.fromStorage(
            row['manual_tier_override'] as String?,
          ),
    manualTierReason: row['manual_tier_reason'] as String? ?? '',
    relationshipStartedAt:
        DateTime.tryParse(row['relationship_started_at'] as String? ?? '')
            ?.toLocal(),
    lastCompletedAt:
        DateTime.tryParse(row['last_completed_at'] as String? ?? '')
            ?.toLocal(),
    completedVisitsCount: row['completed_visits_count'] as int? ?? 0,
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '')?.toLocal(),
  );
}
