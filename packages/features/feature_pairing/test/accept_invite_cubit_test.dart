import 'package:bloc_test/bloc_test.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_pairing/feature_pairing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInviteService extends Mock implements InviteService {}

void main() {
  group('AcceptInviteCubit', () {
    const token = 'tok-1';
    const studentId = 'student-1';
    const details = InviteDetails(
      pieceId: 'p1',
      pieceTitle: 'Nocturne',
      teacherId: 'teacher-1',
    );

    late MockInviteService inviteService;

    setUp(() {
      inviteService = MockInviteService();
    });

    AcceptInviteCubit buildCubit() => AcceptInviteCubit(
      inviteService: inviteService,
      token: token,
      studentId: studentId,
    );

    blocTest<AcceptInviteCubit, AcceptInviteState>(
      'load resolves the invite details on success',
      build: () {
        when(
          () => inviteService.resolveInvite(token),
        ).thenAnswer((_) async => const Success(details));
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<AcceptInviteState>().having(
          (s) => s.status,
          'status',
          AcceptInviteStatus.loading,
        ),
        isA<AcceptInviteState>()
            .having((s) => s.status, 'status', AcceptInviteStatus.ready)
            .having((s) => s.details, 'details', details),
      ],
    );

    blocTest<AcceptInviteCubit, AcceptInviteState>(
      'load surfaces a failure for an invalid/expired token',
      build: () {
        when(() => inviteService.resolveInvite(token)).thenAnswer(
          (_) async => const ResultFailure<InviteDetails>(
            InviteException('This invite link is invalid or has expired.'),
          ),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [
        isA<AcceptInviteState>()
            .having((s) => s.status, 'status', AcceptInviteStatus.failure)
            .having(
              (s) => s.error,
              'error',
              contains('invalid or has expired'),
            ),
      ],
    );

    blocTest<AcceptInviteCubit, AcceptInviteState>(
      'accept moves to accepted on success',
      build: () {
        when(
          () => inviteService.resolveInvite(token),
        ).thenAnswer((_) async => const Success(details));
        when(
          () => inviteService.acceptInvite(token, studentId: studentId),
        ).thenAnswer((_) async => const Success<void>(null));
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.load();
        await cubit.accept();
      },
      skip: 2,
      expect: () => [
        isA<AcceptInviteState>().having(
          (s) => s.status,
          'status',
          AcceptInviteStatus.accepting,
        ),
        isA<AcceptInviteState>().having(
          (s) => s.status,
          'status',
          AcceptInviteStatus.accepted,
        ),
      ],
    );

    blocTest<AcceptInviteCubit, AcceptInviteState>(
      'accept surfaces a failure and stays retryable',
      build: () {
        when(
          () => inviteService.resolveInvite(token),
        ).thenAnswer((_) async => const Success(details));
        when(
          () => inviteService.acceptInvite(token, studentId: studentId),
        ).thenAnswer(
          (_) async => const ResultFailure<void>(
            InviteException('This piece already has a student.'),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.load();
        await cubit.accept();
      },
      skip: 2,
      expect: () => [
        isA<AcceptInviteState>().having(
          (s) => s.status,
          'status',
          AcceptInviteStatus.accepting,
        ),
        isA<AcceptInviteState>()
            .having((s) => s.status, 'status', AcceptInviteStatus.ready)
            .having((s) => s.error, 'error', contains('already has a student')),
      ],
    );
  });
}
