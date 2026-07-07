import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidade e dados')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text(
            'Como o Fluxora trata seus dados',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text(
            'Coletamos os dados necessários para autenticar usuários e operar a gestão do estabelecimento: nome, e-mail, equipe, serviços, vendas, despesas, comissões e caixa.',
          ),
          SizedBox(height: 16),
          Text(
            'Os dados são usados para fornecer o serviço, sincronizar dispositivos, proteger o acesso e gerar os relatórios solicitados. O Fluxora não vende dados pessoais.',
          ),
          SizedBox(height: 16),
          Text(
            'O tráfego com o servidor utiliza conexão criptografada. O acesso ao banco é limitado por usuário e estabelecimento.',
          ),
          SizedBox(height: 16),
          Text(
            'Você pode exportar seus dados e solicitar a exclusão definitiva da conta nas configurações. Obrigações legais poderão exigir a retenção limitada de determinados registros.',
          ),
          SizedBox(height: 16),
          Text(
            'Esta versão não utiliza publicidade, rastreamento entre aplicativos nem comercialização de dados.',
          ),
        ],
      ),
    );
  }
}
