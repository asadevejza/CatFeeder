import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../localization/app_strings.dart';

// Prijava / registracija preko backenda (JWT). Prikazuje se dok korisnik
// nije prijavljen (prvi put ili poslije odjave).
class AuthScreen extends StatefulWidget {
  final String baseUrl;
  final VoidCallback onSuccess;
  const AuthScreen({super.key, required this.baseUrl, required this.onSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isRegisterMode = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final error = _isRegisterMode
        ? await AuthService.register(widget.baseUrl, username, password)
        : await AuthService.login(widget.baseUrl, username, password);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error == null) {
      widget.onSuccess();
    } else {
      setState(() => _errorMessage = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _usernameController.text.trim().isNotEmpty && _passwordController.text.isNotEmpty;

    return ValueListenableBuilder<String>(
      valueListenable: AppStrings.locale,
      builder: (context, _, __) => Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), shape: BoxShape.circle),
                        child: const Icon(Icons.pets_rounded, color: Colors.white, size: 44),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'CatFeeder',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isRegisterMode ? AppStrings.t('create_account_subtitle') : AppStrings.t('welcome_subtitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                    ),
                    const SizedBox(height: 36),
                    Text(AppStrings.t('username_label'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 8),
                    _authField(
                      controller: _usernameController,
                      hint: AppStrings.t('your_name_hint'),
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 16),
                    Text(AppStrings.t('password_label'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 8),
                    _authField(
                      controller: _passwordController,
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white54, size: 20),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_isRegisterMode) ...[
                      const SizedBox(height: 8),
                      Text(AppStrings.t('password_hint_min'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                      ),
                    ],
                    const SizedBox(height: 22),
                    ElevatedButton(
                      onPressed: (_isSubmitting || !canSubmit) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                        shadowColor: Colors.transparent,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary))
                          : Text(_isRegisterMode ? AppStrings.t('create_account_button') : AppStrings.t('login_button')),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() {
                                  _isRegisterMode = !_isRegisterMode;
                                  _errorMessage = null;
                                }),
                        style: TextButton.styleFrom(foregroundColor: Colors.white70),
                        child: Text(_isRegisterMode ? AppStrings.t('have_account_question') : AppStrings.t('no_account_question')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _authField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: (_) => setState(() {}),
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
    );
  }
}
