import 'package:feature_library/src/bloc/library_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, state) {
          switch (state.status) {
            case LibraryStatus.initial:
            case LibraryStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case LibraryStatus.loaded:
              return Center(child: Text(state.value ?? ''));
            case LibraryStatus.failure:
              return Center(child: Text(state.error ?? 'Error'));
          }
        },
      ),
    );
  }
}
