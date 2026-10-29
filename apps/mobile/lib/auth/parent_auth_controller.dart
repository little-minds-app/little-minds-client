// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:little_minds_api/api.dart';

import 'auth_error.dart';
import 'auth_session.dart';
import 'openapi_enum_int.dart';
import 'parent_auth_repository.dart';

enum ParentAuthStep {
  onboarding,
  phoneEntry,
  phoneVerify,
  emailEntry,
  emailVerify,
  authenticated,
}

/// MVVM-style parent auth state for onboarding + OTP flows (LMP-37).
class ParentAuthController extends ChangeNotifier {
  ParentAuthController({required ParentAuthRepository repository})
      : _repository = repository;

  final ParentAuthRepository _repository;

  ParentAuthStep _step = ParentAuthStep.onboarding;
  bool _busy = false;
  AuthSession? _session;
  ParentMeResponse? _profile;
  String? _challengeId;
  int _resendAfterSeconds = 0;
  ParentAuthFailure? _lastError;

  ParentAuthStep get step => _step;
  bool get busy => _busy;
  bool get isAuthenticated => _session != null;
  AuthSession? get session => _session;
  ParentMeResponse? get profile => _profile;
  String? get challengeId => _challengeId;
  int get resendAfterSeconds => _resendAfterSeconds;
  ParentAuthFailure? get lastError => _lastError;

  Future<void> bootstrap() async {
    _lastError = null;
    final stored = await _repository.loadPersistedSession();
    if (stored == null) {
      _step = ParentAuthStep.onboarding;
      notifyListeners();
      return;
    }
    _busy = true;
    notifyListeners();
    try {
      await _activateSession(stored, validateRemote: true);
    } on ParentAuthFailure catch (e) {
      _lastError = e;
      _session = null;
      _profile = null;
      _step = ParentAuthStep.onboarding;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void showOnboarding() {
    _clearError();
    _step = ParentAuthStep.onboarding;
    notifyListeners();
  }

  void openPhoneFlow() {
    _clearError();
    _challengeId = null;
    _step = ParentAuthStep.phoneEntry;
    notifyListeners();
  }

  void openEmailFlow() {
    _clearError();
    _challengeId = null;
    _step = ParentAuthStep.emailEntry;
    notifyListeners();
  }

  Future<void> submitPhone(String phone) async {
    if (phone.trim().length < 5) {
      _lastError = const ParentAuthFailure(
        code: 'invalid_request',
        message: 'Enter a valid phone number.',
      );
      notifyListeners();
      return;
    }
    await _run(() async {
      final start = await _repository.startPhoneOtp(phone);
      _challengeId = start.challengeId;
      _resendAfterSeconds = openapiEnumInt(start.resendAfter);
      _step = ParentAuthStep.phoneVerify;
    });
  }

  Future<void> submitPhoneCode(String code) async {
    final challenge = _challengeId;
    if (challenge == null || !RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      _lastError = const ParentAuthFailure(
        code: 'invalid_request',
        message: 'Enter the 6-digit code.',
      );
      notifyListeners();
      return;
    }
    await _run(() async {
      final session = await _repository.verifyPhoneOtp(
        challengeId: challenge,
        code: code,
      );
      await _activateSession(session, validateRemote: false);
    });
  }

  Future<void> submitEmail(String email) async {
    if (!email.contains('@') || email.trim().length < 5) {
      _lastError = const ParentAuthFailure(
        code: 'invalid_request',
        message: 'Enter a valid email address.',
      );
      notifyListeners();
      return;
    }
    await _run(() async {
      final start = await _repository.startEmailOtp(email);
      _challengeId = start.challengeId;
      _resendAfterSeconds = openapiEnumInt(start.resendAfter);
      _step = ParentAuthStep.emailVerify;
    });
  }

  Future<void> submitEmailCode(String code) async {
    final challenge = _challengeId;
    if (challenge == null || !RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      _lastError = const ParentAuthFailure(
        code: 'invalid_request',
        message: 'Enter the 6-digit code.',
      );
      notifyListeners();
      return;
    }
    await _run(() async {
      final session = await _repository.verifyEmailOtp(
        challengeId: challenge,
        code: code,
      );
      await _activateSession(session, validateRemote: false);
    });
  }

  Future<void> logout() async {
    final current = _session;
    if (current == null) {
      _step = ParentAuthStep.onboarding;
      notifyListeners();
      return;
    }
    await _run(() async {
      await _repository.logout(current);
      _session = null;
      _profile = null;
      _challengeId = null;
      _step = ParentAuthStep.onboarding;
    });
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Widget tests that exercise Parent Settings navigation without live API.
  void seedAuthenticatedSessionForTests(AuthSession session) {
    _session = session;
    _step = ParentAuthStep.authenticated;
    _lastError = null;
    notifyListeners();
  }

  void _clearError() => _lastError = null;

  Future<void> _activateSession(
    AuthSession session, {
    required bool validateRemote,
  }) async {
    _session = session;
    if (validateRemote) {
      final result = await _repository.fetchParentProfile(session);
      _session = result.session;
      _profile = result.profile;
    }
    _step = ParentAuthStep.authenticated;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      await action();
    } on ParentAuthFailure catch (e) {
      _lastError = e;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
