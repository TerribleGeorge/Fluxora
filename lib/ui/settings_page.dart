import 'package:flutter/material.dart';

import 'plans_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text('Perfil do espaço'),
              subtitle: Text('Pessoal, profissional ou empresa'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          const Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(Icons.account_balance_outlined),
              ),
              title: Text('Contas e carteiras'),
              subtitle: Text('Organize saldos por origem'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          const Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon(Icons.group_outlined)),
              title: Text('Equipe e permissões'),
              subtitle: Text('Controle de acesso preparado'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          const Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon(Icons.cloud_outlined)),
              title: Text('Sincronização segura'),
              subtitle: Text('Dados locais e nuvem protegidos por acesso'),
              trailing: Icon(Icons.chevron_right),
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
        ],
      ),
    );
  }
}
