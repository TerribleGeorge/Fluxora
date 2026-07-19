import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/id_generator.dart';
import '../domain/sale.dart';
import '../state/catalog_bloc.dart';
import '../state/sales_bloc.dart';
import '../state/sales_event.dart';
import '../state/sales_state.dart';
import 'money.dart';

class SalesPage extends StatelessWidget {
  const SalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Atendimentos e vendas')),
      body: BlocConsumer<SalesBloc, SalesState>(
        listenWhen: (before, after) =>
            after.message != null && before.message != after.message,
        listener: (context, state) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.message!))),
        builder: (context, state) {
          if (state.loading && state.sales.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.sales.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Registre o primeiro atendimento ou venda para acompanhar o faturamento real.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final professionals = context.read<CatalogBloc>().state.professionals;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: state.sales.length,
            itemBuilder: (context, index) {
              final sale = state.sales[index];
              final professional = professionals
                  .where((item) => item.id == sale.professionalId)
                  .firstOrNull;
              return Card(
                child: ListTile(
                  enabled: sale.status == SaleStatus.completed,
                  leading: CircleAvatar(
                    child: Icon(
                      sale.status == SaleStatus.cancelled
                          ? Icons.block
                          : Icons.check,
                    ),
                  ),
                  title: Text(
                    sale.items.map((item) => item.description).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${professional?.name ?? 'Profissional'} • ${_paymentLabel(sale.payment.method)}'
                    '${sale.payment.feeAmount > 0 ? ' • taxa ${money(sale.payment.feeAmount)}' : ''}',
                  ),
                  trailing: Text(
                    money(sale.grossTotal),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onLongPress: sale.status == SaleStatus.completed
                      ? () => _confirmCancel(context, sale)
                      : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSaleForm(context),
        icon: const Icon(Icons.point_of_sale),
        label: const Text('Nova venda'),
      ),
    );
  }

  String _paymentLabel(PaymentMethod method) => switch (method) {
    PaymentMethod.cash => 'Dinheiro',
    PaymentMethod.pix => 'Pix',
    PaymentMethod.debitCard => 'Débito',
    PaymentMethod.creditCard => 'Crédito',
    PaymentMethod.other => 'Outro',
  };

  Future<void> _confirmCancel(BuildContext context, Sale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar venda?'),
        content: const Text(
          'A venda permanecerá no histórico, mas não contará nos resultados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancelar venda'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<SalesBloc>().add(SaleCancelled(sale.id));
    }
  }
}

Future<void> _showSaleForm(BuildContext context) async {
  final catalog = context.read<CatalogBloc>().state;
  final professionals = catalog.professionals
      .where((item) => item.active)
      .toList();
  final services = catalog.services.where((item) => item.active).toList();
  if (professionals.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cadastre um profissional antes da venda.')),
    );
    return;
  }
  String professionalId = professionals.first.id;
  String? serviceId = services.firstOrNull?.id;
  var itemType = services.isEmpty ? SaleItemType.product : SaleItemType.service;
  var paymentMethod = PaymentMethod.pix;
  final productDescription = TextEditingController();
  final productPrice = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final customer = TextEditingController();
  final fee = TextEditingController(text: '0');
  final installments = TextEditingController(text: '1');

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Novo atendimento ou venda',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: professionalId,
                      decoration: const InputDecoration(
                        labelText: 'Profissional',
                      ),
                      items: professionals
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          professionalId = value ?? professionalId,
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<SaleItemType>(
                      segments: const [
                        ButtonSegment(
                          value: SaleItemType.service,
                          label: Text('Serviço'),
                        ),
                        ButtonSegment(
                          value: SaleItemType.product,
                          label: Text('Produto'),
                        ),
                      ],
                      selected: {itemType},
                      onSelectionChanged: (value) =>
                          setModalState(() => itemType = value.first),
                    ),
                    const SizedBox(height: 14),
                    if (itemType == SaleItemType.service)
                      DropdownButtonFormField<String>(
                        initialValue: serviceId,
                        decoration: const InputDecoration(labelText: 'Serviço'),
                        items: services
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(
                                  '${item.name} — ${money(item.price)}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => serviceId = value,
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: productDescription,
                              decoration: const InputDecoration(
                                labelText: 'Produto',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: productPrice,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Preço',
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: quantity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<PaymentMethod>(
                      initialValue: paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Forma de pagamento',
                      ),
                      items: PaymentMethod.values
                          .map(
                            (method) => DropdownMenuItem(
                              value: method,
                              child: Text(_paymentMethodLabel(method)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setModalState(
                        () => paymentMethod = value ?? paymentMethod,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (paymentMethod == PaymentMethod.debitCard ||
                        paymentMethod == PaymentMethod.creditCard)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: fee,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Taxa (%)',
                              ),
                            ),
                          ),
                          if (paymentMethod == PaymentMethod.creditCard) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: installments,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Parcelas',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: customer,
                      decoration: const InputDecoration(
                        labelText: 'Cliente (opcional)',
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        final selectedService = services
                            .where((item) => item.id == serviceId)
                            .firstOrNull;
                        final saleItem =
                            itemType == SaleItemType.service &&
                                selectedService != null
                            ? SaleItem(
                                id: createUuid(),
                                type: SaleItemType.service,
                                description: selectedService.name,
                                quantity: int.tryParse(quantity.text) ?? 0,
                                unitPrice: selectedService.price,
                                serviceId: selectedService.id,
                              )
                            : SaleItem(
                                id: createUuid(),
                                type: SaleItemType.product,
                                description: productDescription.text,
                                quantity: int.tryParse(quantity.text) ?? 0,
                                unitPrice: _parseNumber(productPrice.text),
                              );
                        context.read<SalesBloc>().add(
                          SaleCreated(
                            professionalId: professionalId,
                            items: [saleItem],
                            paymentMethod: paymentMethod,
                            paymentFeePercent: _parseNumber(fee.text),
                            installments: int.tryParse(installments.text) ?? 1,
                            customerName: customer.text,
                          ),
                        );
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Concluir venda'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  } finally {
    productDescription.dispose();
    productPrice.dispose();
    quantity.dispose();
    customer.dispose();
    fee.dispose();
    installments.dispose();
  }
}

String _paymentMethodLabel(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => 'Dinheiro',
  PaymentMethod.pix => 'Pix',
  PaymentMethod.debitCard => 'Cartão de débito',
  PaymentMethod.creditCard => 'Cartão de crédito',
  PaymentMethod.other => 'Outro',
};

double _parseNumber(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
