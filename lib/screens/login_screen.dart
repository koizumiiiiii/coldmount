import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

// login screen where tenants and admins enter their account credentials
class LoginScreen extends StatefulWidget {
  final void Function(String role) onLogin;
  const LoginScreen({super.key, required this.onLogin});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// login form state that handles loading error and visibility
class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final pwCtrl = TextEditingController();
  final _auth = AuthService();
  bool showPw = false, loading = false;
  String error = '';

  // signs in with email and password then forwards role
  Future<void> signIn() async {
    if (emailCtrl.text.trim().isEmpty || pwCtrl.text.isEmpty) {
      setState(() => error = 'Please enter your email and password.');
      return;
    }
    setState(() { error = ''; loading = true; });
    try {
      final role = await _auth.signIn(emailCtrl.text, pwCtrl.text);
      if (!mounted) return;
      setState(() => loading = false);
      widget.onLogin(role);
    } on AuthError catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = e.message; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Sign-in failed. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [CmColors.primaryDark, CmColors.primary])),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.landscape, size: 64, color: Colors.white),
                  const Text('COLDMOUNT',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: 3)),
                  const Text('Boarding House Management',
                    style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sign in to your account',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        TextField(controller: emailCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Email address', labelStyle: TextStyle(color: Colors.white60),
                            prefixIcon: Icon(Icons.mail, color: Colors.white38))),
                        TextField(controller: pwCtrl, obscureText: !showPw,
                          onSubmitted: (_) => signIn(),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Password', labelStyle: const TextStyle(color: Colors.white60),
                            prefixIcon: const Icon(Icons.key, color: Colors.white38),
                            suffixIcon: IconButton(
                              icon: Icon(showPw ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white38),
                              onPressed: () => setState(() => showPw = !showPw)))),
                        if (error.isNotEmpty)
                          Padding(padding: const EdgeInsets.only(top: 8),
                            child: Text(error, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                        const SizedBox(height: 12),
                        SizedBox(width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CmColors.accent, foregroundColor: Colors.white),
                            onPressed: loading ? null : signIn,
                            child: Text(loading ? 'Signing in…' : 'Sign In'))),
                        const Text('Tenant accounts are created by your property admin.',
                          style: TextStyle(color: Colors.white30, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
