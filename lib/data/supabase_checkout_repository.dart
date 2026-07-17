import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/checkout_repository.dart';
import '../domain/product.dart';
import '../domain/sale.dart';

class SupabaseCheckoutRepository implements CheckoutRepository {
  SupabaseCheckoutRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Sale> completeAppointmentCheckout({
    required String appointmentId,
    required PaymentMethod paymentMethod,
    double paymentFeePercent = 0,
    List<CheckoutProductLine> products = const [],
    String notes = '',
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'complete_appointment_checkout',
      params: {
        'target_appointment_id': appointmentId,
        'payment_method': paymentMethod.name,
        'payment_fee_percent': paymentFeePercent,
        'product_lines': products.map((item) => item.toJson()).toList(),
        'checkout_notes': notes,
      },
    );
    final items = row['items'];
    final payment = row['payment'];
    return Sale.fromJson({
      'id': row['id'],
      'businessId': row['business_id'],
      'professionalId': row['professional_id'],
      'appointmentId': row['appointment_id'],
      'customerId': row['customer_id'],
      'items': items,
      'payment': payment,
      'occurredAt': row['occurred_at'],
      'createdBy': row['created_by'],
      'createdAt': row['created_at'],
      'customerName': row['customer_name'],
      'notes': row['notes'],
      'status': row['status'],
      'loyaltyTierApplied': row['loyalty_tier_applied'],
      'serviceGrossTotal': row['service_gross_total'],
      'serviceDiscountTotal': row['service_discount_total'],
      'productGrossTotal': row['product_gross_total'],
      'productCostTotal': row['product_cost_total'],
      'estimatedProfit': row['estimated_profit'],
      'updatedAt': row['updated_at'],
    });
  }
}
