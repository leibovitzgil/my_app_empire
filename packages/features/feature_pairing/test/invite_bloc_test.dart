import 'package:bloc_test/bloc_test.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_pairing/feature_pairing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';
import 'package:pieces/pieces.dart';

class MockInviteService extends Mock implements InviteService {}

class MockMonetizationService extends Mock implements MonetizationService {}

class MockPieceRepository extends Mock implements PieceRepository {}

void main() {
  group('InviteBloc', () {
    const teacherId = 'teacher-1';
    const pieceId = 'p1';

    late MockInviteService inviteService;
    late MockMonetizationService monetization;
    late MockPieceRepository pieceRepository;

    Piece pieceWithStudent(String? studentId) => Piece(
      id: 'p_$studentId',
      title: 'Nocturne',
      basePdfChecksum: 'c',
      basePdfPath: '/tmp/p.pdf',
      teacherId: teacherId,
      studentId: studentId,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    setUp(() {
      inviteService = MockInviteService();
      monetization = MockMonetizationService();
      pieceRepository = MockPieceRepository();
    });

    InviteBloc buildBloc() => InviteBloc(
      inviteService: inviteService,
      monetizationService: monetization,
      pieceRepository: pieceRepository,
      teacherId: teacherId,
      pieceId: pieceId,
    );

    blocTest<InviteBloc, InviteState>(
      'a pro teacher is always ready, regardless of paired-student count',
      build: () {
        when(() => monetization.isProUser()).thenAnswer((_) async => true);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const InviteSheetOpened()),
      skip: 1,
      expect: () => [
        isA<InviteState>().having(
          (s) => s.status,
          'status',
          InviteStatus.ready,
        ),
      ],
    );

    blocTest<InviteBloc, InviteState>(
      'a free-tier teacher under the limit is ready',
      build: () {
        when(() => monetization.isProUser()).thenAnswer((_) async => false);
        when(() => pieceRepository.watchPieces()).thenAnswer(
          (_) => Stream.value([pieceWithStudent(null)]),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const InviteSheetOpened()),
      skip: 1,
      expect: () => [
        isA<InviteState>().having(
          (s) => s.status,
          'status',
          InviteStatus.ready,
        ),
      ],
    );

    blocTest<InviteBloc, InviteState>(
      'a free-tier teacher at the limit requires the paywall',
      build: () {
        when(() => monetization.isProUser()).thenAnswer((_) async => false);
        when(() => pieceRepository.watchPieces()).thenAnswer(
          (_) => Stream.value([pieceWithStudent('student-1')]),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const InviteSheetOpened()),
      skip: 1,
      expect: () => [
        isA<InviteState>().having(
          (s) => s.status,
          'status',
          InviteStatus.paywallRequired,
        ),
      ],
    );

    blocTest<InviteBloc, InviteState>(
      'creating a link succeeds',
      build: () {
        when(() => monetization.isProUser()).thenAnswer((_) async => true);
        when(
          () => inviteService.createInvite(
            teacherId: teacherId,
            pieceId: pieceId,
          ),
        ).thenAnswer(
          (_) async => Success(
            InviteLink(
              token: 'tok',
              uri: Uri.parse('https://duet.app/invite/tok'),
              pieceId: pieceId,
              teacherId: teacherId,
            ),
          ),
        );
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const InviteSheetOpened());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const InviteLinkCreateRequested());
      },
      skip: 2,
      expect: () => [
        isA<InviteState>().having(
          (s) => s.status,
          'status',
          InviteStatus.creating,
        ),
        isA<InviteState>()
            .having((s) => s.status, 'status', InviteStatus.created)
            .having((s) => s.link?.token, 'link.token', 'tok'),
      ],
    );

    blocTest<InviteBloc, InviteState>(
      'a create failure surfaces the error and stays retryable',
      build: () {
        when(() => monetization.isProUser()).thenAnswer((_) async => true);
        when(
          () => inviteService.createInvite(
            teacherId: teacherId,
            pieceId: pieceId,
          ),
        ).thenAnswer(
          (_) async => const ResultFailure<InviteLink>(InviteException('boom')),
        );
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const InviteSheetOpened());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const InviteLinkCreateRequested());
      },
      skip: 2,
      expect: () => [
        isA<InviteState>().having(
          (s) => s.status,
          'status',
          InviteStatus.creating,
        ),
        isA<InviteState>()
            .having((s) => s.status, 'status', InviteStatus.failure)
            .having((s) => s.error, 'error', contains('boom')),
      ],
    );
  });
}
