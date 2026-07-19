import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/account.dart';

void main() {
  group('permissões de membros', () {
    BusinessMembership membership(MembershipRole role, {bool active = true}) {
      return BusinessMembership(
        id: 'membership-1',
        businessId: 'business-1',
        userId: 'user-1',
        role: role,
        createdAt: DateTime(2026, 7, 7),
        active: active,
      );
    }

    test('proprietário possui todas as permissões', () {
      final owner = membership(MembershipRole.owner);

      for (final permission in BusinessPermission.values) {
        expect(owner.can(permission), isTrue);
      }
    });

    test('gestor opera o negócio sem alterar os dados principais', () {
      final manager = membership(MembershipRole.manager);

      expect(manager.can(BusinessPermission.manageCash), isTrue);
      expect(manager.can(BusinessPermission.viewAllReports), isTrue);
      expect(manager.can(BusinessPermission.manageBusiness), isFalse);
    });

    test('profissional acessa somente agenda e comissões próprias', () {
      final professional = membership(MembershipRole.professional);

      expect(professional.can(BusinessPermission.viewOwnSchedule), isTrue);
      expect(professional.can(BusinessPermission.viewOwnCommissions), isTrue);
      expect(professional.can(BusinessPermission.viewDashboard), isFalse);
      expect(professional.can(BusinessPermission.manageCash), isFalse);
    });

    test('membro inativo não possui acesso', () {
      final inactiveOwner = membership(MembershipRole.owner, active: false);

      expect(inactiveOwner.can(BusinessPermission.viewDashboard), isFalse);
    });
  });

  test('serializa e recupera as entidades da conta', () {
    final createdAt = DateTime(2026, 7, 7, 12);
    final user = UserProfile(
      id: 'user-1',
      name: 'Ana Silva',
      email: 'ana@example.com',
      createdAt: createdAt,
    );
    final business = BeautyBusiness(
      id: 'business-1',
      name: 'Studio Ana',
      type: BusinessType.browAndLashStudio,
      createdAt: createdAt,
      phone: '11999999999',
      referralCode: 'AB12CD',
    );
    final membership = BusinessMembership(
      id: 'membership-1',
      businessId: business.id,
      userId: user.id,
      role: MembershipRole.owner,
      createdAt: createdAt,
    );

    expect(UserProfile.fromJson(user.toJson()).email, user.email);
    expect(BeautyBusiness.fromJson(business.toJson()).type, business.type);
    expect(
      BeautyBusiness.fromJson(business.toJson()).referralCode,
      business.referralCode,
    );
    expect(
      BusinessMembership.fromJson(membership.toJson()).role,
      MembershipRole.owner,
    );
  });
}
