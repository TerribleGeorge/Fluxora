import '../domain/catalog.dart';

enum CatalogStatus { initial, loading, success, failure }

class CatalogState {
  const CatalogState({
    this.status = CatalogStatus.initial,
    this.professionals = const [],
    this.services = const [],
    this.message,
  });

  final CatalogStatus status;
  final List<Professional> professionals;
  final List<BeautyService> services;
  final String? message;

  bool get loading => status == CatalogStatus.loading;
}
