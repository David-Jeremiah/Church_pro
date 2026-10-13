import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

/// Asks the `summarizeBudget` Cloud Function for a plain-language summary.
/// The AI key lives only on the server, never in the app.
class BudgetAiService {
  /// Only set this if your function URL is not the usual
  /// https://us-central1-<project>.cloudfunctions.net/summarizeBudget
  static const String? urlOverride = null;

  Future<String> summarize({required String churchId, required String budgetId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Please sign in again');
    final token = await user.getIdToken();

    final url = urlOverride ??
        'https://us-central1-${Firebase.app().options.projectId}.cloudfunctions.net/summarizeBudget';

    final http.Response response;
    try {
      response = await http
          .post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'churchId': churchId, 'budgetId': budgetId}),
      )
          .timeout(const Duration(seconds: 70));
    } catch (_) {
      throw Exception('Could not reach the AI service. Check your internet connection.');
    }

    if (response.statusCode == 404) {
      throw Exception('The AI summary is not set up yet. Deploy the summarizeBudget function first.');
    }
    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}
    if (response.statusCode != 200) {
      throw Exception(body['error'] ?? 'Could not create the summary (${response.statusCode}).');
    }
    return (body['summary'] as String?) ?? '';
  }
}