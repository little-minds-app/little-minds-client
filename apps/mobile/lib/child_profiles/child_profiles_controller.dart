// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:little_minds_api/api.dart';

import '../auth/parent_auth_controller.dart';
import 'child_profile_repository.dart';

/// Parent-scoped, in-memory selection. Never persists a child ID across logout.
class ChildProfilesController extends ChangeNotifier {
  ChildProfilesController({
    required ChildProfileRepository repository,
    required ParentAuthController auth,
  })  : _repository = repository,
        _auth = auth,
        _parentId = auth.session?.parentId {
    auth.addListener(_onAuthChanged);
  }

  final ChildProfileRepository _repository;
  final ParentAuthController _auth;
  String? _parentId;
  List<ChildProfileResponse> _children = const [];
  String? _selectedId;
  String? _error;
  bool _busy = false;
  bool _loaded = false;
  int _generation = 0;

  List<ChildProfileResponse> get children => List.unmodifiable(_children);
  String? get selectedId => _selectedId;
  ChildProfileResponse? get selected {
    for (final child in _children) {
      if (child.childId == _selectedId) return child;
    }
    return null;
  }

  bool get busy => _busy;
  bool get loaded => _loaded;
  String? get error => _error;
  bool get isAuthenticated => _auth.session != null;

  void _onAuthChanged() {
    final newParent = _auth.session?.parentId;
    if (newParent == _parentId) return;
    _parentId = newParent;
    _generation++;
    _busy = false;
    _children = const [];
    _selectedId = null;
    _error = null;
    _loaded = false;
    notifyListeners();
  }

  Future<void> load() async {
    if (_busy) return;
    if (!isAuthenticated) {
      _children = const [];
      _selectedId = null;
      _loaded = true;
      _error = 'Ebeveyn girişi gerekli.';
      notifyListeners();
      return;
    }
    final generation = _generation;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final latest = await _repository.list();
      if (generation != _generation) return;
      _children = latest;
      if (!_children.any((child) => child.childId == _selectedId)) {
        _selectedId = null;
      }
      _loaded = true;
    } catch (_) {
      if (generation == _generation) {
        _error = 'Profiller alınamadı. Yeniden deneyin.';
      }
    } finally {
      if (generation == _generation) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  void select(String childId) {
    if (!_children.any((child) => child.childId == childId)) return;
    _selectedId = childId;
    notifyListeners();
  }

  /// Istanbul's UTC+3 civil date; the server uses the same reference timezone.
  DateTime todayReference([DateTime? now]) {
    final istanbul = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 3));
    return DateTime.utc(istanbul.year, istanbul.month, istanbul.day);
  }

  Future<bool> save({
    String? childId,
    required String nickname,
    required int ageMonths,
  }) async {
    if (!isAuthenticated || _busy) return false;
    if (ageMonths < 0 || ageMonths > 2147483647 || nickname.length > 80) {
      _error = 'Geçerli bir yaş ve takma ad girin.';
      notifyListeners();
      return false;
    }
    final generation = _generation;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final date = todayReference();
      if (childId == null) {
        final createdId = await _repository.create(
          ageMonths: ageMonths, nickname: nickname, referenceDate: date,
        );
        if (generation != _generation) return false;
        _selectedId = createdId;
      } else {
        if (!_children.any((child) => child.childId == childId)) return false;
        await _repository.edit(
          childId: childId, ageMonths: ageMonths, nickname: nickname, referenceDate: date,
        );
        if (generation != _generation) return false;
      }
      final latest = await _repository.list();
      if (generation != _generation) return false;
      _children = latest;
      if (!_children.any((child) => child.childId == _selectedId)) _selectedId = null;
      _loaded = true;
      return true;
    } catch (_) {
      if (generation == _generation) {
        _error = 'Profil kaydedilemedi. Yeniden deneyin.';
      }
      return false;
    } finally {
      if (generation == _generation) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
