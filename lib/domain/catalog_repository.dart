import 'catalog.dart';

abstract interface class CatalogRepository {
  Future<List<Professional>> getProfessionals();
  Future<List<BeautyService>> getServices();
  Future<void> saveProfessional(Professional professional);
  Future<void> configureProfessionalLogin({
    required String professionalId,
    required String loginName,
    required String password,
  });
  Future<void> saveService(BeautyService service);
  Future<void> setProfessionalActive(String id, bool active);
  Future<void> setServiceActive(String id, bool active);
}
