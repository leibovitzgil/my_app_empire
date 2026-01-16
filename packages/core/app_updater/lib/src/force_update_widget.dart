import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_update_service.dart';

class ForceUpdateWidget extends StatefulWidget {
  const ForceUpdateWidget({
    required this.child,
    this.appUpdateService,
    super.key,
  });

  final Widget child;
  final AppUpdateService? appUpdateService;

  @override
  State<ForceUpdateWidget> createState() => _ForceUpdateWidgetState();
}

class _ForceUpdateWidgetState extends State<ForceUpdateWidget> {
  late AppUpdateService _service;
  bool _isUpdateRequired = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.appUpdateService ?? AppUpdateService();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    try {
      final required = await _service.isUpdateRequired();
      if (mounted) {
        setState(() {
          _isUpdateRequired = required;
          _isLoading = false;
        });
      }
    } catch (e) {
      // If check fails, we proceed to app
      if (mounted) {
        setState(() {
          _isUpdateRequired = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Showing a loading indicator while checking version.
      // This might be replaced by a splash screen in real usage.
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isUpdateRequired) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Update Required',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'A new version of the app is available. Please update to continue using the app.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    final url = _service.getStoreUrl();
                    if (url.isNotEmpty) {
                      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text('Update Now'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
