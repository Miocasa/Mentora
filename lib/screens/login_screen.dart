import 'package:course/screens/signup_screen.dart';
import 'package:course/services/auth_service.dart';
import 'package:flutter/material.dart';

import 'package:course/generated/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final userCredential = await _authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      setState(() {
        _isLoading = false;
      });
      if (userCredential == null) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.loginFailed;
          // You might want to show more specific errors from AuthService
        });
      } else {
        // AuthGate will handle navigation to HomeScreen
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Access the current theme

    return Scaffold(
      // appBar: AppBar(title: const Text('Login')), // Removed AppBar for a cleaner look
      body: SafeArea( // Ensures content is not obscured by system UI
        child: Center( // Center the content on the screen
          child: SingleChildScrollView( // Allows scrolling if content overflows
            padding: const EdgeInsets.all(24.0), // Increased padding
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch, // Make buttons stretch
                children: <Widget>[
                  // App Logo (Optional)
                  // FlutterLogo(size: 80, style: FlutterLogoStyle.markOnly),
                  // const SizedBox(height: 24),

                  Text(
                    AppLocalizations.of(context)!.loginTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.loginSubtitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.loginEmailLabel,
                      hintText: AppLocalizations.of(context)!.loginEmailHint,
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder( // Added border
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty ||
                          !value.contains('@')) {
                        return AppLocalizations.of(context)!.loginEmailError;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16), // Increased spacing
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.loginPasswordLabel,
                      hintText: AppLocalizations.of(context)!.loginPasswordHint,
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder( // Added border
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      // TODO: Add suffixIcon for password visibility toggle
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.loginPasswordError;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  // "Forgot Password?" button aligned to the right
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: Implement Forgot Password functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLocalizations.of(context)!.loginForgotPasswordClicked),
                            ),
                        );
                      },
                      child: Text(AppLocalizations.of(context)!.loginForgotPassword),
                    ),
                  ),
                  const SizedBox(height: 24), // Increased spacing
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0), // Increased padding
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                            color: theme.colorScheme.error, fontSize: 14), // Use theme error color
                        textAlign: TextAlign.center,
                      ),
                    ),
                  _isLoading
                      ? Center(child: const CircularProgressIndicator()) // Center loader
                      : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16.0), // Taller button
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        )
                    ),
                    onPressed: _login,
                    child: Text(AppLocalizations.of(context)!.loginButton),
                  ),
                  const SizedBox(height: 16),
                  Row( // For "Don't have an account? Sign Up"
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.loginNoAccount,
                        style: theme.textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const SignUpScreen(),
                          ));
                        },
                        child: Text(AppLocalizations.of(context)!.loginSignUpLink, style: const TextStyle(fontWeight: FontWeight.bold),),
                      ),
                    ],
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
