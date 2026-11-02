import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth/parent_auth_controller.dart';
import '../config/app_config.dart';
import 'parent_gate_api.dart';

/// A parent-only challenge. No offline fallback, default PIN or persisted unlock.
class ParentPinSurface extends StatefulWidget {
  const ParentPinSurface({
    super.key,
    required this.auth,
    required this.config,
    required this.onUnlocked,
    required this.onBack,
  });

  final ParentAuthController auth;
  final AppConfig config;
  final ValueChanged<String> onUnlocked;
  final VoidCallback onBack;

  @override
  State<ParentPinSurface> createState() => _ParentPinSurfaceState();
}

class _ParentPinSurfaceState extends State<ParentPinSurface> {
  late final ParentGateApi _api = ParentGateApi(widget.config);
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  final _identity = TextEditingController();
  final _otp = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  bool _configured = false;
  String _provider = 'phone';
  String? _challengeId;
  String? _proof;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = widget.auth.session;
    if (session == null) {
      widget.onBack();
      return;
    }
    _api.authorize(session);
    try {
      final configured = await _api.configured();
      if (!mounted || widget.auth.session?.sessionId != session.sessionId) return;
      setState(() { _configured = configured; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Güvenlik durumu alınamadı. Tekrar deneyin.'; _loading = false; });
    }
  }

  Future<void> _perform(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await operation();
    } catch (_) {
      if (mounted) setState(() => _error = 'İşlem başarısız. Kodunuzu ve bağlantınızı kontrol edin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlock() => _perform(() async {
    final sessionId = widget.auth.session?.sessionId;
    if (sessionId == null) throw StateError('Missing session');
    final token = await _api.verify(_pin.text);
    if (!mounted || widget.auth.session?.sessionId != sessionId) return;
    _pin.clear();
    widget.onUnlocked(token);
  });

  Future<void> _sendOtp() => _perform(() async {
    final challenge = await _api.beginIdentityProof(_provider, _identity.text.trim());
    if (!mounted) return;
    setState(() => _challengeId = challenge);
  });

  Future<void> _confirmOtp() => _perform(() async {
    final id = _challengeId;
    if (id == null) throw StateError('Missing challenge');
    final proof = await _api.confirmIdentityProof(_provider, id, _otp.text.trim());
    if (!mounted) return;
    _otp.clear();
    setState(() => _proof = proof);
  });

  Future<void> _savePin() => _perform(() async {
    final proof = _proof;
    if (proof == null) throw StateError('Identity proof required');
    if (!RegExp(r'^[0-9]{6}$').hasMatch(_pin.text) || _pin.text != _confirmation.text) {
      throw StateError('Invalid PIN');
    }
    await _api.setPin(_pin.text, _confirmation.text, proof, reset: _configured);
    if (!mounted) return;
    _pin.clear();
    _confirmation.clear();
    setState(() { _configured = true; _proof = null; _challengeId = null; });
  });

  Widget _digits(TextEditingController controller, String label) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    obscureText: true,
    maxLength: 6,
    enableSuggestions: false,
    autocorrect: false,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ebeveyn kilidi'),
        leading: BackButton(onPressed: widget.onBack)),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_error != null) ...[
                  Text(_error!, key: const Key('parent-pin-error')),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _load, child: const Text('Yeniden dene')),
                ],
                Text(_configured ? 'Ebeveyn PIN kodunu girin' : 'Ebeveyn PIN kodunuzu oluşturun',
                  style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                if (_configured && _proof == null && _challengeId == null) ...[
                  _digits(_pin, '6 haneli PIN'),
                  FilledButton(key: const Key('parent-pin-verify'),
                    onPressed: _busy ? null : _unlock,
                    child: const Text('Ebeveyn alanına geç')),
                  const SizedBox(height: 16),
                  TextButton(key: const Key('parent-pin-reset'),
                    onPressed: _busy ? null : () => setState(() { _challengeId = ''; _configured = true; }),
                    child: const Text('PIN unuttum / sıfırla')),
                ] else ...[
                  if (_proof == null) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _provider,
                      items: const [
                        DropdownMenuItem(value: 'phone', child: Text('SMS ile doğrula')),
                        DropdownMenuItem(value: 'email', child: Text('E-posta ile doğrula')),
                      ],
                      onChanged: _busy ? null : (value) => setState(() { _provider = value ?? 'phone'; _challengeId = null; }),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _identity,
                      decoration: InputDecoration(labelText: _provider == 'phone' ? 'Telefon numarası' : 'E-posta adresi')),
                    if (_challengeId == null || _challengeId == '') ...[
                      FilledButton(onPressed: _busy ? null : _sendOtp,
                        child: const Text('Doğrulama kodu gönder')),
                    ] else ...[
                      _digits(_otp, 'OTP doğrulama kodu'),
                      FilledButton(onPressed: _busy ? null : _confirmOtp,
                        child: const Text('OTP doğrula')),
                    ],
                  ] else ...[
                    _digits(_pin, 'Yeni 6 haneli PIN'),
                    _digits(_confirmation, 'PIN tekrar'),
                    FilledButton(key: const Key('parent-pin-setup'),
                      onPressed: _busy ? null : _savePin,
                      child: Text(_configured ? 'PIN sıfırla' : 'PIN oluştur')),
                  ],
                ],
                if (_busy) const Center(child: CircularProgressIndicator()),
              ]),
            ),
      ))),
    );
  }

  @override
  void dispose() {
    _pin.dispose(); _confirmation.dispose(); _identity.dispose(); _otp.dispose();
    super.dispose();
  }
}
