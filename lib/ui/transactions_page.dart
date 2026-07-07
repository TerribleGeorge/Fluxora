import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/transaction.dart';
import '../state/finance_bloc.dart';
import '../state/finance_event.dart';
import '../state/finance_state.dart';
import 'money.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  Future<void> _openForm(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final description = TextEditingController();
    final amount = TextEditingController();
    final category = TextEditingController();
    var type = TransactionType.expense;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Form(
          key: formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Novo lançamento',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Entrada'),
                      icon: Icon(Icons.add),
                    ),
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Saída'),
                      icon: Icon(Icons.remove),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (value) =>
                      setModalState(() => type = value.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: description,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'Informe uma descrição válida.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor',
                    prefixText: 'R\$ ',
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(
                      (value ?? '').replaceAll(',', '.'),
                    );
                    return parsed == null || parsed <= 0
                        ? 'Informe um valor maior que zero.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: category,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Categoria (opcional)',
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    final parsed = double.parse(
                      amount.text.replaceAll(',', '.'),
                    );
                    context.read<FinanceBloc>().add(
                      FinanceTransactionAdded(
                        description: description.text.trim(),
                        amount: parsed,
                        category: category.text.trim().isEmpty
                            ? type == TransactionType.income
                                  ? 'Receitas'
                                  : 'Despesas'
                            : category.text.trim(),
                        type: type,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('Salvar lançamento'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    description.dispose();
    amount.dispose();
    category.dispose();
  }

  Future<void> _delete(
    BuildContext context,
    FinanceTransaction transaction,
  ) async {
    context.read<FinanceBloc>().add(FinanceTransactionDeleted(transaction));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${transaction.description} foi excluído.'),
          action: SnackBarAction(
            label: 'DESFAZER',
            onPressed: () => context.read<FinanceBloc>().add(
              FinanceTransactionRestored(transaction),
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FinanceBloc, FinanceState>(
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Lançamentos')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.add),
          label: const Text('Novo'),
        ),
        body: state.transactions.isEmpty
            ? const Center(child: Text('Nenhum lançamento ainda.'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: state.transactions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = state.transactions[index];
                  return Dismissible(
                    key: ValueKey(item.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.all(24),
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: const Icon(Icons.delete_outline),
                    ),
                    onDismissed: (_) => _delete(context, item),
                    child: Card(
                      child: ListTile(
                        title: Text(item.description),
                        subtitle: Text(item.category),
                        leading: CircleAvatar(
                          child: Icon(
                            item.type == TransactionType.income
                                ? Icons.south_west
                                : Icons.north_east,
                          ),
                        ),
                        trailing: Text(
                          '${item.type == TransactionType.income ? '+' : '-'} ${money(item.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: item.type == TransactionType.income
                                ? Colors.greenAccent
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
