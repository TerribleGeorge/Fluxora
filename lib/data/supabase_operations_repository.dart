import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/operations.dart';
import '../domain/operations_repository.dart';
import '../domain/sale.dart';

class SupabaseOperationsRepository implements OperationsRepository {
  SupabaseOperationsRepository(this._client, this.businessId);
  final SupabaseClient _client;
  final String businessId;

  @override
  Future<List<CommissionPayout>> getPayouts() async {
    final rows = await _client
        .from('commission_payouts')
        .select()
        .eq('business_id', businessId)
        .order('paid_at', ascending: false);
    return rows
        .map(
          (row) => CommissionPayout(
            id: row['id'] as String,
            businessId: row['business_id'] as String,
            professionalId: row['professional_id'] as String,
            amount: (row['amount'] as num).toDouble(),
            periodStart: DateTime.parse(row['period_start'] as String),
            periodEnd: DateTime.parse(row['period_end'] as String),
            paidAt: DateTime.parse(row['paid_at'] as String).toLocal(),
            method: PaymentMethod.values.byName(row['method'] as String),
            createdBy: row['created_by'] as String,
            notes: row['notes'] as String? ?? '',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<CashSession>> getCashSessions() async {
    final rows = await _client
        .from('cash_sessions')
        .select()
        .eq('business_id', businessId)
        .order('opened_at', ascending: false);
    return rows
        .map(
          (row) => CashSession(
            id: row['id'] as String,
            businessId: row['business_id'] as String,
            openingBalance: (row['opening_balance'] as num).toDouble(),
            openedAt: DateTime.parse(row['opened_at'] as String).toLocal(),
            openedBy: row['opened_by'] as String,
            status: CashSessionStatus.values.byName(row['status'] as String),
            closedAt: DateTime.tryParse(
              row['closed_at'] as String? ?? '',
            )?.toLocal(),
            closedBy: row['closed_by'] as String?,
            expectedClosing: (row['expected_closing'] as num?)?.toDouble(),
            countedClosing: (row['counted_closing'] as num?)?.toDouble(),
            notes: row['notes'] as String? ?? '',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> savePayout(CommissionPayout payout) async {
    await _client.from('commission_payouts').upsert({
      'id': payout.id,
      'business_id': businessId,
      'professional_id': payout.professionalId,
      'amount': payout.amount,
      'period_start': payout.periodStart.toUtc().toIso8601String(),
      'period_end': payout.periodEnd.toUtc().toIso8601String(),
      'paid_at': payout.paidAt.toUtc().toIso8601String(),
      'method': payout.method.name,
      'created_by': payout.createdBy,
      'notes': payout.notes,
    });
  }

  @override
  Future<void> saveCashSession(CashSession session) async {
    await _client.from('cash_sessions').upsert({
      'id': session.id,
      'business_id': businessId,
      'opening_balance': session.openingBalance,
      'opened_at': session.openedAt.toUtc().toIso8601String(),
      'opened_by': session.openedBy,
      'status': session.status.name,
      'closed_at': session.closedAt?.toUtc().toIso8601String(),
      'closed_by': session.closedBy,
      'expected_closing': session.expectedClosing,
      'counted_closing': session.countedClosing,
      'notes': session.notes,
    });
  }
}
