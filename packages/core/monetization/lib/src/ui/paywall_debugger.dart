import 'package:flutter/material.dart';
import '../monetization_service.dart';
import '../simulated_monetization_service.dart';

/// A widget that provides debugging tools for the Monetization system.
///
/// If the provided [monetizationService] is a [SimulatedMonetizationService],
/// it allows toggling the "Pro" status.
///
/// If it is a real service, it displays the current status.
class PaywallDebugger extends StatelessWidget {
  final MonetizationService monetizationService;

  const PaywallDebugger({
    super.key,
    required this.monetizationService,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paywall Debugger',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            StreamBuilder<bool>(
              stream: monetizationService.isProUserStream(),
              builder: (context, snapshot) {
                final isPro = snapshot.data ?? false;
                return Row(
                  children: [
                    const Text('Status: '),
                    Icon(
                      isPro ? Icons.check_circle : Icons.cancel,
                      color: isPro ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPro ? 'Pro User' : 'Free User',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            if (monetizationService is SimulatedMonetizationService)
              _buildSimulationControls(context, monetizationService as SimulatedMonetizationService)
            else
              const Text(
                'Running on real RevenueCat service.\nSimulation controls disabled.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulationControls(BuildContext context, SimulatedMonetizationService service) {
    return StreamBuilder<bool>(
      stream: service.isProUserStream(),
      builder: (context, snapshot) {
        final isPro = snapshot.data ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const Text('Simulation Controls:'),
            SwitchListTile(
              title: const Text('Simulate Pro User'),
              subtitle: const Text('Toggles the local Pro status'),
              value: isPro,
              onChanged: (value) {
                service.setProStatus(value);
              },
            ),
          ],
        );
      },
    );
  }
}
