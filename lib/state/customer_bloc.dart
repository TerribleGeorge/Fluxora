import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/customer_repository.dart';
import 'customer_event.dart';
import 'customer_state.dart';

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  CustomerBloc(this._repository) : super(const CustomerState()) {
    on<CustomerStarted>(_onStarted);
    on<LoyaltySettingsSaved>(_onLoyaltySettingsSaved);
    on<CustomerLoyaltyOverrideSaved>(_onCustomerLoyaltyOverrideSaved);
    on<CustomerLinkedToAppointment>(_onCustomerLinkedToAppointment);
    on<CustomerAssociationSearched>(_onCustomerAssociationSearched);
  }

  final CustomerRepository _repository;
  int _associationSearchRevision = 0;

  Future<void> _onStarted(
    CustomerStarted event,
    Emitter<CustomerState> emit,
  ) async {
    emit(state.copyWith(status: CustomerStatus.loading));
    await _reload(emit);
  }

  Future<void> _onLoyaltySettingsSaved(
    LoyaltySettingsSaved event,
    Emitter<CustomerState> emit,
  ) async {
    final settings = event.settings;
    final invalidDiscount =
        settings.standardDiscountPercent < 0 ||
        settings.standardDiscountPercent > 100 ||
        settings.goldDiscountPercent < 0 ||
        settings.goldDiscountPercent > 100 ||
        settings.premiumDiscountPercent < 0 ||
        settings.premiumDiscountPercent > 100;
    if (invalidDiscount || settings.inactiveAfterDays < 1) {
      emit(
        state.copyWith(
          status: CustomerStatus.failure,
          message: 'Revise descontos e prazo de inatividade.',
        ),
      );
      return;
    }

    try {
      await _repository.saveLoyaltySettings(settings);
      await _reload(emit, message: 'Configurações de fidelidade salvas.');
    } on Exception {
      emit(
        state.copyWith(
          status: CustomerStatus.failure,
          message: 'Não foi possível salvar a fidelidade.',
        ),
      );
    }
  }

  Future<void> _onCustomerLoyaltyOverrideSaved(
    CustomerLoyaltyOverrideSaved event,
    Emitter<CustomerState> emit,
  ) async {
    if (event.customerId.trim().isEmpty) {
      emit(
        state.copyWith(
          status: CustomerStatus.failure,
          message: 'Não foi possível identificar o cliente.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: CustomerStatus.loading));
    try {
      await _repository.updateCustomerLoyaltyOverride(
        customerId: event.customerId,
        tier: event.tier,
        reason: event.reason,
      );
      await _reload(
        emit,
        message: event.tier == null
            ? 'Cliente voltou para a fidelidade automática.'
            : 'Categoria de fidelidade do cliente salva.',
      );
    } on Exception {
      emit(
        state.copyWith(
          status: CustomerStatus.failure,
          message: 'Não foi possível salvar a categoria do cliente.',
        ),
      );
    }
  }

  Future<void> _onCustomerLinkedToAppointment(
    CustomerLinkedToAppointment event,
    Emitter<CustomerState> emit,
  ) async {
    if (event.appointmentId.trim().isEmpty || event.customerId.trim().isEmpty) {
      emit(
        state.copyWith(
          status: CustomerStatus.failure,
          message: 'Não foi possível identificar o atendimento e o cliente.',
        ),
      );
      if (!event.completer.isCompleted) event.completer.complete(false);
      return;
    }

    emit(state.copyWith(status: CustomerStatus.loading));
    try {
      await _repository.linkAppointmentToCustomer(
        appointmentId: event.appointmentId,
        customerId: event.customerId,
      );
      emit(
        state.copyWith(
          status: CustomerStatus.success,
          associationCandidates: const [],
          associationQuery: '',
          associationSearchLoading: false,
          message: 'Cliente fiel associado e preço do atendimento atualizado.',
        ),
      );
      if (!event.completer.isCompleted) event.completer.complete(true);
    } on Exception {
      emit(
        state.copyWith(
          status: CustomerStatus.failure,
          message:
              'Não foi possível associar o cliente. Confirme se o atendimento ainda não foi concluído.',
        ),
      );
      if (!event.completer.isCompleted) event.completer.complete(false);
    }
  }

  Future<void> _onCustomerAssociationSearched(
    CustomerAssociationSearched event,
    Emitter<CustomerState> emit,
  ) async {
    final query = event.query.trim();
    final revision = ++_associationSearchRevision;
    if (event.appointmentId.trim().isEmpty || query.length < 2) {
      emit(
        state.copyWith(
          associationCandidates: const [],
          associationQuery: query,
          associationSearchLoading: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        associationCandidates: const [],
        associationQuery: query,
        associationSearchLoading: true,
      ),
    );
    try {
      final customers = await _repository.searchLinkableCustomers(
        appointmentId: event.appointmentId,
        query: query,
      );
      if (revision != _associationSearchRevision) return;
      emit(
        state.copyWith(
          associationCandidates: customers,
          associationQuery: query,
          associationSearchLoading: false,
        ),
      );
    } on Exception {
      if (revision != _associationSearchRevision) return;
      emit(
        state.copyWith(
          associationCandidates: const [],
          associationQuery: query,
          associationSearchLoading: false,
          message: 'Não foi possível buscar clientes para este atendimento.',
        ),
      );
    }
  }

  Future<void> _reload(Emitter<CustomerState> emit, {String? message}) async {
    try {
      final results = await Future.wait([
        _repository.getLoyaltySettings(),
        _repository.getCustomers(),
      ]);
      emit(
        CustomerState(
          status: CustomerStatus.success,
          loyaltySettings: results[0] as dynamic,
          customers: results[1] as dynamic,
          message: message,
        ),
      );
    } on Exception {
      emit(
        state.copyWith(
          status: CustomerStatus.failure,
          message: 'Não foi possível carregar clientes e fidelidade.',
        ),
      );
    }
  }
}
