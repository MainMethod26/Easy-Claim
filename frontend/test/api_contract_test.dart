import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Contract check across the three places an admin route lives:
//   backend/src/endpoints/admin.ts  (what the server mounts)
//   docs/API_CONTRACT.md            (the agreed contract)
//   lib/data/repositories/admin_repositories.dart  (what the app calls)
// Every mounted admin/tenant route must be documented with the same method, and every app
// call must hit a documented route with that method. Role, tenant and response shapes are
// asserted by backend/test/roleMatrix.test.ts, adminMetrics.test.ts and test/console_test.dart.

String _read(String path) => File(path).readAsStringSync();

/// `$userId` / `${x}` path segments become `:userId`; query strings are dropped.
String _normalise(String path) {
  final p = path.split('?').first.replaceAllMapped(RegExp(r'\$\{?(\w+)\}?'), (m) => ':${m[1]}');
  return p.length > 1 && p.endsWith('/') ? p.substring(0, p.length - 1) : p;
}

Set<String> _documented() {
  final out = <String>{};
  final row = RegExp(r'^\|\s*(GET|POST|PUT|PATCH|DELETE)\s+`([^`?]+)', multiLine: true);
  for (final m in row.allMatches(_read('../docs/API_CONTRACT.md'))) {
    out.add('${m[1]} ${_normalise(m[2]!.trim())}');
  }
  return out;
}

void main() {
  final documented = _documented();

  test('every admin/tenant route the backend mounts is in docs/API_CONTRACT.md', () {
    final source = _read('../backend/src/endpoints/admin.ts');
    final mounts = {'superadmin': '/admin', 'tenantAdmin': '/tenant'};
    final routes = RegExp(r"^(superadmin|tenantAdmin)\.(get|post|put|patch|delete)\('([^']*)'", multiLine: true)
        .allMatches(source)
        .map((m) => '${m[2]!.toUpperCase()} ${_normalise('${mounts[m[1]]}${m[3] == '/' ? '' : m[3]}')}')
        .toSet();
    expect(routes, isNotEmpty);
    expect(routes, containsAll(['GET /admin/overview', 'GET /admin/security', 'GET /admin/integrity', 'GET /admin/audit', 'GET /tenant/overview', 'GET /tenant/audit']));
    final missing = routes.difference(documented);
    expect(missing, isEmpty, reason: 'Mounted but undocumented: $missing');
  });

  test('every admin repository call targets a documented route with the same method', () {
    final source = _read('lib/data/repositories/admin_repositories.dart');
    final calls = <String>{};
    for (final m in RegExp(r"_api\.(get|post|put|patch|delete)\(").allMatches(source)) {
      // All string literals in the call's argument list up to the first ';' (covers ternaries).
      final tail = source.substring(m.end, source.indexOf(';', m.end));
      for (final lit in RegExp(r"'(/[^']*)'").allMatches(tail)) {
        calls.add('${m[1]!.toUpperCase()} ${_normalise(lit[1]!)}');
      }
    }
    expect(calls, containsAll(['GET /tenant/overview', 'GET /tenant/audit', 'GET /admin/overview', 'GET /admin/audit']));
    final missing = calls.difference(documented);
    expect(missing, isEmpty, reason: 'Called by the app but not in the contract: $missing');
  });
}
