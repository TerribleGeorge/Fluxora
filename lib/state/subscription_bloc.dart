import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/subscription_repository.dart';
import 'subscription_event.dart';
import 'subscription_state.dart';

class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  SubscriptionBloc(this._repository) : super(const SubscriptionState()) {
    on<SubscriptionStarted>(_onStarted);
  }
  final SubscriptionRepository _repository;

  Future<void> _onStarted(
    SubscriptionStarted event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const SubscriptionState(status: SubscriptionLoadStatus.loading));
    try {
      emit(
        SubscriptionState(
          status: SubscriptionLoadStatus.ready,
          subscription: await _repository.getSubscription(),
        ),
      );
    } on Exception {
      emit(
        const SubscriptionState(
          status: SubscriptionLoadStatus.failure,
          message: 'Não foi possível verificar o período de teste.',
        ),
      );
    }
  }
}
