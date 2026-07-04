import 'package:feature_pairing/src/bloc/pairing_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PairingScreen extends StatelessWidget {
  const PairingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pairing')),
      body: BlocBuilder<PairingBloc, PairingState>(
        builder: (context, state) {
          switch (state.status) {
            case PairingStatus.initial:
            case PairingStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case PairingStatus.loaded:
              return Center(child: Text(state.value ?? ''));
            case PairingStatus.failure:
              return Center(child: Text(state.error ?? 'Error'));
          }
        },
      ),
    );
  }
}
