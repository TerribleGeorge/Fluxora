import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/customer_repository.dart';
import 'customer_event.dart';
import 'customer_state.dart';

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  CustomerBloc(this._repository) : super(const CustomerState()) {
    on<CustomerStarted>(_onStarted);
    on<LoyaltySettingsSaved>(_onLoyaltySettingsSaved);
  }

  final CustomerRepository _repository;

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

  Future<void> _reload(
    Emitter<CustomerState> emit, {
    String? message,
  }) async {
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
