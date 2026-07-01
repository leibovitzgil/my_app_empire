import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMembershipRepository extends Mock implements MembershipRepository {}

void main() {
  group('MembersBloc', () {
    const me = GrocerySeed.you;
    final owner = ListMember(
      collaborator: GrocerySeed.you,
      role: MemberRole.owner,
      status: MemberStatus.active,
      since: DateTime(2026, 6, 2),
    );
    final invited = ListMember(
      collaborator: const Collaborator(
        id: 'x@y.com',
        name: 'Pat',
        colorValue: 1,
      ),
      role: MemberRole.editor,
      status: MemberStatus.invited,
      since: DateTime(2026, 6, 28),
    );
    late MockMembershipRepository repo;
    late StreamController<List<ListMember>> controller;

    setUp(() {
      repo = MockMembershipRepository();
      controller = StreamController<List<ListMember>>.broadcast();
      when(repo.watchMembers).thenAnswer((_) => controller.stream);
      when(repo.inviteLink).thenReturn('https://tandem.app/join/household');
    });
    tearDown(() => controller.close());

    blocTest<MembersBloc, MembersState>(
      'reflects the roster arriving on the stream',
      build: () => MembersBloc(repository: repo, currentUser: me),
      act: (_) => controller.add([owner]),
      expect: () => [
        isA<MembersState>()
            .having((s) => s.status, 'status', MembersStatus.ready)
            .having((s) => s.members, 'members', [owner]),
      ],
    );

    blocTest<MembersBloc, MembersState>(
      'MemberInvited surfaces a success message',
      build: () => MembersBloc(repository: repo, currentUser: me),
      setUp: () => when(
        () => repo.inviteByEmail(any()),
      ).thenAnswer((_) async => Success<ListMember>(invited)),
      act: (bloc) => bloc.add(const MemberInvited('x@y.com')),
      expect: () => [
        isA<MembersState>().having(
          (s) => s.actionMessage,
          'actionMessage',
          'Invited Pat',
        ),
      ],
    );

    blocTest<MembersBloc, MembersState>(
      'MemberInvited maps a MembershipException to its message',
      build: () => MembersBloc(repository: repo, currentUser: me),
      setUp: () => when(() => repo.inviteByEmail(any())).thenAnswer(
        (_) async => const ResultFailure<ListMember>(
          MembershipException('Enter a valid email address'),
        ),
      ),
      act: (bloc) => bloc.add(const MemberInvited('nope')),
      expect: () => [
        isA<MembersState>().having(
          (s) => s.actionError,
          'actionError',
          'Enter a valid email address',
        ),
      ],
    );

    blocTest<MembersBloc, MembersState>(
      'MemberRemoved surfaces a failure message on error',
      build: () => MembersBloc(repository: repo, currentUser: me),
      setUp: () => when(() => repo.removeMember(any())).thenAnswer(
        (_) async => const ResultFailure<void>(
          MembershipException("The owner can't be removed"),
        ),
      ),
      act: (bloc) => bloc.add(const MemberRemoved('me')),
      expect: () => [
        isA<MembersState>().having(
          (s) => s.actionError,
          'actionError',
          "The owner can't be removed",
        ),
      ],
    );

    blocTest<MembersBloc, MembersState>(
      'MemberRemoved emits nothing extra on success',
      build: () => MembersBloc(repository: repo, currentUser: me),
      setUp: () => when(
        () => repo.removeMember(any()),
      ).thenAnswer((_) async => const Success<void>(null)),
      act: (bloc) => bloc.add(const MemberRemoved('x@y.com')),
      expect: () => <MembersState>[],
    );
  });
}
