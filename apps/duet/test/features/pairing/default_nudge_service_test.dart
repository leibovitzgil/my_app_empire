import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/pairing/pairing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notifications/notifications.dart';

class _MockPieceRepository extends Mock implements PieceRepository {}

Piece _piece({
  required String id,
  required String ownerId,
  List<Collaborator> collaborators = const [],
}) => Piece(
  id: id,
  title: 'Sheet',
  basePdfChecksum: 'c',
  basePdfPath: 'p.pdf',
  ownerId: ownerId,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
  collaborators: collaborators,
);

void main() {
  late _MockPieceRepository pieces;
  late InMemoryUserMessaging gateway;

  setUp(() {
    pieces = _MockPieceRepository();
    gateway = InMemoryUserMessaging();
  });

  DefaultNudgeService serviceFor(String me) => DefaultNudgeService(
    pieceRepository: pieces,
    messageGateway: gateway,
    currentUserId: () => me,
  );

  test('nudges every other participant, never the sender', () async {
    when(() => pieces.getPiece('p1')).thenAnswer(
      (_) async => Success(
        _piece(
          id: 'p1',
          ownerId: 'owner',
          collaborators: const [
            Collaborator(uid: 'bea', name: 'Bea'),
            Collaborator(uid: 'cal', name: 'Cal'),
          ],
        ),
      ),
    );

    final result = await serviceFor(
      'owner',
    ).nudge(pieceId: 'p1', fromName: 'Ada');
    expect(result, isA<Success<void>>());

    final beaInbox = await gateway.inboxFor('bea').first;
    expect(beaInbox, hasLength(1));
    expect(beaInbox.single.title, 'Ada added notes');
    expect(beaInbox.single.data['type'], 'nudge');
    expect(beaInbox.single.data['pieceId'], 'p1');
    expect(beaInbox.single.data['fromName'], 'Ada');

    expect(await gateway.inboxFor('cal').first, hasLength(1));
    // The sender never nudges themselves.
    expect(await gateway.inboxFor('owner').first, isEmpty);
  });

  test(
    'a collaborator can nudge the owner (and other collaborators)',
    () async {
      when(() => pieces.getPiece('p1')).thenAnswer(
        (_) async => Success(
          _piece(
            id: 'p1',
            ownerId: 'owner',
            collaborators: const [Collaborator(uid: 'bea', name: 'Bea')],
          ),
        ),
      );

      await serviceFor('bea').nudge(pieceId: 'p1', fromName: 'Bea');

      expect(await gateway.inboxFor('owner').first, hasLength(1));
      expect(await gateway.inboxFor('bea').first, isEmpty);
    },
  );

  test('a solo sheet is a no-op success', () async {
    when(() => pieces.getPiece('solo')).thenAnswer(
      (_) async => Success(_piece(id: 'solo', ownerId: 'owner')),
    );

    final result = await serviceFor(
      'owner',
    ).nudge(pieceId: 'solo', fromName: 'Ada');
    expect(result, isA<Success<void>>());
    expect(await gateway.inboxFor('owner').first, isEmpty);
  });

  test('surfaces a repository failure', () async {
    when(() => pieces.getPiece('gone')).thenAnswer(
      (_) async => ResultFailure<Piece>(StateError('gone')),
    );

    final result = await serviceFor(
      'owner',
    ).nudge(pieceId: 'gone', fromName: 'Ada');
    expect(result, isA<ResultFailure<void>>());
  });
}
