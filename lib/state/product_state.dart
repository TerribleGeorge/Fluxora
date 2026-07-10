import '../domain/product.dart';

enum ProductStatus { initial, loading, success, failure }

class ProductState {
  const ProductState({
    this.status = ProductStatus.initial,
    this.templates = const [],
    this.products = const [],
    this.message,
  });

  final ProductStatus status;
  final List<ProductTemplate> templates;
  final List<Product> products;
  final String? message;

  bool get loading => status == ProductStatus.loading;

  ProductState copyWith({
    ProductStatus? status,
    List<ProductTemplate>? templates,
    List<Product>? products,
    String? message,
  }) => ProductState(
    status: status ?? this.status,
    templates: templates ?? this.templates,
    products: products ?? this.products,
    message: message,
  );
}
