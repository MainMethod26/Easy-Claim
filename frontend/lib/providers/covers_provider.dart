import 'package:flutter/foundation.dart';
import '../data/models/api_models.dart';
import '../data/repositories/repositories.dart';

/// Covers tab state. "My Covers" is the customer's real policies (GET /covers/my-covers).
/// "All Covers" is a static insurer showcase in the screen, not business state.
class CoversProvider with ChangeNotifier {
  final CoversRepository _repo;

  CoversProvider({CoversRepository? repository, bool autoLoad = true}) : _repo = repository ?? CoversRepository() {
    if (autoLoad) refresh();
  }

  List<Policy> _policies = const [];
  bool _isLoading = false;
  Object? _error;
  int _selectedTabIndex = 0;

  List<Policy> get myPolicies => _policies;
  bool get isLoading => _isLoading;
  Object? get error => _error;
  int get selectedTabIndex => _selectedTabIndex;

  /// [quiet] (live updates): no loading state, and a failed reload keeps the current list.
  Future<void> refresh({bool quiet = false}) async {
    if (!quiet) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    try {
      _policies = await _repo.myPolicies();
      _error = null;
    } catch (e) {
      if (!quiet) _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setTabIndex(int index) {
    if (_selectedTabIndex != index) {
      _selectedTabIndex = index;
      notifyListeners();
    }
  }
}
