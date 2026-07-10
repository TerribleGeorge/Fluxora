import 'product.dart';

abstract interface class ProductRepository {
  Future<List<ProductTemplate>> getTemplates();
  Future<List<Product>> getProducts();
  Future<List<Product>> getSellableProducts();
  Future<void> saveProduct(Product product);
}
