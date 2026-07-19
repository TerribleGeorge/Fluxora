import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/account.dart';
import 'package:fluxora/domain/business_repository.dart';
import 'package:fluxora/ui/quick_start_manual_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('manual explica fluxo do dono e do funcionário', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      Provider<BusinessAccess>.value(
        value: _access(MembershipRole.owner),
        child: const MaterialApp(home: QuickStartManualPage()),
      ),
    );

    expect(find.text('Manual rápido do Fluxora'), findsOneWidget);
    expect(find.text('Dono'), findsOneWidget);
    expect(find.text('Funcionário'), findsOneWidget);
    expect(find.text('4. Como aparecer no site do cliente'), findsOneWidget);
    expect(
      find.textContaining('Ative Aparecer na busca pública'),
      findsOneWidget,
    );

    await tester.tap(find.text('Funcionário'));
    await tester.pumpAndSettle();

    expect(find.text('1. Onde o funcionário entra'), findsOneWidget);
    expect(find.textContaining('toque em Funcionário'), findsOneWidget);
    expect(find.textContaining('e-mail do estabelecimento'), findsOneWidget);
    expect(find.textContaining('Faturamento total da empresa'), findsOneWidget);
  });

  testWidgets('cartão abre o manual rápido', (tester) async {
    await tester.pumpWidget(
      Provider<BusinessAccess>.value(
        value: _access(MembershipRole.professional),
        child: const MaterialApp(home: Scaffold(body: QuickStartManualCard())),
      ),
    );

    expect(find.text('Guia rápido do funcionário'), findsOneWidget);

    await tester.tap(find.text('Abrir manual'));
    await tester.pumpAndSettle();

    expect(find.text('Manual rápido do Fluxora'), findsOneWidget);
    expect(find.text('1. Onde o funcionário entra'), findsOneWidget);
  });
}

BusinessAccess _access(MembershipRole role) {
  return BusinessAccess(
    business: BeautyBusiness(
      id: 'business-1',
      name: 'Studio Teste',
      type: BusinessType.beautySalon,
      createdAt: DateTime(2026),
    ),
    membership: BusinessMembership(
      id: 'membership-1',
      businessId: 'business-1',
      userId: 'user-1',
      role: role,
      createdAt: DateTime(2026),
    ),
  );
}
