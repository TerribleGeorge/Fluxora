import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/account.dart';
import '../state/business_bloc.dart';
import '../state/business_event.dart';

class BusinessSetupPage extends StatefulWidget {
  const BusinessSetupPage({super.key});

  @override
  State<BusinessSetupPage> createState() => _BusinessSetupPageState();
}

class _BusinessSetupPageState extends State<BusinessSetupPage> {
  final _nameController = TextEditingController();
  final _referralController = TextEditingController();
  BusinessType _type = BusinessType.beautySalon;

  @override
  void dispose() {
    _nameController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BusinessBloc>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Configure seu negócio')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Vamos preparar seu espaço no Fluxora',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Você poderá cadastrar equipe, serviços e regras financeiras depois.',
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome do estabelecimento',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<BusinessType>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de negócio',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: BusinessType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(_label(type)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _type = value ?? _type),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _referralController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Código de indicação (opcional)',
                    helperText:
                        'Se outro estabelecimento indicou o Fluxora, informe o código aqui.',
                    prefixIcon: Icon(Icons.handshake_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: state.loading
                      ? null
                      : () => context.read<BusinessBloc>().add(
                          BusinessCreated(
                            name: _nameController.text,
                            type: _type,
                            referralCode: _referralController.text,
                          ),
                        ),
                  child: const Text('Criar estabelecimento'),
                ),
                if (state.message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _label(BusinessType type) => switch (type) {
    BusinessType.barbershop => 'Barbearia',
    BusinessType.beautySalon => 'Salão de beleza',
    BusinessType.nailStudio => 'Esmalteria / manicure',
    BusinessType.browAndLashStudio => 'Cílios e sobrancelhas',
    BusinessType.makeupStudio => 'Estúdio de maquiagem',
    BusinessType.spa => 'Spa',
    BusinessType.aestheticClinic => 'Clínica de estética',
    BusinessType.otherBeauty => 'Outro negócio de beleza',
  };
}
