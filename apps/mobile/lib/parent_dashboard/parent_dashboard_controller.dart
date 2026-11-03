// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import '../child_profiles/child_profiles_controller.dart';
import '../auth/parent_auth_controller.dart';
import 'parent_dashboard_view_data.dart';
import 'session_kpi_repository.dart';
import 'session_kpi_window.dart';

enum ParentDashboardPhase {
  initial,
  loading,
  loaded,
  empty,
  error,
  unauthorized,
  childNotFound,
}

/// Loads and presents canonical session KPIs for the selected child (LMP-53).
class ParentDashboardController extends ChangeNotifier {
  ParentDashboardController({
    required SessionKpiRepository repository,
    required ParentAuthController auth,
    required ChildProfilesController profiles,
    SessionKpiWindow Function()? windowBuilder,
  })  : _repository = repository,
        _auth = auth,
        _profiles = profiles,
        _windowBuilder = windowBuilder ?? SessionKpiWindow.recentSevenDaysPlusToday {
    _auth.addListener(_invalidate);
    _profiles.addListener(_invalidateSelection);
  }

  final SessionKpiRepository _repository;
  final ParentAuthController _auth;
  final ChildProfilesController _profiles;
  final SessionKpiWindow Function() _windowBuilder;

  ParentDashboardPhase _phase = ParentDashboardPhase.initial;
  ParentDashboardViewData? _view;
  SessionKpiFailure? _failure;
  String? _parentId;
  String? _childId;
  int _generation = 0;
  bool _needsChildSelection = false;

  ParentDashboardPhase get phase => _phase;
  ParentDashboardViewData? get view => _view;
  SessionKpiFailure? get failure => _failure;
  bool get needsChildSelection => _needsChildSelection;

  /// Mission status has no authoritative server API on main — always unavailable.
  static const missionStatusUnavailableMessage =
      'Görev durumu henüz sunucudan doğrulanamıyor';

  Future<void> load() async {
    if (_auth.session == null) {
      _resetForAuthLoss(ParentDashboardPhase.unauthorized);
      return;
    }
    await _profiles.load();
    if (_auth.session == null) {
      _resetForAuthLoss(ParentDashboardPhase.unauthorized);
      return;
    }
    final selected = _profiles.selectedId;
    if (selected == null && _profiles.children.isNotEmpty) {
      _needsChildSelection = true;
      _phase = ParentDashboardPhase.initial;
      _view = null;
      _failure = null;
      notifyListeners();
      return;
    }
    if (_profiles.children.isEmpty) {
      _needsChildSelection = true;
      _phase = ParentDashboardPhase.initial;
      _view = null;
      _failure = null;
      notifyListeners();
      return;
    }
    _needsChildSelection = false;
    await _fetchForChild(selected ?? _profiles.selectedId);
  }

  Future<void> refresh() => load();

  Future<void> _fetchForChild(String? childId) async {
    final generation = ++_generation;
    _parentId = _auth.session?.parentId;
    _childId = childId;
    _phase = ParentDashboardPhase.loading;
    _failure = null;
    _view = null;
    notifyListeners();

    final window = _windowBuilder();
    try {
      final response = await _repository.fetch(
        window: window,
        childId: childId,
      );
      if (!_stillCurrent(generation)) return;
      final mapped = mapSessionKpiToView(response);
      _view = mapped;
      _phase = mapped.isEmpty ? ParentDashboardPhase.empty : ParentDashboardPhase.loaded;
      notifyListeners();
    } catch (error) {
      if (!_stillCurrent(generation)) return;
      final failure = mapSessionKpiException(error);
      _failure = failure;
      _view = null;
      _phase = switch (failure) {
        SessionKpiUnauthorized() => ParentDashboardPhase.unauthorized,
        SessionKpiChildNotFound() => ParentDashboardPhase.childNotFound,
        _ => ParentDashboardPhase.error,
      };
      notifyListeners();
    }
  }

  bool _stillCurrent(int generation) {
    if (generation != _generation) return false;
    if (_auth.session?.parentId != _parentId) return false;
    if (_profiles.selectedId != _childId && _childId != null) {
      // Child changed mid-flight — drop stale payload.
      return false;
    }
    return true;
  }

  void _invalidate() {
    final newParent = _auth.session?.parentId;
    if (newParent == _parentId && _auth.session != null) return;
    _generation++;
    _parentId = newParent;
    _childId = null;
    _view = null;
    _failure = null;
    _phase = _auth.session == null
        ? ParentDashboardPhase.unauthorized
        : ParentDashboardPhase.initial;
    _needsChildSelection = false;
    notifyListeners();
  }

  void _invalidateSelection() {
    final selected = _profiles.selectedId;
    if (selected == _childId && _phase != ParentDashboardPhase.initial) return;
    _generation++;
    _childId = selected;
    _view = null;
    _failure = null;
    if (selected == null || _profiles.children.isEmpty) {
      _needsChildSelection = true;
      _phase = ParentDashboardPhase.initial;
      notifyListeners();
      return;
    }
    _needsChildSelection = false;
    // ignore: discarded_futures
    _fetchForChild(selected);
  }

  void _resetForAuthLoss(ParentDashboardPhase phase) {
    _generation++;
    _view = null;
    _failure = null;
    _phase = phase;
    _needsChildSelection = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_invalidate);
    _profiles.removeListener(_invalidateSelection);
    super.dispose();
  }
}
