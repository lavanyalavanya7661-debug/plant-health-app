import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
 
import 'main.dart' show ScannerScreen;
import 'login_screen.dart';
 
/// Signed in      -> scanner
/// Not signed in  -> phone number + OTP login
/// Firebase remembers the user, so they stay signed in after closing the app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
 
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.hasData ? const ScannerScreen() : const LoginScreen();
      },
    );
  }
}
 