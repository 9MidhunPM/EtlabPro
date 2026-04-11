import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class LockService extends ChangeNotifier with WidgetsBindingObserver {
  // Note: local_auth package not installed. Biometric auth disabled.
  bool _locked = false;
  bool get isLocked => _locked;

  LockService() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _locked = true;
      notifyListeners();
    }
  }

  Future<void> authenticate() async {
    try {
      // Biometric authentication not available (local_auth package not installed)
      _locked = false;
      notifyListeners();
    } on PlatformException {
      _locked = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
