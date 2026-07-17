import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/domain/account.dart';
import 'package:fluxora/domain/appointment.dart';
import 'package:fluxora/ui/appointments_page.dart';

void main() {
  group('permissão para associar cliente fiel', () {
    test('owner e manager podem associar antes do checkout', () {
      final appointment = _appointment(AppointmentStatus.scheduled);

      expect(
        canAssociateAppointmentCustomer(
          appointment: appointment,
          businessId: 'business-1',
          role: MembershipRole.owner,
          membershipActive: true,
        ),
        isTrue,
      );
      expect(
        canAssociateAppointmentCustomer(
          appointment: appointment,
          businessId: 'business-1',
          role: MembershipRole.manager,
          membershipActive: true,
        ),
        isTrue,
      );
    });

    test('profissional só pode associar no próprio atendimento', () {
      final appointment = _appointment(AppointmentStatus.confirmed);

      expect(
        canAssociateAppointmentCustomer(
          appointment: appointment,
          businessId: 'business-1',
          role: MembershipRole.professional,
          membershipActive: true,
          linkedProfessionalId: 'professional-1',
        ),
        isTrue,
      );
      expect(
        canAssociateAppointmentCustomer(
          appointment: appointment,
          businessId: 'business-1',
          role: MembershipRole.professional,
          membershipActive: true,
          linkedProfessionalId: 'professional-2',
        ),
        isFalse,
      );
    });

    test('ninguém associa após checkout ou encerramento', () {
      for (final status in [
        AppointmentStatus.completed,
        AppointmentStatus.cancelled,
        AppointmentStatus.noShow,
      ]) {
        expect(
          canAssociateAppointmentCustomer(
            appointment: _appointment(status),
            businessId: 'business-1',
            role: MembershipRole.owner,
            membershipActive: true,
          ),
          isFalse,
        );
      }
    });

    test('vínculo inativo ou de outro estabelecimento é bloqueado', () {
      final appointment = _appointment(AppointmentStatus.scheduled);

      expect(
        canAssociateAppointmentCustomer(
          appointment: appointment,
          businessId: 'business-1',
          role: MembershipRole.owner,
          membershipActive: false,
        ),
        isFalse,
      );
      expect(
        canAssociateAppointmentCustomer(
          appointment: appointment,
          businessId: 'business-2',
          role: MembershipRole.owner,
          membershipActive: true,
        ),
        isFalse,
      );
    });
  });
}

Appointment _appointment(AppointmentStatus status) {
  final startsAt = DateTime(2026, 7, 20, 10);
  return Appointment(
    id: 'appointment-1',
    businessId: 'business-1',
    professionalId: 'professional-1',
    serviceId: 'service-1',
    customerName: 'Cliente',
    customerPhone: '11999999999',
    startsAt: startsAt,
    endsAt: startsAt.add(const Duration(hours: 1)),
    status: status,
    source: AppointmentSource.publicBooking,
    createdAt: startsAt,
  );
}
