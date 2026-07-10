import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/catalog.dart';
import '../domain/business_repository.dart';
import '../domain/service_template.dart';
import '../state/auth_bloc.dart';
import '../state/catalog_bloc.dart';
import '../state/catalog_event.dart';
import '../state/catalog_state.dart';
import 'money.dart';

class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Equipe e serviços'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Profissionais', icon: Icon(Icons.groups_outlined)),
              Tab(text: 'Serviços', icon: Icon(Icons.content_cut_outlined)),
            ],
          ),
        ),
        body: BlocConsumer<CatalogBloc, CatalogState>(
          listenWhen: (before, after) =>
              after.message != null && before.message != after.message,
          listener: (context, state) => ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message!))),
          builder: (context, state) {
            if (state.loading &&
                state.professionals.isEmpty &&
                state.services.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            return TabBarView(
              children: [
                _ProfessionalsList(items: state.professionals),
                _ServicesList(items: state.services),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfessionalsList extends StatelessWidget {
  const _ProfessionalsList({required this.items});
  final List<Professional> items;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        items.isEmpty
            ? const _EmptyCatalog(
                icon: Icons.groups_outlined,
                title: 'Cadastre sua equipe',
                message: 'Defina profissionais e a comissão padrão de cada um.',
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    child: ListTile(
                      enabled: item.active,
                      leading: CircleAvatar(
                        child: Text(item.name.characters.first.toUpperCase()),
                      ),
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.defaultCommissionPercent.toStringAsFixed(1)}% de comissão padrão'
                        '${item.userId == null ? '' : ' • usuário vinculado'}',
                      ),
                      onTap: () => _showProfessionalForm(context, item),
                      trailing: Switch(
                        value: item.active,
                        onChanged: (active) => context.read<CatalogBloc>().add(
                          ProfessionalActiveChanged(item.id, active),
                        ),
                      ),
                    ),
                  );
                },
              ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            heroTag: 'new-professional',
            onPressed: () => _showProfessionalForm(context),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Profissional'),
          ),
        ),
      ],
    );
  }
}

class _ServicesList extends StatelessWidget {
  const _ServicesList({required this.items});
  final List<BeautyService> items;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        items.isEmpty
            ? const _EmptyCatalog(
                icon: Icons.content_cut_outlined,
                title: 'Cadastre seus serviços',
                message: 'Informe preço, duração e regra de comissão.',
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    child: ListTile(
                      enabled: item.active,
                      leading: const CircleAvatar(
                        child: Icon(Icons.spa_outlined),
                      ),
                      title: Text(item.name),
                      subtitle: Text(
                        '${money(item.price)} • ${item.durationMinutes} min • ${_commissionLabel(item)}',
                      ),
                      onTap: () => _showServiceForm(context, item),
                      trailing: Switch(
                        value: item.active,
                        onChanged: (active) => context.read<CatalogBloc>().add(
                          ServiceActiveChanged(item.id, active),
                        ),
                      ),
                    ),
                  );
                },
              ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            heroTag: 'new-service',
            onPressed: () => _showServiceForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Serviço'),
          ),
        ),
      ],
    );
  }

  String _commissionLabel(BeautyService service) =>
      switch (service.commissionType) {
        ServiceCommissionType.businessDefault => 'comissão do profissional',
        ServiceCommissionType.percentage =>
          '${service.commissionValue.toStringAsFixed(1)}% de comissão',
        ServiceCommissionType.fixedAmount =>
          '${money(service.commissionValue)} de comissão',
      };
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

