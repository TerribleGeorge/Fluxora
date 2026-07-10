import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/customer.dart';
import '../domain/sale.dart';
import '../domain/sales_repository.dart';

class SupabaseSalesRepository implements SalesRepository {
  SupabaseSalesRepository(this._client, this.businessId);

  final SupabaseClient _client;
  final String businessId;

  @override
  Future<List<Sale>> getSales() async {
    final rows = await _client
        .from('sales')
        .select()
        .eq('business_id', businessId)
        .order('occurred_at', ascending: false);
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<void> saveSale(Sale sale) async {
    await _client.from('sales').upsert({
      'id': sale.id,
      'business_id': businessId,
      'professional_id': sale.professionalId,
      'appointment_id': sale.appointmentId,
      'customer_id': sale.customerId,
      'items': sale.items.map((item) => item.toJson()).toList(),
      'payment': sale.payment.toJson(),
      'gross_total': sale.grossTotal,
      'fee_amount': sale.payment.feeAmount,
      'occurred_at': sale.occurredAt.toUtc().toIso8601String(),
      'created_by': sale.createdBy,
      'customer_name': sale.customerName,
      'notes': sale.notes,
      'status': sale.status.name,
      'loyalty_tier_applied': sale.loyaltyTierApplied.storageName,
      'service_gross_total': sale.serviceGrossTotal,
      'service_discount_total': sale.serviceDiscountTotal,
      'product_gross_total': sale.productGrossTotal,
      'product_cost_total': sale.productCostTotal,
      'estimated_profit': sale.estimatedProfit,
    });
  }

  @override
  Future<void> setSaleStatus(String id, SaleStatus status) async {
    await _client
        .from('sales')
        .update({'status': status.name})
        .eq('business_id', businessId)
        .eq('id', id);
  }

  Sale _fromRow(Map<String, dynamic> row) {
    final itemsJson = row['items'] is String
        ? jsonDecode(row['items'] as String)
        : row['items'];
    final paymentJson = row['payment'] is String
        ? jsonDecode(row['payment'] as String)
        : row['payment'];
    return Sale(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      professionalId: row['professional_id'] as String,
      items: (itemsJson as List<dynamic>)
          .map((item) => SaleItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      payment: SalePayment.fromJson(paymentJson as Map<String, dynamic>),
      occurredAt: DateTime.parse(row['occurred_at'] as String).toLocal(),
      createdBy: row['created_by'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      appointmentId: row['appointment_id'] as String?,
      customerId: row['customer_id'] as String?,
      customerName: row['customer_name'] as String? ?? '',
      notes: row['notes'] as String? ?? '',
      status: SaleStatus.values.byName(row['status'] as String),
      loyaltyTierApplied: CustomerLoyaltyTierStorage.fromStorage(
        row['loyalty_tier_applied'] as String?,
      ),
      serviceGrossTotal: (row['service_gross_total'] as num?)?.toDouble() ?? 0,
      serviceDiscountTotal:
          (row['service_discount_total'] as num?)?.toDouble() ?? 0,
      productGrossTotal: (row['product_gross_total'] as num?)?.toDouble() ?? 0,
      productCostTotal: (row['product_cost_total'] as num?)?.toDouble() ?? 0,
      estimatedProfit: (row['estimated_profit'] as num?)?.toDouble() ?? 0,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
