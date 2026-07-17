// Drives every real funnel bloc/cubit through its instrumented action and
// asserts each catalogue event fires exactly once per action (M7.2) — the
// exactly-once gate for the app-glue BlocObserver seam (features themselves
// stay analytics-free, G3).
import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:duet/data/duet_analytics.dart';
import 'package:duet/data/duet_analytics_observer.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/library/library.dart';
import 'package:duet/features/pairing/pairing.dart';
import 'package:duet/features/score/score.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_paywall/feature_paywall.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';
import 'package:notifications/notifications.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

import 'recording_app_logger.dart';

class _MockPieceRepository extends Mock implements PieceRepository {}

class _MockPdfRenderService extends Mock implements PdfRenderService {}

class _MockAnnotationRepository extends Mock implements AnnotationRepository {}

class _MockCollaboratorInviteService extends Mock
    implements CollaboratorInviteService {}

class _MockInviteService extends Mock implements InviteService {}

class _MockMonetizationService extends Mock implements MonetizationService {}

class _MockUserMessageGateway extends Mock implements UserMessageGateway {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockPackage extends Mock implements Package {}

class _MockCustomerInfo extends Mock implements CustomerInfo {}

void main() {
  const ownerId = 'owner-1';
  const pieceId = 'p1';

  late RecordingAppLogger logger;
  late BlocObserver previousObserver;

  Piece piece({List<Collaborator> collaborators = const []}) => Piece(
    id: pieceId,
    title: 'Nocturne',
    basePdfChecksum: 'c',
    basePdfPath: '/tmp/p.pdf',
    ownerId: ownerId,
    collaborators: collaborators,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  setUp(() {
    logger = RecordingAppLogger();
    previousObserver = Bloc.observer;
    Bloc.observer = DuetAnalyticsObserver(
      analytics: DuetAnalytics(logger),
    );
  });

  tearDown(() => Bloc.observer = previousObserver);

  group('sheet_imported', () {
    test('a successful import fires exactly once, with the piece id', () async {
      final repository = _MockPieceRepository();
      final renderService = _MockPdfRenderService();
      when(
        () => renderService.open('/tmp/source.pdf'),
      ).thenAnswer((_) async => const Success<int>(3));
      when(
        () => repository.importPiece(
          title: 'My title',
          sourcePath: '/tmp/source.pdf',
          ownerName: any<String?>(named: 'ownerName'),
        ),
      ).thenAnswer((_) async => Success<Piece>(piece()));

      final bloc = ImportPieceBloc(
        pieceRepository: repository,
        renderService: renderService,
        binaryStore: const NoopPieceBinaryStore(),
        filePicker: () async => const PickedPdfFile(
          path: '/tmp/source.pdf',
          suggestedTitle: 'My title',
        ),
      )..add(const ImportPickRequested());
      await pumpEventQueue();
      bloc.add(const ImportSubmitted());
      await pumpEventQueue();

      final events = logger.named('sheet_imported');
      expect(events, hasLength(1));
      expect(events.single.parameters, {'piece_id': pieceId});
      await bloc.close();
    });
  });

  group('invite_sent / paywall_shown (invite sheet)', () {
    late _MockCollaboratorInviteService collaboratorInviteService;
    late _MockInviteService inviteService;
    late _MockMonetizationService monetization;
    late _MockPieceRepository pieceRepository;

    setUp(() {
      collaboratorInviteService = _MockCollaboratorInviteService();
      inviteService = _MockInviteService();
      monetization = _MockMonetizationService();
      pieceRepository = _MockPieceRepository();
      when(() => monetization.isProUser()).thenAnswer((_) async => false);
    });

    InviteBloc buildBloc() => InviteBloc(
      collaboratorInviteService: collaboratorInviteService,
      inviteService: inviteService,
      monetizationService: monetization,
      pieceRepository: pieceRepository,
      ownerId: ownerId,
      pieceId: pieceId,
    );

    test(
      'an email invite send fires invite_sent{email} exactly once',
      () async {
        const email = 'collaborator@example.com';
        const recipient = InviteRecipient(uid: 'c1', email: email);
        when(
          () => pieceRepository.getPiece(pieceId),
        ).thenAnswer((_) async => Success<Piece>(piece()));
        when(
          () => collaboratorInviteService.lookupInvitee(
            pieceId: pieceId,
            email: email,
          ),
        ).thenAnswer(
          (_) async => const Success<LookupOutcome>(Resolved(recipient)),
        );
        when(
          () => collaboratorInviteService.sendInvite(
            pieceId: pieceId,
            ownerId: ownerId,
            email: email,
            ownerName: any<String?>(named: 'ownerName'),
          ),
        ).thenAnswer(
          (_) async => const Success<LookupOutcome>(Resolved(recipient)),
        );

        final bloc = buildBloc()..add(const InviteSheetOpened());
        await pumpEventQueue();
        bloc.add(const InviteEmailChanged(email));
        await pumpEventQueue();
        bloc.add(const InviteSendRequested());
        await pumpEventQueue();

        final events = logger.named('invite_sent');
        expect(events, hasLength(1));
        expect(events.single.parameters, {'method': 'email'});
        // The invite email itself must never ride along (no PII).
        expect('${events.single.parameters}', isNot(contains(email)));
        expect(logger.named('paywall_shown'), isEmpty);
        await bloc.close();
      },
    );

    test(
      'an invite-link creation fires invite_sent{link} exactly once',
      () async {
        when(
          () => pieceRepository.getPiece(pieceId),
        ).thenAnswer((_) async => Success<Piece>(piece()));
        when(
          () => inviteService.createInvite(
            ownerId: ownerId,
            pieceId: pieceId,
            ownerName: any<String?>(named: 'ownerName'),
          ),
        ).thenAnswer(
          (_) async => Success<InviteLink>(
            InviteLink(
              token: 't1',
              uri: Uri.parse('https://duet.dev/invite/t1'),
              pieceId: pieceId,
              ownerId: ownerId,
            ),
          ),
        );

        final bloc = buildBloc()..add(const InviteSheetOpened());
        await pumpEventQueue();
        bloc.add(const InviteLinkCreateRequested());
        await pumpEventQueue();

        final events = logger.named('invite_sent');
        expect(events, hasLength(1));
        expect(events.single.parameters, {'method': 'link'});
        await bloc.close();
      },
    );

    test('an at-cap sheet open fires paywall_shown exactly once', () async {
      when(() => pieceRepository.getPiece(pieceId)).thenAnswer(
        (_) async => Success<Piece>(
          piece(collaborators: const [Collaborator(uid: 's1')]),
        ),
      );

      final bloc = buildBloc()..add(const InviteSheetOpened());
      await pumpEventQueue();

      expect(logger.named('paywall_shown'), hasLength(1));
      expect(logger.named('invite_sent'), isEmpty);
      await bloc.close();
    });
  });

  group('invite_accepted', () {
    test('an inbox accept (M5.6, email path) fires exactly once', () async {
      final invites = _MockCollaboratorInviteService();
      final gateway = _MockUserMessageGateway();
      const invite = InviteMessage(
        messageId: 'm1',
        pieceId: pieceId,
        ownerId: ownerId,
      );
      when(
        () => invites.watchInvites('me'),
      ).thenAnswer((_) => const Stream<List<InviteMessage>>.empty());
      when(
        () => invites.acceptInvite(
          invite,
          accepterId: 'me',
          accepterName: any<String?>(named: 'accepterName'),
          accepterEmail: any<String?>(named: 'accepterEmail'),
        ),
      ).thenAnswer((_) async => const Success<void>(null));

      final cubit = InviteInboxCubit(
        collaboratorInviteService: invites,
        messageGateway: gateway,
        currentUserId: 'me',
      );
      await cubit.accept(invite);

      final events = logger.named('invite_accepted');
      expect(events, hasLength(1));
      expect(events.single.parameters, {'method': 'email'});
      await cubit.close();
    });

    test('an inbox accept refused at cap fires paywall_shown, not '
        'invite_accepted', () async {
      final invites = _MockCollaboratorInviteService();
      final gateway = _MockUserMessageGateway();
      const invite = InviteMessage(
        messageId: 'm1',
        pieceId: pieceId,
        ownerId: ownerId,
      );
      when(
        () => invites.watchInvites('me'),
      ).thenAnswer((_) => const Stream<List<InviteMessage>>.empty());
      when(
        () => invites.acceptInvite(
          invite,
          accepterId: 'me',
          accepterName: any<String?>(named: 'accepterName'),
          accepterEmail: any<String?>(named: 'accepterEmail'),
        ),
      ).thenAnswer(
        (_) async => const ResultFailure<void>(AtCapInviteException()),
      );

      final cubit = InviteInboxCubit(
        collaboratorInviteService: invites,
        messageGateway: gateway,
        currentUserId: 'me',
      );
      await cubit.accept(invite);

      expect(logger.named('invite_accepted'), isEmpty);
      expect(logger.named('paywall_shown'), hasLength(1));
      await cubit.close();
    });

    test('a token accept (M5.2, link path) fires exactly once', () async {
      final inviteService = _MockInviteService();
      final pieceRepository = _MockPieceRepository();
      final monetization = _MockMonetizationService();
      const details = InviteDetails(
        pieceId: pieceId,
        pieceTitle: 'Nocturne',
        ownerId: ownerId,
      );
      when(
        () => inviteService.resolveInvite('tok'),
      ).thenAnswer((_) async => const Success<InviteDetails>(details));
      when(
        () => pieceRepository.getPiece(pieceId),
      ).thenAnswer((_) async => Success<Piece>(piece()));
      when(monetization.isProUser).thenAnswer((_) async => false);
      when(
        () => inviteService.acceptInvite(
          'tok',
          collaboratorId: 'me',
          collaboratorName: any<String?>(named: 'collaboratorName'),
          collaboratorEmail: any<String?>(named: 'collaboratorEmail'),
        ),
      ).thenAnswer((_) async => const Success<void>(null));

      final cubit = AcceptInviteCubit(
        inviteService: inviteService,
        pieceRepository: pieceRepository,
        monetizationService: monetization,
        token: 'tok',
        collaboratorId: 'me',
      );
      await cubit.load();
      await cubit.accept();

      final events = logger.named('invite_accepted');
      expect(events, hasLength(1));
      expect(events.single.parameters, {'method': 'link'});
      await cubit.close();
    });
  });

  group('note_recorded / practice_opened (ScoreBloc)', () {
    late ScoreBloc bloc;

    setUp(() {
      bloc = ScoreBloc(
        pieceRepository: _MockPieceRepository(),
        annotationRepository: _MockAnnotationRepository(),
        currentUserId: 'me',
      );
    });

    tearDown(() => bloc.close());

    test(
      'a saved audio note fires note_recorded{duration_ms} exactly once',
      () async {
        const region = Region(
          pageIndex: 0,
          left: 0.1,
          top: 0.1,
          width: 0.5,
          height: 0.2,
        );
        final note = AudioNote(
          id: 'note_1',
          authorId: 'me',
          audioAssetId: 'asset_1',
          pageIndex: 0,
          durationMs: 4200,
          region: region,
          createdAt: DateTime(2024),
        );

        bloc.add(AudioNoteSaved(note, '/tmp/rec.m4a'));
        await pumpEventQueue();

        final events = logger.named('note_recorded');
        expect(events, hasLength(1));
        expect(events.single.parameters, {'duration_ms': 4200});
      },
    );

    test(
      'resolving a passage to practice fires practice_opened exactly once',
      () async {
        const region = Region(
          pageIndex: 0,
          left: 0,
          top: 0,
          width: 1,
          height: 1,
        );

        bloc
          ..add(const RegionSelectStarted(RegionIntent.practice))
          ..add(const RegionSelectCompleted(region));
        await pumpEventQueue();

        expect(logger.named('practice_opened'), hasLength(1));
      },
    );

    test('resolving a passage to record fires no practice_opened', () async {
      const region = Region(
        pageIndex: 0,
        left: 0,
        top: 0,
        width: 1,
        height: 1,
      );

      bloc
        ..add(const RegionSelectStarted(RegionIntent.recordAudio))
        ..add(const RegionSelectCompleted(region));
      await pumpEventQueue();

      expect(logger.named('practice_opened'), isEmpty);
    });
  });

  group('purchase_completed (PaywallBloc)', () {
    test('a completed purchase fires exactly once', () async {
      final monetization = _MockMonetizationService();
      final package = _MockPackage();
      when(
        () => monetization.purchasePackage(package),
      ).thenAnswer((_) async => _MockCustomerInfo());

      final bloc = PaywallBloc(monetizationService: monetization)
        ..add(PaywallPackagePurchased(package));
      await pumpEventQueue();

      expect(logger.named('purchase_completed'), hasLength(1));
      await bloc.close();
    });

    test('a restore never fires purchase_completed', () async {
      final monetization = _MockMonetizationService();
      when(
        monetization.restorePurchases,
      ).thenAnswer((_) async => _MockCustomerInfo());

      final bloc = PaywallBloc(monetizationService: monetization)
        ..add(const PaywallRestoreRequested());
      await pumpEventQueue();

      expect(logger.named('purchase_completed'), isEmpty);
      await bloc.close();
    });
  });

  group('sign_up (AuthBloc)', () {
    late _MockAuthRepository repository;
    late StreamController<String?> users;

    setUp(() {
      repository = _MockAuthRepository();
      users = StreamController<String?>.broadcast();
      when(() => repository.user).thenAnswer((_) => users.stream);
    });

    tearDown(() => users.close());

    test('a successful sign-up fires sign_up exactly once', () async {
      when(
        () => repository.signUp(
          'new@example.com',
          'pw',
          displayName: any<String?>(named: 'displayName'),
        ),
      ).thenAnswer((_) async {
        users.add('uid-1');
        return const Success<void>(null);
      });

      final bloc = AuthBloc(authRepository: repository)
        ..add(const AuthSignUpRequested('new@example.com', 'pw'));
      await pumpEventQueue();

      expect(logger.named('sign_up'), hasLength(1));
      await bloc.close();
    });

    test('a plain login never fires sign_up', () async {
      when(() => repository.login('old@example.com', 'pw')).thenAnswer((
        _,
      ) async {
        users.add('uid-1');
        return const Success<void>(null);
      });

      final bloc = AuthBloc(authRepository: repository)
        ..add(const AuthLoginRequested('old@example.com', 'pw'));
      await pumpEventQueue();

      expect(logger.named('sign_up'), isEmpty);
      await bloc.close();
    });

    test('a failed sign-up followed by a login fires no sign_up', () async {
      when(
        () => repository.signUp(
          'new@example.com',
          'pw',
          displayName: any<String?>(named: 'displayName'),
        ),
      ).thenAnswer(
        (_) async => const ResultFailure<void>(AuthFailure.unknown()),
      );
      when(() => repository.login('new@example.com', 'pw')).thenAnswer((
        _,
      ) async {
        users.add('uid-1');
        return const Success<void>(null);
      });

      final bloc = AuthBloc(authRepository: repository)
        ..add(const AuthSignUpRequested('new@example.com', 'pw'));
      await pumpEventQueue();
      bloc.add(const AuthLoginRequested('new@example.com', 'pw'));
      await pumpEventQueue();

      expect(logger.named('sign_up'), isEmpty);
      await bloc.close();
    });
  });
}
