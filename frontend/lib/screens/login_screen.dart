import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/student_data.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey  = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool  _obscure  = true;
  bool _isFetchingData = false;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthService>();
    final data = context.read<StudentData>();
    final ok = await auth.login(_userCtrl.text.trim(), _passCtrl.text);

    if (ok && mounted) {
      final roll = auth.rollNumber;
      if (roll != null) {
        setState(() => _isFetchingData = true);
        await data.loadAll(roll, force: true);
        if (!mounted) return;
        setState(() => _isFetchingData = false);
      }
      if (!mounted) return;
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LoginHeader(scheme: scheme),
                    const SizedBox(height: 36),
                    _CredentialsFields(
                      userCtrl: _userCtrl,
                      passCtrl: _passCtrl,
                      obscure: _obscure,
                      onToggleObscure: () => setState(() => _obscure = !_obscure),
                      onSubmit: _submit,
                    ),
                    const SizedBox(height: 12),
                    _AuthErrorBanner(error: auth.error, scheme: scheme),
                    const SizedBox(height: 12),
                    _SubmitButton(isLoading: auth.isLoading, onPressed: _submit),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      child: _isFetchingData
                          ? Column(
                              children: const [
                                SizedBox(height: 10),
                                LinearProgressIndicator(minHeight: 4),
                                SizedBox(height: 6),
                                Text('Fetching your data...', textAlign: TextAlign.center),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 24),
                    const _FooterNote(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  final ColorScheme scheme;

  const _LoginHeader({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.school_rounded, size: 40, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(height: 20),
        Text(
          'EtlabPro',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in with your Etlab credentials',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _CredentialsFields extends StatelessWidget {
  final TextEditingController userCtrl;
  final TextEditingController passCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  const _CredentialsFields({
    required this.userCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: userCtrl,
          decoration: const InputDecoration(
            labelText: 'Username',
            prefixIcon: Icon(Icons.person_outline),
          ),
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username],
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your username' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: passCtrl,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: onToggleObscure,
            ),
          ),
          obscureText: obscure,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onFieldSubmitted: (_) => onSubmit(),
          validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
        ),
      ],
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  final String? error;
  final ColorScheme scheme;

  const _AuthErrorBanner({required this.error, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: error != null
          ? Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: scheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(error!, style: TextStyle(color: scheme.onErrorContainer))),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _SubmitButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            )
          : const Text('Sign In'),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'WE DO NOT SAVE YOUR ETLAB USERNAME/PASSWORD.\nIT IS SAVED ONLY ON YOUR DEVICE.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
