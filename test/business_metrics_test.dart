import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/business_metrics.dart';
import 'package:fluxora/domain/catalog.dart';
import 'package:fluxora/domain/sale.dart';
import 'package:fluxora/domain/transaction.dart';

void main() {
  test('calcula lucro real sem tratar retirada como despesa operacional', () {
    final date = DateTime(2026, 7, 10);
    final metrics = BusinessMetrics.calculate(
      start: DateTime(2026, 7),
      end: DateTime(2026, 8),
      professionals: [
        Professional(
          id: 'professional-1',
          businessId: 'business-1',
          name: 'Ana',
          createdAt: date,
        ),
      ],
      services: [
        BeautyService(
          id: 'service-1',
          businessId: 'business-1',
          name: 'Corte',
          price: 100,
          durationMinutes: 30,
          createdAt: date,
        ),
      ],
      sales: [
        Sale(
          id: 'sale-1',
          businessId: 'business-1',
          professionalId: 'professional-1',
          items: const [
            SaleItem(
              id: 'item-1',
              type: SaleItemType.service,
              description: 'Corte',
              quantity: 2,
              unitPrice: 100,
              serviceId: 'service-1',
              commissionAmount: 80,
            ),
          ],
          payment: const SalePayment(
            method: PaymentMethod.creditCard,
            amount: 200,
            feePercent: 5,
          ),
          occurredAt: date,
          createdBy: 'user-1',
          createdAt: date,
        ),
      ],
      transactions: [
        _expense(date, 'rent', 40, FinancialEntryKind.operatingExpense),
        _expense(date, 'tax', 10, FinancialEntryKind.tax),
        _expense(date, 'draw', 20, FinancialEntryKind.ownerWithdrawal),
      ],
    );

    expect(metrics.grossRevenue, 200);
    expect(metrics.cardFees, 10);
    expect(metrics.commissions, 80);
    expect(metrics.profitBeforeWithdrawal, 60);
    expect(metrics.availableAfterWithdrawals, 40);
    expect(metrics.byProfessional.single.label, 'Ana');
    expect(metrics.byService.single.count, 2);
  });

  test('ignora vendas canceladas e dados fora do período', () {
    final metrics = BusinessMetrics.calculate(
      start: DateTime(2026, 7),
      end: DateTime(2026, 8),
      professionals: const [],
      services: const [],
      sales: [
        Sale(
          id: 'cancelled',
          businessId: 'business-1',
          professionalId: 'professional-1',
          items: const [
            SaleItem(
              id: 'item',
              type: SaleItemType.product,
              description: 'Produto',
              quantity: 1,
              unitPrice: 100,
            ),
          ],
          payment: const SalePayment(method: PaymentMethod.pix, amount: 100),
          occurredAt: DateTime(2026, 7, 10),
          createdBy: 'user-1',
          createdAt: DateTime(2026, 7, 10),
          status: SaleStatus.cancelled,
        ),
      ],
      transactions: const [],
    );

    expect(metrics.grossRevenue, 0);
    expect(metrics.cancelledSales, 1);
  });
}

FinanceTransaction _expense(
  DateTime date,
  String id,
  double amount,
  FinancialEntryKind kind,
) => FinanceTransaction(
  id: id,
  description: id,
  amount: amount,
  category: 'Teste',
  date: date,
  type: TransactionType.expense,
  kind: kind,
);
