import 'package:flutter/foundation.dart';
import '../data/models/api_models.dart';
import '../data/repositories/repositories.dart';

/// Home screen state: the signed-in customer's claims from the backend (GET /claims), with the
/// most recent one expanded (GET /claims/:id + /timeline). No sample data: if the API fails,
/// [error] is set and the screen shows an error with retry.
class HomeScreenProvider with ChangeNotifier {
  final ClaimsRepository _claims;

  HomeScreenProvider({ClaimsRepository? claims, bool autoLoad = true}) : _claims = claims ?? ClaimsRepository() {
    if (autoLoad) refresh();
  }

  bool _isLoading = false;
  Object? _error;
  List<ClaimSummary> _list = const [];
  ClaimDetail? _primary;
  ClaimTimeline? _timeline;

  bool get isLoading => _isLoading;
  Object? get error => _error;
  List<ClaimSummary> get claims => _list;
  ClaimDetail? get primaryClaim => _primary;
  ClaimTimeline? get primaryTimeline => _timeline;

  /// Claims that need something from the customer (draft, info needed, rejected decision).
  int get actionCount => _list
      .where((c) => c.stage == 'Draft' || c.stage == 'Info Needed' || (c.stage == 'Decision' && c.status == 'Rejected'))
      .length;

  /// [quiet] (live updates): keep showing the current claims while reloading, and keep them if
  /// the reload fails.
  Future<void> refresh({bool quiet = false}) async {
    if (!quiet) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final list = await _claims.list();
      ClaimDetail? primary;
      ClaimTimeline? timeline;
      if (list.isNotEmpty) {
        final latest = list.first; // newest first
        final results = await Future.wait<Object>([_claims.detail(latest.id), _claims.timeline(latest.id)]);
        primary = results[0] as ClaimDetail;
        timeline = results[1] as ClaimTimeline;
      }
      _list = list;
      _primary = primary;
      _timeline = timeline;
      _error = null;
    } catch (e) {
      if (!quiet) _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
