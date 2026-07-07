import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/subscription.dart';
import '../state/subscription_bloc.dart';
import '../state/subscription_state.dart';
import 'app_shell.dart';
import 'plans_page.dart';

class SubscriptionShell extends StatelessWidget {
  const SubscriptionShell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubscriptionBloc, SubscriptionState>(
      builder: (context, state) {
        if (state.status == SubscriptionLoadStatus.loading ||
            state.status == SubscriptionLoadStatus.initial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final subscription = state.subscription;
        if (subscription != null && !subscription.hasAccess) {
          return const PlansPage(expired: true);
        }
        return Column(
          children: [
            if (subscription?.status == SubscriptionStatus.trialing)
              Material(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: SafeArea(
                  bottom: false,
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: Text(
                      '${subscription!.trialDaysRemaining} dia(s) restantes no teste gratuito',
                    ),
                    trailing: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PlansPage(),
                        ),
                      ),
                      child: const Text('Ver planos'),
                    ),
                  ),
                ),
              ),
            const Expanded(child: AppShell()),
          ],
        );
      },
    );
  }
}
