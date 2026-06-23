import 'package:core_ui/core_ui.dart';
import 'package:feature_paywall/src/bloc/paywall_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A simple paywall: lists the current offering's packages with purchase and
/// restore actions. Provide a [PaywallBloc] above this widget.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Go Pro')),
      body: BlocBuilder<PaywallBloc, PaywallState>(
        builder: (context, state) {
          switch (state.status) {
            case PaywallStatus.initial:
            case PaywallStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case PaywallStatus.purchased:
              return const Center(child: Text('You are Pro! 🎉'));
            case PaywallStatus.ready:
            case PaywallStatus.purchasing:
            case PaywallStatus.failure:
              return _PaywallBody(state: state);
          }
        },
      ),
    );
  }
}

class _PaywallBody extends StatelessWidget {
  const _PaywallBody({required this.state});

  final PaywallState state;

  @override
  Widget build(BuildContext context) {
    final busy = state.status == PaywallStatus.purchasing;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: state.packages.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final package = state.packages[index];
                return Card(
                  child: ListTile(
                    title: Text(package.storeProduct.title),
                    subtitle: Text(package.storeProduct.priceString),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: busy
                        ? null
                        : () => context.read<PaywallBloc>().add(
                            PaywallPackagePurchased(package),
                          ),
                  ),
                );
              },
            ),
          ),
          if (state.status == PaywallStatus.failure && state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                state.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          PrimaryButton(
            label: 'Restore purchases',
            onPressed: busy
                ? null
                : () => context.read<PaywallBloc>().add(
                    const PaywallRestoreRequested(),
                  ),
          ),
        ],
      ),
    );
  }
}
