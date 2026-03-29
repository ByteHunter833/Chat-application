import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../repositories/auth_repository.dart';
import '../theme/app_theme.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = true;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);
    if (_isSignUp) {
      await controller.signUp(
        name: _nameController.text.trim(),
        username: AuthRepository.normalizeUsername(_usernameController.text),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      return;
    }

    await controller.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      final error = next.error;
      if (error == null ||
          !mounted ||
          previous?.error.toString() == error.toString()) {
        return;
      }

      final message = switch (error) {
        UsernameAlreadyTakenException() =>
          'This @username is already taken. Try another one.',
        AuthFlowException(:final message) => message,
        _ => 'Authentication failed. Please try again.',
      };

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AuthHero(isDark: isDark),
              const SizedBox(height: AppTheme.spacingXl),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: isDark
                      ? AppTheme.darkShadow
                      : AppTheme.lightShadow,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isSignUp ? 'Create account' : 'Welcome back',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      Text(
                        _isSignUp
                            ? 'Reserve a unique username and start chatting with people already in the app.'
                            : 'Sign in with the email you used when creating your account.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingLg),
                      Row(
                        children: [
                          Expanded(
                            child: _ModeChip(
                              label: 'Create',
                              isSelected: _isSignUp,
                              onTap: () => setState(() => _isSignUp = true),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingSm),
                          Expanded(
                            child: _ModeChip(
                              label: 'Sign in',
                              isSelected: !_isSignUp,
                              onTap: () => setState(() => _isSignUp = false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingLg),
                      if (_isSignUp) ...[
                        _buildField(
                          controller: _nameController,
                          label: 'Full name',
                          hint: 'John Carter',
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().length < 2) {
                              return 'Enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        _buildField(
                          controller: _usernameController,
                          label: 'Username',
                          hint: '@johnc',
                          prefixText: '@',
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9_]'),
                            ),
                          ],
                          helper:
                              'Lowercase, unique, 5-24 chars. People can find you by this handle.',
                          validator: (value) {
                            final username = AuthRepository.normalizeUsername(
                              value ?? '',
                            );
                            final regex = RegExp(r'^[a-z0-9_]{5,24}$');
                            if (!regex.hasMatch(username)) {
                              return 'Use 5-24 letters, numbers, or _';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                      ],
                      _buildField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (!email.contains('@') || !email.contains('.')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      _buildField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Minimum 6 characters',
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if ((value ?? '').trim().length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: AppTheme.spacingLg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacingSm,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _isSignUp ? 'Create account' : 'Sign in',
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppTheme.spacingMd),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                        ),
                        child: Text(
                          'Only users already registered in this app can be found and messaged. Search works by @username, just like Telegram.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.primaryDark,
                                height: 1.5,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    String? helper,
    String? prefixText,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppTheme.spacingSm),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          obscureText: obscureText,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          decoration: InputDecoration(hintText: hint, prefixText: prefixText),
        ),
        if (helper != null) ...[
          const SizedBox(height: AppTheme.spacingXs),
          Text(helper, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF133B82), Color(0xFF0B1A3B)]
              : const [Color(0xFF2563EB), Color(0xFF06B6D4)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(
              Icons.alternate_email_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text(
            'Own your handle.\nChat by username.',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Create a unique @username, discover people inside the app, and open direct chats instantly.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary
              : (isDark ? AppTheme.darkTertiary : AppTheme.lightTertiary),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
