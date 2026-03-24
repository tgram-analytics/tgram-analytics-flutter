import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _log = Logger('tgram_analytics');

/// Fire-and-forget async send. Logs errors, never throws.
Future<void> send(
  http.Client client,
  String url,
  Map<String, Object?> payload,
  Duration timeout,
) async {
  try {
    final response = await client
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(timeout);
    if (response.statusCode >= 400) {
      _log.warning('tgram-analytics: $url returned ${response.statusCode}');
    }
  } catch (e) {
    _log.fine('tgram-analytics: failed to send to $url: $e');
  }
}
