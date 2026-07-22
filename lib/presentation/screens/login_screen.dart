import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/app_state.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController(),
      password = TextEditingController(),
      displayName = TextEditingController();
  bool signup = false, loading = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    displayName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.shield_rounded, size: 64, color: AppColors.cyan),
              const SizedBox(height: 18),
              Text(
                'CASTLE WATCH',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                signup
                    ? 'Create your command center'
                    : 'Your shields. Always in sight.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 36),
              if (!SupabaseConfig.isConfigured) ...[
                Card(
                  color: const Color(0x33FF667D),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      SupabaseConfig.hasPlaceholderUrl
                          ? 'SUPABASE_URL is still a placeholder. Copy the real Project URL from Supabase Settings → API, update the environment file, and fully restart the app.'
                          : 'Supabase is not configured for this launch. Restart with SUPABASE_URL and SUPABASE_ANON_KEY dart-defines.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (signup) ...[
                TextField(
                  controller: displayName,
                  decoration: InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 10),
              if (!signup)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                ),
              const SizedBox(height: 12),
              if (error != null) ...[
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.red),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: loading ? null : _submit,
                child: loading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(signup ? 'Create account' : 'Sign in'),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => setState(() => signup = !signup),
                child: Text(
                  signup
                      ? 'Already have an account? Sign in'
                      : 'New commander? Create an account',
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Independent player-support tool. Not affiliated with the game publisher.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    if (email.text.trim().isEmpty || !email.text.contains('@')) {
      setState(() => error = 'Enter a valid email address.');
      return;
    }
    if (password.text.length < 6) {
      setState(() => error = 'Password must contain at least 6 characters.');
      return;
    }
    if (signup && displayName.text.trim().isEmpty) {
      setState(() => error = 'Enter your display name.');
      return;
    }
    if (!SupabaseConfig.isConfigured) {
      if (SupabaseConfig.demoMode) {
        context.go('/dashboard');
      } else {
        setState(
          () => error =
              'Supabase configuration is missing. Fully restart the app with both dart-defines.',
        );
      }
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
      if (signup) {
        await auth.signUp(
          email: email.text,
          password: password.text,
          displayName: displayName.text,
        );
      } else {
        await auth.signIn(email: email.text, password: password.text);
      }
      if (mounted && auth.currentSession != null) {
        context.go('/dashboard');
      } else if (mounted) {
        setState(() => error = 'Check your email to confirm your account.');
      }
    } on AppFailure catch (failure) {
      if (mounted) {
        setState(() => error = failure.message);
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    if (email.text.trim().isEmpty) {
      setState(() => error = 'Enter your email first.');
      return;
    }
    if (!SupabaseConfig.isConfigured) {
      setState(() => error = 'Password reset requires Supabase configuration.');
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } on AppFailure catch (failure) {
      if (mounted) setState(() => error = failure.message);
    }
  }
}
