import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/finance_repository.dart';
import '../domain/transaction.dart';

class SupabaseFinanceRepository implements FinanceRepository {
  SupabaseFinanceRepository({
    required SupabaseClient client,
    required this.businessId,
    required this.userId,
  }) : _client = client;

  final SupabaseClient _client;
  final String businessId;
  final String userId;

  @override
  Future<List<FinanceTransaction>> getTransactions() async {
    final rows = await _client
        .from('finance_transactions')
        .select()
        .eq('business_id', businessId)
        .order('occurred_at', ascending: false);
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<void> saveTransaction(FinanceTransaction transaction) async {
    await _client.from('finance_transactions').upsert(_toRow(transaction));
  }

  @override
  Future<void> replaceTransaction(FinanceTransaction transaction) async {
    await _client.from('finance_transactions').upsert(_toRow(transaction));
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _client
        .from('finance_transactions')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('business_id', businessId)
        .eq('id', id);
  }

  Map<String, Object?> _toRow(FinanceTransaction transaction) => {
    'id': transaction.id,
    'business_id': businessId,
    'description': transaction.description,
    'amount': transaction.amount,
    'category': transaction.category,
    'occurred_at': transaction.date.toUtc().toIso8601String(),
    'type': transaction.type.name,
    'entry_kind':
        (transaction.kind ?? FinancialEntryKind.operatingExpense).name,
    'payment_source': transaction.paymentSource.name,
    'notes': transaction.notes,
    'created_by': transaction.createdBy.isEmpty
        ? userId
        : transaction.createdBy,
    'deleted_at': transaction.deletedAt?.toUtc().toIso8601String(),
  };

  FinanceTransaction _fromRow(Map<String, dynamic> row) {
    return FinanceTransaction(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      description: row['description'] as String,
      amount: (row['amount'] as num).toDouble(),
      category: row['category'] as String,
      date: DateTime.parse(row['occurred_at'] as String).toLocal(),
      type: TransactionType.values.byName(row['type'] as String),
      kind: FinancialEntryKind.values.byName(
        row['entry_kind'] as String? ??
            (row['type'] == 'income' ? 'otherIncome' : 'operatingExpense'),
      ),
      paymentSource: EntryPaymentSource.values.byName(
        row['payment_source'] as String? ?? 'bank',
      ),
      notes: row['notes'] as String? ?? '',
      createdBy: row['created_by'] as String,
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
      deletedAt: DateTime.tryParse(row['deleted_at'] as String? ?? ''),
    );
  }
}
