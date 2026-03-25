import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

class LockService extends ChangeNotifier with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
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
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        _locked = false;
        notifyListeners();
        return;
      }
      final didAuth = await _auth.authenticate(
        localizedReason: 'Authenticate to access EtlabPro',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (didAuth) {
        _locked = false;
        notifyListeners();
      }
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
