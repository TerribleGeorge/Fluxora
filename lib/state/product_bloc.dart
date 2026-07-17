import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/account.dart';
import '../domain/id_generator.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';
import 'product_event.dart';
import 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  ProductBloc(
    this._repository, {
    required this.businessId,
    required this.businessType,
  }) : super(const ProductState()) {
    on<ProductStarted>(_onStarted);
    on<ProductSaved>(_onProductSaved);
    on<ProductActiveChanged>(_onProductActiveChanged);
  }

  final ProductRepository _repository;
  final String businessId;
  final BusinessType businessType;

  Future<void> _onStarted(
    ProductStarted event,
    Emitter<ProductState> emit,
  ) async {
    emit(state.copyWith(status: ProductStatus.loading));
    await _reload(emit);
  }

  Future<void> _onProductSaved(
    ProductSaved event,
    Emitter<ProductState> emit,
  ) async {
    if (event.name.trim().length < 2 ||
        event.salePrice < 0 ||
        event.unitCost < 0 ||
        event.stockQuantity < 0 ||
        event.minStockQuantity < 0) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Revise nome, preço, custo e estoque do produto.',
        ),
      );
      return;
    }
    final existing = state.products
        .where((item) => item.id == event.id)
        .firstOrNull;
    final product = Product(
      id: existing?.id ?? createUuid(),
      businessId: businessId,
      businessType: businessType,
      name: event.name.trim(),
      category: event.category.trim().isEmpty
          ? 'Produtos'
          : event.category.trim(),
      salePrice: event.salePrice,
      unitCost: event.unitCost,
      stockQuantity: event.stockQuantity,
      minStockQuantity: event.minStockQuantity,
      active: event.active,
      updatedAt: DateTime.now(),
    );
    await _save(emit, product, success: 'Produto salvo.');
  }

  Future<void> _onProductActiveChanged(
    ProductActiveChanged event,
    Emitter<ProductState> emit,
  ) async {
    await _save(
      emit,
      event.product.copyWith(active: event.active),
      success: event.active ? 'Produto ativado.' : 'Produto pausado.',
    );
  }

  Future<void> _save(
    Emitter<ProductState> emit,
    Product product, {
    required String success,
  }) async {
    try {
      await _repository.saveProduct(product);
      await _reload(emit, message: success);
    } on Exception {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Não foi possível salvar o produto.',
        ),
      );
    }
  }

  Future<void> _reload(Emitter<ProductState> emit, {String? message}) async {
    try {
      final results = await Future.wait([
        _repository.getTemplates(),
        _repository.getProducts(),
      ]);
      emit(
        ProductState(
          status: ProductStatus.success,
          templates: results[0] as List<ProductTemplate>,
          products: results[1] as List<Product>,
          message: message,
        ),
      );
    } on Exception {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Não foi possível carregar produtos.',
        ),
      );
    }
  }
}
