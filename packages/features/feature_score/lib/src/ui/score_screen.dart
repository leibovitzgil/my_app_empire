import 'package:feature_score/src/bloc/score_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ScoreScreen extends StatelessWidget {
  const ScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Score')),
      body: BlocBuilder<ScoreBloc, ScoreState>(
        builder: (context, state) {
          switch (state.status) {
            case ScoreStatus.initial:
            case ScoreStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case ScoreStatus.loaded:
              return Center(child: Text(state.value ?? ''));
            case ScoreStatus.failure:
              return Center(child: Text(state.error ?? 'Error'));
          }
        },
      ),
    );
  }
}
