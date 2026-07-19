import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/catalog.dart';
import '../domain/catalog_repository.dart';
import '../domain/id_generator.dart';
import 'catalog_event.dart';
import 'catalog_state.dart';

class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  CatalogBloc(this._repository, this.businessId) : super(const CatalogState()) {
    on<CatalogStarted>(_onStarted);
    on<ProfessionalSaved>(_onProfessionalSaved);
    on<ProfessionalActiveChanged>(_onProfessionalActiveChanged);
    on<ServiceSaved>(_onServiceSaved);
    on<ServiceActiveChanged>(_onServiceActiveChanged);
  }

  final CatalogRepository _repository;
  final String businessId;

  Future<void> _onStarted(
    CatalogStarted event,
    Emitter<CatalogState> emit,
  ) async {
    emit(
      CatalogState(
        status: CatalogStatus.loading,
        professionals: state.professionals,
        services: state.services,
      ),
    );
    await _reload(emit);
  }

  Future<void> _onProfessionalSaved(
    ProfessionalSaved event,
    Emitter<CatalogState> emit,
  ) async {
    if (event.name.trim().length < 2 ||
        event.commissionPercent < 0 ||
        event.commissionPercent > 100) {
      _failure(emit, 'Revise o nome e o percentual de comissão.');
      return;
    }
    final existing = state.professionals
        .where((item) => item.id == event.id)
        .firstOrNull;
    if (event.enableEmployeeLogin) {
      final needsPassword = existing?.loginEnabled != true;
      if (event.employeeLoginName.trim().length < 2 ||
          (needsPassword && event.employeePassword.length < 8) ||
          (event.employeePassword.isNotEmpty &&
              event.employeePassword.length < 8)) {
        _failure(
          emit,
          'Informe nome de login e senha do funcionário com 8 caracteres.',
        );
        return;
      }
    }
    final now = DateTime.now();
    final professionalId = existing?.id ?? createUuid();
    final professional = Professional(
      id: professionalId,
      businessId: businessId,
      name: event.name.trim(),
      phone: event.phone.trim(),
      email: event.email.trim(),
      defaultCommissionPercent: event.commissionPercent,
      active: existing?.active ?? true,
      userId: event.userId,
      loginEnabled: existing?.loginEnabled ?? false,
      loginName: existing?.loginName ?? '',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _run(emit, () async {
      await _repository.saveProfessional(professional);
      if (event.enableEmployeeLogin) {
        await _repository.configureProfessionalLogin(
          professionalId: professionalId,
          loginName: event.employeeLoginName.trim(),
          password: event.employeePassword,
        );
      }
    });
  }

  Future<void> _onProfessionalActiveChanged(
    ProfessionalActiveChanged event,
    Emitter<CatalogState> emit,
  ) async {
    await _run(
      emit,
      () => _repository.setProfessionalActive(event.id, event.active),
    );
  }

  Future<void> _onServiceSaved(
    ServiceSaved event,
    Emitter<CatalogState> emit,
  ) async {
    final invalidCommission =
        event.commissionValue < 0 ||
        (event.commissionType == ServiceCommissionType.percentage &&
            event.commissionValue > 100);
    if (event.name.trim().length < 2 ||
        event.price <= 0 ||
        event.durationMinutes < 5 ||
        invalidCommission) {
      _failure(emit, 'Revise nome, preço, duração e comissão do serviço.');
      return;
    }
    final existing = state.services
        .where((item) => item.id == event.id)
        .firstOrNull;
    final now = DateTime.now();
    final service = BeautyService(
      id: existing?.id ?? createUuid(),
      businessId: businessId,
      name: event.name.trim(),
      category: event.category.trim().isEmpty
          ? 'Serviços'
          : event.category.trim(),
      price: event.price,
      durationMinutes: event.durationMinutes,
      commissionType: event.commissionType,
      commissionValue:
          event.commissionType == ServiceCommissionType.businessDefault
          ? 0
          : event.commissionValue,
      active: existing?.active ?? true,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _run(emit, () => _repository.saveService(service));
  }

  Future<void> _onServiceActiveChanged(
    ServiceActiveChanged event,
    Emitter<CatalogState> emit,
  ) async {
    await _run(
      emit,
      () => _repository.setServiceActive(event.id, event.active),
    );
  }

  Future<void> _run(
    Emitter<CatalogState> emit,
    Future<void> Function() operation,
  ) async {
    try {
      await operation();
      await _reload(emit);
    } on Exception {
      _failure(emit, 'Não foi possível salvar a alteração.');
    }
  }

  Future<void> _reload(Emitter<CatalogState> emit) async {
    try {
      final results = await Future.wait([
        _repository.getProfessionals(),
        _repository.getServices(),
      ]);
      emit(
        CatalogState(
          status: CatalogStatus.success,
          professionals: results[0] as List<Professional>,
          services: results[1] as List<BeautyService>,
        ),
      );
    } on Exception {
      _failure(emit, 'Não foi possível carregar equipe e serviços.');
    }
  }

  void _failure(Emitter<CatalogState> emit, String message) {
    emit(
      CatalogState(
        status: CatalogStatus.failure,
        professionals: state.professionals,
        services: state.services,
        message: message,
      ),
    );
  }
}
