import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/account.dart';
import 'package:fluxora/domain/customer.dart';
import 'package:fluxora/domain/product.dart';
import 'package:fluxora/domain/sale.dart';

void main() {
  test('fidelidade desligada sempre retorna cliente novo e sem desconto', () {
    final customer = Customer(
      id: 'customer-1',
      businessId: 'business-1',
      name: 'Maria',
      relationshipStartedAt: DateTime(2025, 1, 1),
      lastCompletedAt: DateTime(2026, 7, 1),
      createdAt: DateTime(2025, 1, 1),
    );
    final settings = LoyaltySettings(
      businessId: 'business-1',
      enabled: false,
      premiumDiscountPercent: 20,
    );

    final tier = customer.effectiveTier(
      settings: settings,
      now: DateTime(2026, 7, 10),
    );

    expect(tier, CustomerLoyaltyTier.newCustomer);
    expect(settings.discountFor(tier), 0);
  });

  test('cliente recorrente ativo evolui para premium após 12 meses', () {
    final customer = Customer(
      id: 'customer-1',
      businessId: 'business-1',
      name: 'Maria',
      relationshipStartedAt: DateTime(2025, 1, 1),
      lastCompletedAt: DateTime(2026, 7, 1),
      createdAt: DateTime(2025, 1, 1),
    );
    final settings = LoyaltySettings(
      businessId: 'business-1',
      enabled: true,
      premiumDiscountPercent: 15,
    );

    final tier = customer.effectiveTier(
      settings: settings,
      now: DateTime(2026, 7, 10),
    );

    expect(tier, CustomerLoyaltyTier.premium);
    expect(settings.discountFor(tier), 15);
  });

  test('cliente antigo inativo perde benefício automático', () {
    final customer = Customer(
      id: 'customer-1',
      businessId: 'business-1',
      name: 'Maria',
      relationshipStartedAt: DateTime(2025, 1, 1),
      lastCompletedAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2025, 1, 1),
    );
    final settings = LoyaltySettings(
      businessId: 'business-1',
      enabled: true,
      premiumDiscountPercent: 15,
      inactiveAfterDays: 90,
    );

    expect(
      customer.effectiveTier(settings: settings, now: DateTime(2026, 7, 10)),
      CustomerLoyaltyTier.newCustomer,
    );
  });

  test('produto só pode seguir o mesmo nicho do estabelecimento', () {
    expect(
      ProductCatalog.productMatchesBusiness(
        businessType: BusinessType.barbershop,
        productType: BusinessType.barbershop,
      ),
      isTrue,
    );
    expect(
      ProductCatalog.productMatchesBusiness(
        businessType: BusinessType.barbershop,
        productType: BusinessType.nailStudio,
      ),
      isFalse,
    );
  });

  test('lucro real de venda desconta taxa, comissão e custo de produto', () {
    final sale = Sale(
      id: 'sale-1',
      businessId: 'business-1',
      professionalId: 'professional-1',
      items: const [
        SaleItem(
          id: 'service-1',
          type: SaleItemType.service,
          description: 'Corte',
          quantity: 1,
          unitPrice: 90,
          basePrice: 100,
          discountAmount: 10,
          commissionAmount: 36,
          loyaltyTier: CustomerLoyaltyTier.gold,
        ),
        SaleItem(
          id: 'product-1',
          type: SaleItemType.product,
          description: 'Pomada',
          quantity: 2,
          unitPrice: 40,
          unitCost: 15,
        ),
      ],
      payment: const SalePayment(
        method: PaymentMethod.creditCard,
        amount: 170,
        feePercent: 5,
      ),
      occurredAt: DateTime(2026, 7, 10),
      createdBy: 'owner-1',
      createdAt: DateTime(2026, 7, 10),
    );

    expect(sale.grossTotal, 170);
    expect(sale.payment.feeAmount, 8.5);
    expect(sale.productCostFromItems, 30);
    expect(sale.realProfit, 95.5);
  });
}
