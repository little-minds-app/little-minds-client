// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import '../child_profiles/child_profiles_controller.dart';
import '../auth/parent_auth_controller.dart';
import 'mission_status_repository.dart';
import 'mission_status_view_data.dart';
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

enum MissionStatusPhase {
  initial,
  loading,
  loaded,
  empty,
  unavailable,
}

/// Loads and presents canonical session KPIs for the selected child (LMP-53).
class ParentDashboardController extends ChangeNotifier {
  ParentDashboardController({
    required SessionKpiRepository repository,
    required MissionStatusRepository missionRepository,
    required ParentAuthController auth,
    required ChildProfilesController profiles,
    SessionKpiWindow Function()? windowBuilder,
  })  : _repository = repository,
        _missionRepository = missionRepository,
        _auth = auth,
        _profiles = profiles,
        _windowBuilder = windowBuilder ?? SessionKpiWindow.recentSevenDaysPlusToday {
    _auth.addListener(_invalidate);
    _profiles.addListener(_invalidateSelection);
  }

  final SessionKpiRepository _repository;
  final MissionStatusRepository _missionRepository;
  final ParentAuthController _auth;
  final ChildProfilesController _profiles;
  final SessionKpiWindow Function() _windowBuilder;

  ParentDashboardPhase _phase = ParentDashboardPhase.initial;
  ParentDashboardViewData? _view;
  SessionKpiFailure? _failure;
  MissionStatusPhase _missionPhase = MissionStatusPhase.initial;
  MissionStatusViewData? _missionView;
  MissionStatusFailure? _missionFailure;
  String? _parentId;
  String? _sessionId;
  String? _childId;
  int _generation = 0;
  bool _needsChildSelection = false;

  ParentDashboardPhase get phase => _phase;
  ParentDashboardViewData? get view => _view;
  SessionKpiFailure? get failure => _failure;
  MissionStatusPhase get missionPhase => _missionPhase;
  MissionStatusViewData? get missionView => _missionView;
  MissionStatusFailure? get missionFailure => _missionFailure;
  bool get needsChildSelection => _needsChildSelection;

  /// Shown when mission status cannot be loaded from the server (fail-closed).
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
      _resetMissionState();
      notifyListeners();
      return;
    }
    if (_profiles.children.isEmpty) {
      _needsChildSelection = true;
      _phase = ParentDashboardPhase.initial;
      _view = null;
      _failure = null;
      _resetMissionState();
      notifyListeners();
      return;
    }
    _needsChildSelection = false;
    await _fetchForChild(selected ?? _profiles.selectedId);
  }

  Future<void> refresh() => load();

  Future<void> _fetchForChild(String? childId) async {
    final generation = ++_generation;
    final boundParentId = _auth.session?.parentId;
    final boundSessionId = _auth.session?.sessionId;
    final boundChildId = childId;
    _parentId = boundParentId;
    _sessionId = boundSessionId;
    _childId = boundChildId;
    _phase = ParentDashboardPhase.loading;
    _failure = null;
    _view = null;
    _missionPhase = MissionStatusPhase.loading;
    _missionView = null;
    _missionFailure = null;
    notifyListeners();

    final window = _windowBuilder();
    if (boundChildId != null) {
      // ignore: discarded_futures
      _fetchMission(
        generation: generation,
        window: window,
        childId: boundChildId,
        boundParentId: boundParentId,
        boundSessionId: boundSessionId,
      );
    } else {
      _resetMissionState();
    }

    try {
      final response = await _repository.fetch(
        window: window,
        childId: childId,
      );
      if (!_stillCurrent(
        generation,
        boundParentId: boundParentId,
        boundSessionId: boundSessionId,
        boundChildId: boundChildId,
      )) {
        return;
      }
      final mapped = mapSessionKpiToView(response);
      _view = mapped;
      _phase = mapped.isEmpty ? ParentDashboardPhase.empty : ParentDashboardPhase.loaded;
      notifyListeners();
    } catch (error) {
      if (!_stillCurrent(
        generation,
        boundParentId: boundParentId,
        boundSessionId: boundSessionId,
        boundChildId: boundChildId,
      )) {
        return;
      }
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

  Future<void> _fetchMission({
    required int generation,
    required SessionKpiWindow window,
    required String childId,
    required String? boundParentId,
    required String? boundSessionId,
  }) async {
    try {
      final response = await _missionRepository.fetch(
        childId: childId,
        window: window,
      );
      if (!_stillCurrent(
        generation,
        boundParentId: boundParentId,
        boundSessionId: boundSessionId,
        boundChildId: childId,
      )) {
        return;
      }
      final mapped = mapMissionStatusToView(response);
      _missionView = mapped;
      _missionFailure = null;
      _missionPhase =
          mapped.isEmpty ? MissionStatusPhase.empty : MissionStatusPhase.loaded;
      notifyListeners();
    } catch (error) {
      if (!_stillCurrent(
        generation,
        boundParentId: boundParentId,
        boundSessionId: boundSessionId,
        boundChildId: childId,
      )) {
        return;
      }
      _missionView = null;
      _missionFailure = mapMissionStatusException(error);
      _missionPhase = MissionStatusPhase.unavailable;
      notifyListeners();
    }
  }

  bool _stillCurrent(
    int generation, {
    required String? boundParentId,
    required String? boundSessionId,
    required String? boundChildId,
  }) {
    if (generation != _generation) return false;
    final session = _auth.session;
    if (session == null) return false;
    if (session.parentId != boundParentId) return false;
    if (session.sessionId != boundSessionId) return false;
    if (boundChildId != null && _profiles.selectedId != boundChildId) return false;
    return true;
  }

  void _invalidate() {
    final session = _auth.session;
    if (session == null) {
      if (_parentId == null && _sessionId == null) return;
      _generation++;
      _parentId = null;
      _sessionId = null;
      _childId = null;
      _view = null;
      _failure = null;
      _resetMissionState();
      _phase = ParentDashboardPhase.unauthorized;
      _needsChildSelection = false;
      notifyListeners();
      return;
    }
    final newParent = session.parentId;
    final newSession = session.sessionId;
    if (newParent == _parentId && newSession == _sessionId) return;
    _generation++;
    _parentId = newParent;
    _sessionId = newSession;
    _childId = null;
    _view = null;
    _failure = null;
    _resetMissionState();
    _phase = ParentDashboardPhase.initial;
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
    _resetMissionState();
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
    _parentId = null;
    _sessionId = null;
    _childId = null;
    _view = null;
    _failure = null;
    _resetMissionState();
    _phase = phase;
    _needsChildSelection = false;
    notifyListeners();
  }

  void _resetMissionState() {
    _missionPhase = MissionStatusPhase.initial;
    _missionView = null;
    _missionFailure = null;
  }

  @override
  void dispose() {
    _auth.removeListener(_invalidate);
    _profiles.removeListener(_invalidateSelection);
    super.dispose();
  }
}
