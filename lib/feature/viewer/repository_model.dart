import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';

class Repository {
  static final _url = Uri.parse('https://graphql.anilist.co');

  Repository(String? accessToken)
    : _headers = {
        'Accept': 'application/json',
        'Content-type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  final Map<String, String> _headers;

  Future<Map<String, dynamic>> request(
    String query, [
    Map<String, dynamic> variables = const {},
  ]) async {
    final maxAttempts = query.trimLeft().startsWith('mutation') ? 1 : 3;

    for (var attempt = 1; ; attempt++) {
      final isLast = attempt >= maxAttempts;

      try {
        final response = await post(
          _url,
          body: json.encode({'query': query, 'variables': variables}),
          headers: _headers,
        ).timeout(const Duration(seconds: 30));

        Object? decoded;
        try {
          decoded = json.decode(response.body);
        } on FormatException {
          decoded = null; // an HTML error page instead of JSON
        }

        final body = decoded is Map<String, dynamic> ? decoded : null;
        final status = response.statusCode;

        if (body == null || status == 429 || status >= 500) {
          if (isLast) {
            throw Exception(
              status == 429
                  ? 'Too many requests, please wait a moment'
                  : 'AniList is not responding properly (HTTP $status)',
            );
          }
          final wait = (int.tryParse(response.headers['retry-after'] ?? '') ?? attempt)
              .clamp(1, 5)
              .toInt();
          await Future.delayed(Duration(seconds: wait));
          continue;
        }

        if (body.containsKey('errors')) {
          throw StateError((body['errors'] as List).map((e) => e['message'].toString()).join(', '));
        }

        return body['data'];
      } on SocketException {
        if (isLast) throw Exception('Failed to connect');
        await Future.delayed(Duration(seconds: attempt));
      } on TimeoutException {
        if (isLast) throw Exception('Request took too long');
      }
    }
  }
}
