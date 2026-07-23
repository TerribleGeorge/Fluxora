import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/auth_repository.dart';
import '../domain/business_document.dart';
import '../domain/business_repository.dart';
import 'business_event.dart';
import 'business_state.dart';

class BusinessBloc extends Bloc<BusinessEvent, BusinessState> {
  BusinessBloc(this._repository) : super(const BusinessState()) {
    on<BusinessesStarted>(_onStarted);
    on<BusinessCreated>(_onCreated);
    on<BusinessSelected>(_onSelected);
  }

  final BusinessRepository _repository;

  Future<void> _onStarted(
    BusinessesStarted event,
    Emitter<BusinessState> emit,
  ) async {
    emit(const BusinessState(status: BusinessStatus.loading));
    try {
      final accesses = await _repository.getBusinesses();
      emit(
        BusinessState(
          status: accesses.isEmpty
              ? BusinessStatus.requiresBusiness
              : BusinessStatus.ready,
          accesses: accesses,
          selected: accesses.firstOrNull,
        ),
      );
    } on AuthFailure catch (error) {
      emit(
        BusinessState(status: BusinessStatus.failure, message: error.message),
      );
    }
  }

  Future<void> _onCreated(
    BusinessCreated event,
    Emitter<BusinessState> emit,
  ) async {
    if (event.name.trim().length < 2) {
      emit(
        const BusinessState(
          status: BusinessStatus.requiresBusiness,
          message: 'Informe o nome do estabelecimento.',
        ),
      );
      return;
    }
    if (!BusinessDocument.isValid(event.document)) {
      emit(
        const BusinessState(
          status: BusinessStatus.requiresBusiness,
          message:
              'Informe um CNPJ válido para ativar o teste gratuito do estabelecimento.',
        ),
      );
      return;
    }
    emit(const BusinessState(status: BusinessStatus.loading));
    try {
      final access = await _repository.createBusiness(
        name: event.name,
        type: event.type,
        document: BusinessDocument.normalize(event.document),
        referralCode: event.referralCode,
      );
      emit(
        BusinessState(
          status: BusinessStatus.ready,
          accesses: [access],
          selected: access,
        ),
      );
    } on AuthFailure catch (error) {
      emit(
        BusinessState(
          status: BusinessStatus.requiresBusiness,
          message: error.message,
        ),
      );
    }
  }

  void _onSelected(BusinessSelected event, Emitter<BusinessState> emit) {
    emit(
      BusinessState(
        status: BusinessStatus.ready,
        accesses: state.accesses,
        selected: event.access,
      ),
    );
  }
}
