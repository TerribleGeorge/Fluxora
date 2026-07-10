import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/account.dart';
import 'package:fluxora/domain/customer.dart';
import 'package:fluxora/domain/customer_repository.dart';
import 'package:fluxora/domain/product.dart';
import 'package:fluxora/domain/product_repository.dart';
import 'package:fluxora/state/customer_bloc.dart';
import 'package:fluxora/state/customer_event.dart';
import 'package:fluxora/state/customer_state.dart';
import 'package:fluxora/state/product_bloc.dart';
import 'package:fluxora/state/product_event.dart';
import 'package:fluxora/state/product_state.dart';

void main() {
  test('CustomerBloc salva configuração de fidelidade', () async {
    final repository = _FakeCustomerRepository();
    final bloc = CustomerBloc(repository);

    bloc.add(const CustomerStarted());
    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<CustomerState>(
          (state) => state.status == CustomerStatus.success,
        ),
      ),
    );

    bloc.add(
      const LoyaltySettingsSaved(
        LoyaltySettings(
          businessId: 'business-1',
          enabled: true,
          standardDiscountPercent: 5,
          goldDiscountPercent: 10,
          premiumDiscountPercent: 15,
        ),
      ),
    );
    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<CustomerState>(
          (state) =>
              state.message == 'Configurações de fidelidade salvas.' &&
              state.loyaltySettings?.premiumDiscountPercent == 15,
        ),
      ),
    );

    await bloc.close();
  });

  test('ProductBloc cadastra produto respeitando nicho do negócio', () async {
    final repository = _FakeProductRepository();
    final bloc = ProductBloc(
      repository,
      businessId: 'business-1',
      businessType: BusinessType.barbershop,
    );

    bloc.add(const ProductStarted());
    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<ProductState>(
          (state) =>
              state.status == ProductStatus.success &&
              state.templates.single.name == 'Pomada modeladora',
        ),
      ),
    );

    bloc.add(
      const ProductSaved(
        name: 'Pomada modeladora',
        category: 'Finalizadores',
        salePrice: 39.90,
        unitCost: 18,
        stockQuantity: 10,
        minStockQuantity: 2,
      ),
    );
    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<ProductState>(
          (state) =>
              state.message == 'Produto salvo.' &&
              state.products.single.businessType == BusinessType.barbershop &&
              state.products.single.stockQuantity == 10,
        ),
      ),
    );

    await bloc.close();
  });

  test('ProductBloc rejeita estoque negativo', () async {
    final bloc = ProductBloc(
      _FakeProductRepository(),
      businessId: 'business-1',
      businessType: BusinessType.barbershop,
    );

    bloc.add(
      const ProductSaved(
        name: 'Pomada',
        category: 'Finalizadores',
        salePrice: 39.90,
        unitCost: 18,
        stockQuantity: -1,
        minStockQuantity: 0,
      ),
    );

    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<ProductState>(
          (state) =>
              state.status == ProductStatus.failure &&
              state.message == 'Revise nome, preço, custo e estoque do produto.',
        ),
      ),
    );

    await bloc.close();
  });
}

class _FakeCustomerRepository implements CustomerRepository {
  LoyaltySettings settings = const LoyaltySettings(businessId: 'business-1');

  @override
  Future<List<Customer>> getCustomers() async => const [];

  @override
  Future<LoyaltySettings> getLoyaltySettings() async => settings;

  @override
  Future<void> saveCustomer(Customer customer) async {}

  @override
  Future<void> saveLoyaltySettings(LoyaltySettings settings) async {
    this.settings = settings;
  }

  @override
  Future<BookingPriceQuote> resolveBookingPrice({
    required String serviceId,
    required String name,
    required String email,
    required String phone,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> linkAppointmentToCustomer({
    required String appointmentId,
    required String customerId,
  }) async {}
}

class _FakeProductRepository implements ProductRepository {
  final products = <Product>[];

  @override
  Future<List<Product>> getProducts() async => products;

  @override
  Future<List<Product>> getSellableProducts() async => products;

  @override
  Future<List<ProductTemplate>> getTemplates() async => const [
    ProductTemplate(
      id: 'template-1',
      businessType: BusinessType.barbershop,
      name: 'Pomada modeladora',
      category: 'Finalizadores',
      suggestedSalePrice: 39.90,
    ),
  ];

  @override
  Future<void> saveProduct(Product product) async {
    products.removeWhere((item) => item.id == product.id);
    products.add(product);
  }
}
