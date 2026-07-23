import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import '../domain/account.dart';
import '../domain/business_document.dart';
import '../state/business_bloc.dart';
import '../state/business_event.dart';

class BusinessSetupPage extends StatefulWidget {
  const BusinessSetupPage({super.key});

  @override
  State<BusinessSetupPage> createState() => _BusinessSetupPageState();
}

class _BusinessSetupPageState extends State<BusinessSetupPage> {
  final _nameController = TextEditingController();
  final _documentController = TextEditingController();
  final _referralController = TextEditingController();
  BusinessType _type = BusinessType.beautySalon;

  @override
  void dispose() {
    _nameController.dispose();
    _documentController.dispose();
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
                  'O CNPJ protege seu teste gratuito, evita cadastros duplicados e ajuda o Fluxora a tratar seu negócio como uma empresa real.',
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
                  controller: _documentController,
                  textCapitalization: TextCapitalization.characters,
                  keyboardType: TextInputType.text,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9./-]')),
                    _BusinessDocumentInputFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'CNPJ do estabelecimento',
                    helperText:
                        'Obrigatório para liberar os 14 dias grátis. Aceita CNPJ numérico e alfanumérico.',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Usamos o CNPJ para impedir que o mesmo estabelecimento crie vários testes grátis com e-mails diferentes.',
                          ),
                        ),
                      ],
                    ),
                  ),
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
                            document: _documentController.text,
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

class _BusinessDocumentInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = BusinessDocument.normalize(newValue.text);
    final trimmed = normalized.length > 14
        ? normalized.substring(0, 14)
        : normalized;
    final formatted = _formatPartial(trimmed);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatPartial(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      if (i == 2 || i == 5) buffer.write('.');
      if (i == 8) buffer.write('/');
      if (i == 12) buffer.write('-');
      buffer.write(value[i]);
    }
    return buffer.toString();
  }
}
