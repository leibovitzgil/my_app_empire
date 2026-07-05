@Tags(['golden'])
library;

import 'package:feature_score/feature_score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A network-free theme (AppTheme pulls google_fonts, which fetches at
// runtime and fails in tests).
final _theme = ThemeData(useMaterial3: true);

const _layers = [
  ParticipantLayer(
    ownerId: 'owner',
    label: 'Ms. Rivera',
    colorId: 'p0',
    strokes: [],
    visible: true,
    isOwn: true,
  ),
  ParticipantLayer(
    ownerId: 'c1',
    label: 'Bea',
    colorId: 'p1',
    strokes: [],
    visible: true,
    isOwn: false,
  ),
  ParticipantLayer(
    ownerId: 'c2',
    label: 'Cy',
    colorId: 'p2',
    strokes: [],
    visible: true,
    isOwn: false,
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required List<ParticipantLayer> layers,
  bool audioPinsVisible = true,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      home: Scaffold(
        body: LayerToggleBar(
          layers: layers,
          audioPinsVisible: audioPinsVisible,
          onInkToggle: (_) {},
          onAudioToggle: () {},
        ),
      ),
    ),
  );
}

void main() {
  group('LayerToggleBar goldens', () {
    testWidgets('owner plus two collaborators, all visible', (tester) async {
      await _pump(tester, layers: _layers);
      await expectLater(
        find.byType(LayerToggleBar),
        matchesGoldenFile('goldens/layer_toggle_bar_collaborators.png'),
      );
    });

    testWidgets('a collaborator layer hidden', (tester) async {
      await _pump(
        tester,
        layers: [
          _layers[0],
          _layers[1].copyWith(visible: false),
          _layers[2],
        ],
        audioPinsVisible: false,
      );
      await expectLater(
        find.byType(LayerToggleBar),
        matchesGoldenFile('goldens/layer_toggle_bar_hidden.png'),
      );
    });
  });
}
