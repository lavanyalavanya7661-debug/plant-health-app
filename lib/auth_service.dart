import 'package:firebase_auth/firebase_auth.dart';
 
/// Thin wrapper around Firebase Authentication (email + password).
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
 
  User? get currentUser => _auth.currentUser;
 
  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
 
  Future<void> register(String email, String password) =>
      _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
 
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());
 
  Future<void> signOut() => _auth.signOut();
 
  // ---------------- Phone OTP (second step after email sign-in) ----------------
 
  /// True once a phone number has been verified and linked to the account.
  static bool hasPhone(User? u) => (u?.phoneNumber ?? '').isNotEmpty;
 
  /// Sends an SMS code. [phone] must include the country code, e.g. +919876543210.
  Future<void> sendOtp({
    required String phone,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    required void Function(FirebaseAuthException e) onFailed,
    int? resendToken,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phone.trim(),
      timeout: const Duration(seconds: 60),
      forceResendingToken: resendToken,
      verificationCompleted: onAutoVerified, // Android may read the SMS itself
      verificationFailed: onFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }
 
  PhoneAuthCredential credentialFor(String verificationId, String code) =>
      PhoneAuthProvider.credential(
          verificationId: verificationId, smsCode: code.trim());
 
  /// Signs the user in with a verified phone credential (phone + OTP login).
  Future<void> signInWithPhoneCredential(PhoneAuthCredential credential) =>
      _auth.signInWithCredential(credential);
 
  /// Links the verified phone number to the signed-in email account.
  Future<void> linkPhone(PhoneAuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');
    await user.linkWithCredential(credential);
    await user.reload();
  }
 
  /// Turns Firebase error codes into messages a farmer can understand.
  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'That email address does not look right.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'email-already-in-use':
          return 'An account with this email already exists. Try signing in.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        case 'network-request-failed':
          return 'No internet connection. Please try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a bit and try again.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'invalid-phone-number':
          return 'Enter the phone number with country code, e.g. +919876543210.';
        case 'invalid-verification-code':
          return 'That code is wrong. Check the SMS and try again.';
        case 'session-expired':
          return 'The code has expired. Tap "Resend code".';
        case 'credential-already-in-use':
        case 'provider-already-linked':
          return 'This phone number is already used by another account.';
        case 'quota-exceeded':
          return 'SMS limit reached. Please try again later.';
        case 'captcha-check-failed':
          return 'Security check failed. Please try again.';
      }
      return e.message ?? 'Sign-in failed (${e.code}).';
    }
    return 'Something went wrong: $e';
  }
}
 
