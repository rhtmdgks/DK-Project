import 'dart:convert';
import 'dart:io';

import 'package:dnslib/dnslib.dart';

const _googleDnsHost = '8.8.8.8';
const _googleDnsPort = 53;

/// Resolves [host] using Google DNS (8.8.8.8). Returns first IPv4 address or null.
Future<String?> resolveHostViaGoogleDns(String host) async {
  try {
    final records = await DNSClient.query(
      domain: host,
      dnsRecordType: DNSRecordTypes.findByName('A'),
      dnsServer: DNSServer(host: _googleDnsHost, port: _googleDnsPort),
      timeout: 5000,
    );
    for (final r in records) {
      final addr = r.representation;
      if (addr.isNotEmpty && _isIPv4(addr)) return addr;
    }
    return null;
  } catch (_) {
    return null;
  }
}

bool _isIPv4(String s) {
  final parts = s.split('.');
  if (parts.length != 4) return false;
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0 || n > 255) return false;
  }
  return true;
}

/// Calls Supabase login_from_profiles RPC using [baseUrl] and [anonKey],
/// connecting to [resolvedIp] instead of hostname (bypasses system DNS).
/// Returns the same JSON-decoded response as the normal RPC, or throws.
Future<Map<String, dynamic>> loginRpcViaResolvedIp({
  required String baseUrl,
  required String anonKey,
  required String resolvedIp,
  required String studentId,
  required String password,
}) async {
  final uri = Uri.parse('$baseUrl/rest/v1/rpc/login_from_profiles');
  final host = uri.host;

  final client = HttpClient()
    ..connectionFactory = (Uri u, String? proxyHost, int? proxyPort) async {
      final targetHost = u.host;
      final targetPort = u.port;
      final connectHost = (targetHost == host) ? resolvedIp : targetHost;
      return ConnectionTask.fromSocket(
        Socket.connect(connectHost, targetPort),
        () {},
      );
    };

  try {
    final request = await client.postUrl(uri);
    request.headers.set('apikey', anonKey);
    request.headers.set('Authorization', 'Bearer $anonKey');
    request.headers.set('Content-Type', 'application/json');
    request.write(jsonEncode({
      'p_student_id': studentId,
      'p_password': password,
    }));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw Exception('RPC failed: ${response.statusCode} $body');
    }
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    return decoded;
  } finally {
    client.close();
  }
}
