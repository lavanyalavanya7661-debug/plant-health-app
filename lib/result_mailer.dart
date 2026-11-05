import 'dart:convert';
 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
 
import 'care_tips.dart';
import 'classifier.dart';
 
// ---- Paste your three values from the EmailJS dashboard here ----
const String kEmailJsServiceId = 'service_8i154gb';
const String kEmailJsTemplateId = 'template_x7hsm79';
const String kEmailJsPublicKey = '6_Y9tTNYnh0Swic8r';   // from this step
// ------------------------------------------------------------------
 
/// Emails the scan result to the signed-in user using EmailJS (free plan:
/// about 200 emails a month). No server or paid Firebase plan needed.
class ResultMailer {
  /// Returns the user's email: from the account, else the one saved on this
  /// phone, else asks once and saves it. Null if the user skips.
  Future<String?> emailFor(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
 
    final authEmail = user.email;
    if (authEmail != null && authEmail.isNotEmpty) return authEmail;
 
    final prefs = await SharedPreferences.getInstance();
    final key = 'result_email_${user.uid}';
    final saved = prefs.getString(key);
    if (saved != null && saved.isNotEmpty) return saved;
 
    if (!context.mounted) return null;
    final asked = await _askEmail(context);
    if (asked != null) await prefs.setString(key, asked);
    return asked;
  }
 
  Future<String?> _askEmail(BuildContext context) {
    final controller = TextEditingController();
    String? error;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Email your results?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your email and we will send every scan '
                  'result to it.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () {
                final t = controller.text.trim();
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                  setState(() => error = 'Enter a valid email');
                  return;
                }
                Navigator.pop(ctx, t);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
 
  /// Sends the result email. Throws if EmailJS rejects the request.
  Future<void> sendResult(
    String email,
    List<Prediction> predictions, {
    required double threshold,
  }) async {
    final top = predictions.first;
    final confident = top.confidence >= threshold && !top.isOther;
    final percent = (top.confidence * 100).toStringAsFixed(0);
    final when = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${two(when.day)}-${two(when.month)}-${when.year} '
        '${two(when.hour)}:${two(when.minute)}';
 
    late final String subject;
    late final String headline;
    late final String detail;
    if (top.isOther && top.confidence >= threshold) {
      subject = 'Plant scan: not one of the supported crops';
      headline = 'Not one of my crops';
      detail = 'The photo does not look like a leaf of a supported crop.';
    } else if (!confident) {
      subject = 'Plant scan: not sure about this leaf';
      headline = "I'm not sure about this one";
      detail = 'Try again with a single leaf, in daylight, close up and sharp.';
    } else if (top.isHealthy) {
      subject = 'Plant scan: ${top.crop} looks healthy ($percent%)';
      headline = '${top.crop}: looks healthy';
      detail = careTipFor(top.condition);
    } else {
      subject = 'Plant scan: ${top.crop} - ${top.condition} ($percent%)';
      headline = '${top.crop}: likely ${top.condition}';
      detail = careTipFor(top.condition);
    }
 
    final others = predictions
        .skip(1)
        .map((p) => '${p.crop} - ${p.condition} '
            '(${(p.confidence * 100).toStringAsFixed(0)}%)')
        .join('\n');
 
    final response = await http
        .post(
          Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
          headers: {
            'Content-Type': 'application/json',
            'origin': 'http://localhost', // EmailJS expects an origin header
          },
          body: jsonEncode({
            'service_id': kEmailJsServiceId,
            'template_id': kEmailJsTemplateId,
            'user_id': kEmailJsPublicKey,
            'template_params': {
              'to_email': email,
              'subject': subject,
              'headline': headline,
              'confidence': '$percent%',
              'scanned': stamp,
              'detail': detail,
              'others': others.isEmpty ? 'None' : others,
              'disclaimer':
                  'This is an AI estimate from a photo, not a certain diagnosis.',
            },
          }),
        )
        .timeout(const Duration(seconds: 20));
 
    if (response.statusCode != 200) {
      throw Exception('EmailJS error ${response.statusCode}: ${response.body}');
    }
  }
}