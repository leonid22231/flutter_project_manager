import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:project_manager/models/gitlab_check_result.dart';
import 'package:project_manager/models/gitlab_settings.dart';

class GitLabApiService {
  Future<GitLabCheckResult> checkConnection(GitLabSettings settings) async {
    final token = resolveToken(settings);
    if (token == null || token.isEmpty) {
      return const GitLabCheckResult(
        connected: false,
        error: 'Personal access token is not configured.',
      );
    }

    try {
      final response = await getJson(
        settings: settings,
        path: '/api/v4/user',
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final username = body['username'] as String? ??
            body['name'] as String? ??
            body['email'] as String?;
        return GitLabCheckResult(connected: true, username: username);
      }

      if (response.statusCode == 401) {
        return const GitLabCheckResult(
          connected: false,
          error: 'Invalid personal access token.',
        );
      }

      return GitLabCheckResult(
        connected: false,
        error: 'GitLab API error (${response.statusCode}).',
      );
    } catch (e) {
      return GitLabCheckResult(
        connected: false,
        error: '$e',
      );
    }
  }

  Future<http.Response> get({
    required GitLabSettings settings,
    required String path,
    Map<String, String>? query,
  }) async {
    return _request(
      settings: settings,
      method: 'GET',
      path: path,
      query: query,
    );
  }

  Future<http.Response> getRangeSuffix({
    required GitLabSettings settings,
    required String path,
    required int suffixBytes,
    Map<String, String>? query,
    int maxResponseBytes = 512000,
  }) async {
    return _request(
      settings: settings,
      method: 'GET',
      path: path,
      query: query,
      rangeSuffix: suffixBytes,
      maxResponseBytes: maxResponseBytes,
    );
  }

  Future<http.Response> getRange({
    required GitLabSettings settings,
    required String path,
    required int start,
    required int end,
    Map<String, String>? query,
    int? maxResponseBytes,
  }) async {
    return _request(
      settings: settings,
      method: 'GET',
      path: path,
      query: query,
      rangeStart: start,
      rangeEnd: end,
      maxResponseBytes: maxResponseBytes,
    );
  }

  Future<http.Response> getJson({
    required GitLabSettings settings,
    required String path,
    Map<String, String>? query,
  }) async {
    return _request(
      settings: settings,
      method: 'GET',
      path: path,
      query: query,
      acceptJson: true,
    );
  }

  Future<http.Response> getBytes({
    required GitLabSettings settings,
    required String path,
    Map<String, String>? query,
    int? maxResponseBytes,
  }) async {
    return _request(
      settings: settings,
      method: 'GET',
      path: path,
      query: query,
      acceptJson: false,
      maxResponseBytes: maxResponseBytes,
    );
  }

  Future<http.Response> postJson({
    required GitLabSettings settings,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    return _request(
      settings: settings,
      method: 'POST',
      path: path,
      query: query,
      body: body,
    );
  }

  Future<http.Response> _request({
    required GitLabSettings settings,
    required String method,
    required String path,
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool acceptJson = false,
    int? rangeSuffix,
    int? rangeStart,
    int? rangeEnd,
    int? maxResponseBytes,
  }) async {
    final token = resolveToken(settings);
    if (token == null || token.isEmpty) {
      throw StateError('Personal access token is not configured.');
    }

    final uri = Uri.parse('${settings.normalizedBaseUrl}$path').replace(
      queryParameters: query,
    );

    final headers = {
      'PRIVATE-TOKEN': token,
      if (acceptJson) 'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (rangeSuffix != null) 'Range': 'bytes=-$rangeSuffix',
      if (rangeStart != null && rangeEnd != null)
        'Range': 'bytes=$rangeStart-$rangeEnd',
    };

    if (method == 'POST') {
      return http
          .post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
    }

    if (maxResponseBytes != null) {
      return _getWithRedirectAndByteLimit(
        uri: uri,
        headers: headers,
        maxBytes: maxResponseBytes,
      );
    }

    return http.get(uri, headers: headers).timeout(const Duration(seconds: 60));
  }

  Future<http.Response> _getWithRedirectAndByteLimit({
    required Uri uri,
    required Map<String, String> headers,
    required int maxBytes,
  }) async {
    var requestUri = uri;
    var requestHeaders = Map<String, String>.from(headers);

    for (var redirect = 0; redirect < 5; redirect++) {
      final request = http.Request('GET', requestUri)..headers.addAll(requestHeaders);
      final streamed = await request.send().timeout(const Duration(seconds: 60));

      final statusCode = streamed.statusCode;
      if (statusCode == 301 ||
          statusCode == 302 ||
          statusCode == 303 ||
          statusCode == 307 ||
          statusCode == 308) {
        final location = streamed.headers['location'];
        await streamed.stream.drain();
        if (location == null || location.isEmpty) {
          return http.Response('', statusCode, headers: streamed.headers);
        }

        requestUri = Uri.parse(location);
        requestHeaders = Map<String, String>.from(headers);
        continue;
      }

      final chunks = <List<int>>[];
      var total = 0;
      await for (final chunk in streamed.stream) {
        total += chunk.length;
        if (total > maxBytes) {
          await streamed.stream.drain();
          return http.Response('', 413, headers: streamed.headers);
        }
        chunks.add(chunk);
      }

      final bytes = chunks.expand((chunk) => chunk).toList(growable: false);
      return http.Response.bytes(
        bytes,
        statusCode,
        headers: streamed.headers,
      );
    }

    return http.Response('', 508);
  }

  Future<String?> getJsonBody({
    required GitLabSettings settings,
    required String path,
    Map<String, String>? query,
  }) async {
    final response = await get(
      settings: settings,
      path: path,
      query: query,
    );
    if (response.statusCode != 200) return null;
    return response.body;
  }

  String? resolveToken(GitLabSettings settings) {
    if (settings.useEnvironmentToken) {
      final envToken = Platform.environment['GITLAB_TOKEN'] ??
          Platform.environment['GITLAB_PRIVATE_TOKEN'];
      if (envToken != null && envToken.trim().isNotEmpty) {
        return envToken.trim();
      }
    }
    final token = settings.personalAccessToken.trim();
    return token.isEmpty ? null : token;
  }

  String encodeProjectPath(String projectPath) {
    return Uri.encodeComponent(projectPath);
  }
}
