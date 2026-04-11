import 'package:flutter/material.dart';

import '../services/version_check_service.dart';

class LatestVersionGuard extends StatefulWidget {
  final Widget child;

  const LatestVersionGuard({super.key, required this.child});

  @override
  State<LatestVersionGuard> createState() => _LatestVersionGuardState();
}

class _LatestVersionGuardState extends State<LatestVersionGuard> {
  bool _checked = false;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _runVersionCheck();
  }

  Future<void> _runVersionCheck() async {
    if (_checked) return;
    _checked = true;

    final result = await VersionCheckService.check();
    if (!mounted || !result.isOutdated || _dialogShown) return;

    _dialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Update Required'),
          content: Text(
            'You are not on latest version contact Midhun : 8217267367 For latest version if interested\n\n'
            'Your version: ${result.currentVersion}\n'
            'Latest version: ${result.latestVersion}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
