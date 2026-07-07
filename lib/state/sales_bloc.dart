import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/id_generator.dart';
import '../domain/sale.dart';
import '../domain/sales_repository.dart';
import 'sales_event.dart';
import 'sales_state.dart';

class SalesBloc extends Bloc<SalesEvent, SalesState> {
  SalesBloc(this._repository, {required this.businessId, required this.userId})
    : super(const SalesState()) {
    on<SalesStarted>(_onStarted);
    on<SaleCreated>(_onCreated);
    on<SaleCancelled>(_onCancelled);
  }

  final SalesRepository _repository;
  final String businessId;
  final String userId;

  Future<void> _onStarted(SalesStarted event, Emitter<SalesState> emit) async {
    emit(SalesState(status: SalesStatus.loading, sales: state.sales));
    await _reload(emit);
  }

  Future<void> _onCreated(SaleCreated event, Emitter<SalesState> emit) async {
    final total = event.items.fold<double>(0, (sum, item) => sum + item.total);
    final invalidItems =
        event.items.isEmpty ||
        event.items.any(
          (item) =>
              item.description.trim().length < 2 ||
              item.quantity <= 0 ||
              item.unitPrice <= 0,
        );
    if (event.professionalId.isEmpty ||
        invalidItems ||
        total <= 0 ||
        event.paymentFeePercent < 0 ||
        event.paymentFeePercent > 100 ||
        event.installments < 1) {
      _failure(emit, 'Revise profissional, itens e forma de pagamento.');
      return;
    }
    final now = DateTime.now();
    final sale = Sale(
      id: createUuid(),
      businessId: businessId,
      professionalId: event.professionalId,
      items: List.unmodifiable(event.items),
      payment: SalePayment(
        method: event.paymentMethod,
        amount: total,
        feePercent: event.paymentFeePercent,
        installments: event.installments,
      ),
      occurredAt: now,
      createdBy: userId,
      createdAt: now,
      customerName: event.customerName.trim(),
      notes: event.notes.trim(),
    );
    try {
      await _repository.saveSale(sale);
      await _reload(emit);
    } on Exception {
      _failure(emit, 'Não foi possível registrar a venda.');
    }
  }

  Future<void> _onCancelled(
    SaleCancelled event,
    Emitter<SalesState> emit,
  ) async {
    try {
      await _repository.setSaleStatus(event.id, SaleStatus.cancelled);
      await _reload(emit);
    } on Exception {
      _failure(emit, 'Não foi possível cancelar a venda.');
    }
  }

  Future<void> _reload(Emitter<SalesState> emit) async {
    try {
      emit(
        SalesState(
          status: SalesStatus.success,
          sales: await _repository.getSales(),
        ),
      );
    } on Exception {
      _failure(emit, 'Não foi possível carregar as vendas.');
    }
  }

  void _failure(Emitter<SalesState> emit, String message) {
    emit(
      SalesState(
        status: SalesStatus.failure,
        sales: state.sales,
        message: message,
      ),
    );
  }
}
