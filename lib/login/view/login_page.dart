import 'package:crm_repository/crm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:auto_sms/l10n/l10n.dart';
import 'package:auto_sms/login/cubit/login_cubit.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginCubit(repository: context.read<CrmRepository>()),
      child: const LoginView(),
    );
  }
}

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _getLocalizedError(BuildContext context, String rawError) {
    final l10n = context.l10n;
    switch (rawError) {
      case 'errorNoInternet':
        return l10n.errorNoInternet;
      case 'errorInvalidCredentials':
        return l10n.errorInvalidCredentials;
      case 'errorUserAlreadyRegistered':
        return l10n.errorUserAlreadyRegistered;
      case 'errorWeakPassword':
        return l10n.errorWeakPassword;
      case 'errorRateLimit':
        return l10n.errorRateLimit;
      case 'errorUnexpected':
        return l10n.errorUnexpected;
      default:
        return rawError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: BlocConsumer<LoginCubit, LoginState>(
        listener: (context, state) {
          if (state is LoginError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_getLocalizedError(context, state.message)),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is LoginSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.loginSuccessMessage),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is LoginLoading;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_person, size: 100, color: Colors.blue),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.emailLabel,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.passwordLabel,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    ElevatedButton(
                      onPressed: () {
                        context.read<LoginCubit>().signIn(
                              email: _emailController.text.trim(),
                              password: _passwordController.text.trim(),
                            );
                      },
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                      child: Text(l10n.signInButton, style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        context.read<LoginCubit>().signUp(
                              email: _emailController.text.trim(),
                              password: _passwordController.text.trim(),
                            );
                      },
                      child: Text(l10n.signUpButton),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}