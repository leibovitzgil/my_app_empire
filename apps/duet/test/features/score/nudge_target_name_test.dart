import 'package:duet/domain/domain.dart';
import 'package:duet/features/score/score.dart';
import 'package:flutter_test/flutter_test.dart';

Piece _piece({
  required String ownerId,
  String? ownerName,
  List<Collaborator> collaborators = const [],
}) => Piece(
  id: 'p1',
  title: 'Sheet',
  basePdfChecksum: 'c',
  basePdfPath: 'p.pdf',
  ownerId: ownerId,
  ownerName: ownerName,
  collaborators: collaborators,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

void main() {
  group('nudgeTargetNameFor', () {
    test('a null piece has no target', () {
      expect(nudgeTargetNameFor(null, 'me'), isNull);
    });

    test('a solo sheet (only me) has no target', () {
      expect(nudgeTargetNameFor(_piece(ownerId: 'me'), 'me'), isNull);
    });

    test('the owner viewing names the single collaborator', () {
      final piece = _piece(
        ownerId: 'me',
        collaborators: const [Collaborator(uid: 'bea', name: 'Bea')],
      );
      expect(nudgeTargetNameFor(piece, 'me'), 'Bea');
    });

    test('a collaborator viewing names the owner', () {
      final piece = _piece(
        ownerId: 'owner',
        ownerName: 'Ada',
        collaborators: const [Collaborator(uid: 'me')],
      );
      expect(nudgeTargetNameFor(piece, 'me'), 'Ada');
    });

    test('several other participants read as "your collaborators"', () {
      final piece = _piece(
        ownerId: 'me',
        collaborators: const [
          Collaborator(uid: 'bea', name: 'Bea'),
          Collaborator(uid: 'cal', name: 'Cal'),
        ],
      );
      expect(nudgeTargetNameFor(piece, 'me'), 'your collaborators');
    });

    test('falls back to a generic label when the one other has no name', () {
      final piece = _piece(
        ownerId: 'me',
        collaborators: const [Collaborator(uid: 'bea')],
      );
      expect(nudgeTargetNameFor(piece, 'me'), 'your collaborator');
    });
  });
}