Future<void> _showProfessionalForm(
  BuildContext context, [
  Professional? item,
]) async {
  final bloc = context.read<CatalogBloc>();
  final name = TextEditingController(text: item?.name);
  final phone = TextEditingController(text: item?.phone);
  final email = TextEditingController(text: item?.email);
  final commission = TextEditingController(
    text: item?.defaultCommissionPercent.toStringAsFixed(1) ?? '0',
  );
  final identity = context.read<AuthBloc>().state.identity;
  var linkToCurrentUser =
      item?.userId == identity?.id ||
      (item == null &&
          identity != null &&
          identity.email.trim().toLowerCase() ==
              email.text.trim().toLowerCase());
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setModalState) => _FormSheet(
        title: item == null ? 'Novo profissional' : 'Editar profissional',
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefone'),
          ),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail (opcional)'),
            onChanged: (value) {
              if (identity == null) return;
              final sameEmail =
                  value.trim().toLowerCase() ==
                  identity.email.trim().toLowerCase();
              if (sameEmail != linkToCurrentUser) {
                setModalState(() => linkToCurrentUser = sameEmail);
              }
            },
          ),
          if (identity != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: linkToCurrentUser,
              title: const Text('Vincular este profissional ao meu usuário'),
              subtitle: Text(
                linkToCurrentUser
                    ? 'Este login verá a própria agenda e comissões.'
                    : 'Use quando este cadastro representa a pessoa logada.',
              ),
              onChanged: (value) =>
                  setModalState(() => linkToCurrentUser = value),
            ),
          TextField(
            controller: commission,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Comissão padrão (%)'),
          ),
          FilledButton(
            onPressed: () {
              bloc.add(
                ProfessionalSaved(
                  id: item?.id,
                  name: name.text,
                  phone: phone.text,
                  email: email.text,
                  commissionPercent: _number(commission.text),
                  userId: linkToCurrentUser ? identity?.id : item?.userId,
                ),
              );
              Navigator.pop(sheetContext);
            },
            child: const Text('Salvar profissional'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  phone.dispose();
  email.dispose();
  commission.dispose();
}

Future<void> _showServiceForm(
  BuildContext context, [
  BeautyService? item,
]) async {
  final bloc = context.read<CatalogBloc>();
  final businessType = context.read<BusinessAccess>().business.type;
  final templates = ServiceTemplateCatalog.forBusinessType(businessType);
  final messenger = ScaffoldMessenger.of(context);
  final name = TextEditingController(text: item?.name);
  final category = TextEditingController(text: item?.category ?? 'Serviços');
  final price = TextEditingController(text: item?.price.toStringAsFixed(2));
  final duration = TextEditingController(
    text: item?.durationMinutes.toString() ?? '30',
  );
  final commission = TextEditingController(
    text: item?.commissionValue.toStringAsFixed(2) ?? '0',
  );
  final search = TextEditingController();
  var commissionType =
      item?.commissionType ?? ServiceCommissionType.businessDefault;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setModalState) {
        final suggestions = templates
            .where((template) => template.matches(search.text))
            .take(18)
            .toList(growable: false);
        return _FormSheet(
          title: item == null ? 'Novo serviço' : 'Editar serviço',
          children: [
            if (item == null) ...[
              TextField(
                controller: search,
                decoration: const InputDecoration(
                  labelText: 'Buscar serviço pronto',
                  hintText: 'Ex.: corte, barba, manicure, limpeza...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setModalState(() {}),
              ),
              Text(
                'Toque em uma sugestão para preencher nome, categoria e duração. Depois ajuste preço e tempo do seu negócio.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final template in suggestions)
                    ActionChip(
                      label: Text(
                        '${template.name} • ${template.durationMinutes} min',
                      ),
                      onPressed: () {
                        setModalState(() {
                          name.text = template.name;
                          category.text = template.category;
                          duration.text = template.durationMinutes.toString();
                          if (template.suggestedPrice > 0) {
                            price.text = template.suggestedPrice
                                .toStringAsFixed(2);
                          }
                        });
                      },
                    ),
                ],
              ),
            ],
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: category,
              decoration: const InputDecoration(labelText: 'Categoria'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Preço (R\$)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duração (min)',
                    ),
                  ),
                ),
              ],
            ),
            DropdownButtonFormField<ServiceCommissionType>(
              initialValue: commissionType,
              decoration: const InputDecoration(labelText: 'Regra de comissão'),
              items: const [
                DropdownMenuItem(
                  value: ServiceCommissionType.businessDefault,
                  child: Text('Usar comissão do profissional'),
                ),
                DropdownMenuItem(
                  value: ServiceCommissionType.percentage,
                  child: Text('Percentual específico'),
                ),
                DropdownMenuItem(
                  value: ServiceCommissionType.fixedAmount,
                  child: Text('Valor fixo'),
                ),
              ],
              onChanged: (value) =>
                  setModalState(() => commissionType = value ?? commissionType),
            ),
            if (commissionType != ServiceCommissionType.businessDefault)
              TextField(
                controller: commission,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: commissionType == ServiceCommissionType.percentage
                      ? 'Comissão (%)'
                      : 'Comissão fixa (R\$)',
                ),
              ),
            FilledButton(
              onPressed: () {
                final parsedPrice = _number(price.text);
                final parsedDuration = int.tryParse(duration.text.trim()) ?? 0;
                final parsedCommission = _number(commission.text);
                final invalidCommission =
                    parsedCommission < 0 ||
                    (commissionType == ServiceCommissionType.percentage &&
                        parsedCommission > 100);
                if (name.text.trim().length < 2 ||
                    parsedPrice <= 0 ||
                    parsedDuration < 5 ||
                    invalidCommission) {
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Revise o serviço: nome, preço, duração mínima de 5 minutos e comissão válida.',
                        ),
                      ),
                    );
                  return;
                }
                bloc.add(
                  ServiceSaved(
                    id: item?.id,
                    name: name.text,
                    category: category.text,
                    price: parsedPrice,
                    durationMinutes: parsedDuration,
                    commissionType: commissionType,
                    commissionValue: parsedCommission,
                  ),
                );
                Navigator.pop(sheetContext);
              },
              child: const Text('Salvar serviço'),
            ),
          ],
        );
      },
    ),
  );
  name.dispose();
  category.dispose();
  price.dispose();
  duration.dispose();
  commission.dispose();
  search.dispose();
}

class _FormSheet extends StatelessWidget {
  const _FormSheet({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              for (final child in children) ...[
                child,
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

double _number(String value) {
  return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
}
