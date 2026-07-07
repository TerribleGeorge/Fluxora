import 'catalog.dart';
import 'sale.dart';
import 'transaction.dart';

class MetricBreakdown {
  const MetricBreakdown(this.label, this.amount, {this.count = 0});
  final String label;
  final double amount;
  final int count;
}

class BusinessMetrics {
  const BusinessMetrics({
    required this.periodStart,
    required this.periodEnd,
    required this.grossRevenue,
    required this.cardFees,
    required this.commissions,
    required this.operatingExpenses,
    required this.taxes,
    required this.otherIncome,
    required this.ownerWithdrawals,
    required this.completedSales,
    required this.cancelledSales,
    required this.byProfessional,
    required this.byService,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final double grossRevenue;
  final double cardFees;
  final double commissions;
  final double operatingExpenses;
  final double taxes;
  final double otherIncome;
  final double ownerWithdrawals;
  final int completedSales;
  final int cancelledSales;
  final List<MetricBreakdown> byProfessional;
  final List<MetricBreakdown> byService;

  double get netRevenue => grossRevenue - cardFees;
  double get profitBeforeWithdrawal =>
      netRevenue + otherIncome - commissions - operatingExpenses - taxes;
  double get availableAfterWithdrawals =>
      profitBeforeWithdrawal - ownerWithdrawals;
  double get marginPercent =>
      grossRevenue == 0 ? 0 : profitBeforeWithdrawal / grossRevenue * 100;
  double get averageTicket =>
      completedSales == 0 ? 0 : grossRevenue / completedSales;

  factory BusinessMetrics.calculate({
    required DateTime start,
    required DateTime end,
    required List<Sale> sales,
    required List<FinanceTransaction> transactions,
    required List<Professional> professionals,
    required List<BeautyService> services,
  }) {
    bool inPeriod(DateTime date) => !date.isBefore(start) && date.isBefore(end);
    final completed = sales
        .where(
          (sale) =>
              sale.status == SaleStatus.completed && inPeriod(sale.occurredAt),
        )
        .toList();
    final cancelled = sales.where(
      (sale) =>
          sale.status == SaleStatus.cancelled && inPeriod(sale.occurredAt),
    );
    final periodTransactions = transactions.where(
      (item) => inPeriod(item.date),
    );
    double sumKind(FinancialEntryKind kind) => periodTransactions
        .where((item) => item.kind == kind)
        .fold(0, (sum, item) => sum + item.amount);

    final professionalNames = {
      for (final item in professionals) item.id: item.name,
    };
    final serviceNames = {for (final item in services) item.id: item.name};
    final professionalTotals = <String, (double, int)>{};
    final serviceTotals = <String, (double, int)>{};
    for (final sale in completed) {
      final current = professionalTotals[sale.professionalId] ?? (0.0, 0);
      professionalTotals[sale.professionalId] = (
        current.$1 + sale.grossTotal,
        current.$2 + 1,
      );
      for (final item in sale.items.where(
        (item) => item.type == SaleItemType.service,
      )) {
        final key = item.serviceId ?? item.description;
        final serviceCurrent = serviceTotals[key] ?? (0.0, 0);
        serviceTotals[key] = (
          serviceCurrent.$1 + item.total,
          serviceCurrent.$2 + item.quantity,
        );
      }
    }

    List<MetricBreakdown> breakdown(
      Map<String, (double, int)> totals,
      Map<String, String> names,
    ) {
      final result = totals.entries
          .map(
            (entry) => MetricBreakdown(
              names[entry.key] ?? entry.key,
              entry.value.$1,
              count: entry.value.$2,
            ),
          )
          .toList();
      result.sort((a, b) => b.amount.compareTo(a.amount));
      return result;
    }

    return BusinessMetrics(
      periodStart: start,
      periodEnd: end,
      grossRevenue: completed.fold(0, (sum, sale) => sum + sale.grossTotal),
      cardFees: completed.fold(0, (sum, sale) => sum + sale.payment.feeAmount),
      commissions: completed.fold(0, (sum, sale) => sum + sale.commissionTotal),
      operatingExpenses:
          sumKind(FinancialEntryKind.operatingExpense) +
          sumKind(FinancialEntryKind.otherExpense),
      taxes: sumKind(FinancialEntryKind.tax),
      otherIncome: sumKind(FinancialEntryKind.otherIncome),
      ownerWithdrawals: sumKind(FinancialEntryKind.ownerWithdrawal),
      completedSales: completed.length,
      cancelledSales: cancelled.length,
      byProfessional: breakdown(professionalTotals, professionalNames),
      byService: breakdown(serviceTotals, serviceNames),
    );
  }
}
