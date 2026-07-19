import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/account_lifecycle_repository.dart';
import '../domain/account.dart';
import '../domain/business_repository.dart';
import '../domain/public_booking.dart';
import '../state/auth_bloc.dart';
import '../state/auth_event.dart';
import '../state/catalog_bloc.dart';
import '../state/finance_bloc.dart';
import '../state/operations_bloc.dart';
import '../state/sales_bloc.dart';
import '../state/subscription_bloc.dart';
import 'plans_page.dart';
import 'patch_notes_page.dart';
import 'privacy_page.dart';
import 'transactions_page.dart';
import 'loyalty_settings_page.dart';
import 'public_booking_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<BusinessAccess>();
    final publicBookingRepository = context.watch<PublicBookingRepository?>();
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.new_releases_outlined),
              ),
              title: const Text('Novidades da versão'),
              subtitle: const Text(
                'Fluxora ${PatchNotesPage.version} (${PatchNotesPage.buildNumber})',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PatchNotesPage()),
              ),
            ),
          ),
          if (access.membership.role == MembershipRole.owner)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.public_outlined)),
                title: const Text('Agendamento online'),
                subtitle: Text(
                  publicBookingRepository == null
                      ? 'Conecte o servidor para configurar seu link'
                      : 'Configure e compartilhe o link dos seus clientes',
                ),
                trailing: const Icon(Icons.chevron_right),
                enabled: publicBookingRepository != null,
                onTap: publicBookingRepository == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PublicBookingSettingsPage(
                            businessId: access.business.id,
                            repository: publicBookingRepository,
                          ),
                        ),
                      ),
              ),
            ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.receipt_long_outlined),
              ),
              title: const Text('Despesas, impostos e retiradas'),
              subtitle: const Text('Gerencie as movimentações financeiras'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TransactionsPage(),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.workspace_premium_outlined),
              ),
              title: const Text('Fidelidade de clientes'),
              subtitle: const Text(
                'Ative níveis, descontos e antifraude no agendamento',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LoyaltySettingsPage(),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.storefront_outlined),
              ),
              title: Text(access.business.name),
              subtitle: Text('Perfil: ${access.membership.role.name}'),
            ),
          ),
          if (access.membership.role == MembershipRole.owner)
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.handshake_outlined),
                ),
                title: const Text('Indique o Fluxora'),
                subtitle: Text(
                  access.business.referralCode.isEmpty
                      ? 'Seu código será gerado após sincronizar o estabelecimento.'
                      : 'Código: ${access.business.referralCode} • indique e ganhe bônus de trial.',
                ),
                trailing: access.business.referralCode.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Copiar código',
                        icon: const Icon(Icons.copy_outlined),
                        onPressed: () =>
                            _copyReferralCode(context, access.business),
                      ),
              ),
            ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.workspace_premium_outlined),
              ),
              title: const Text('Plano e assinatura'),
              subtitle: const Text('Conheça os planos do Fluxora'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PlansPage()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.privacy_tip_outlined),
              ),
              title: const Text('Privacidade e dados'),
              subtitle: const Text('Veja como seus dados são protegidos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PrivacyPage()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.download_outlined)),
              title: const Text('Exportar meus dados'),
              subtitle: const Text(
                'Copia um arquivo JSON para a área de transferência',
              ),
              onTap: () => _exportData(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.logout)),
              title: const Text('Sair da conta'),
              onTap: () =>
                  context.read<AuthBloc>().add(const AuthSignOutRequested()),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _deleteAccount(context),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Excluir conta e dados'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    final access = context.read<BusinessAccess>();
    final finance = context.read<FinanceBloc>().state;
    final catalog = context.read<CatalogBloc>().state;
    final sales = context.read<SalesBloc>().state;
    final operations = context.read<OperationsBloc>().state;
    final subscription = context.read<SubscriptionBloc>().state.subscription;
    final data = {
      'exportedAt': DateTime.now().toIso8601String(),
      'business': access.business.toJson(),
      'membership': access.membership.toJson(),
      'professionals': catalog.professionals
          .map((item) => item.toJson())
          .toList(),
      'services': catalog.services.map((item) => item.toJson()).toList(),
      'sales': sales.sales.map((item) => item.toJson()).toList(),
      'transactions': finance.transactions
          .map((item) => item.toJson())
          .toList(),
      'payouts': operations.payouts.map((item) => item.toJson()).toList(),
      'cashSessions': operations.cashSessions
          .map((item) => item.toJson())
          .toList(),
      'subscription': subscription?.toJson(),
    };
    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados exportados para a área de transferência.'),
        ),
      );
    }
  }

  Future<void> _copyReferralCode(
    BuildContext context,
    BeautyBusiness business,
  ) async {
    await Clipboard.setData(ClipboardData(text: business.referralCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código de indicação copiado.')),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final controller = TextEditingController();
    final bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Excluir conta definitivamente?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Esta ação remove a conta e os dados associados. Exporte uma cópia antes, se necessário.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Digite EXCLUIR para confirmar',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                controller.text.trim().toUpperCase() == 'EXCLUIR',
              ),
              child: const Text('Excluir definitivamente'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<AccountLifecycleRepository>().deleteAccount();
      await (await SharedPreferences.getInstance()).clear();
      if (context.mounted) {
        context.read<AuthBloc>().add(const AuthSignOutRequested());
      }
    } on Exception catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}
