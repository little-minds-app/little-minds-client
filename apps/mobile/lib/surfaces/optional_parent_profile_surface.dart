import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:little_minds_api/api.dart';

import '../auth/auth_api_clients.dart';
import '../auth/parent_auth_controller.dart';
import '../config/app_config.dart';

/// One optional screen, opened only from Parent Gate -> Parent Settings.
/// Data remains parent-owned and never enters child/game analytics.
class OptionalParentProfileSurface extends StatefulWidget {
  const OptionalParentProfileSurface({
    super.key,
    required this.auth,
    required this.config,
    required this.onBack,
    this.gateToken,
    this.loadForTest,
    this.saveForTest,
    this.clearForTest,
  });
  final ParentAuthController auth;
  final AppConfig config;
  final VoidCallback onBack;
  final String? gateToken;
  final Future<OptionalParentProfile?> Function()? loadForTest;
  final Future<OptionalParentProfile?> Function(UpdateOptionalParentProfile)? saveForTest;
  final Future<OptionalParentProfile?> Function()? clearForTest;

  @override
  State<OptionalParentProfileSurface> createState() => _OptionalParentProfileSurfaceState();
}

class _OptionalParentProfileSurfaceState extends State<OptionalParentProfileSurface> {
  late final AuthApiClients _clients = AuthApiClients(basePath: widget.config.apiBaseUrlString)
    ..apiClient.addDefaultHeader('X-Parent-Gate-Token', widget.gateToken ?? '');
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _count = TextEditingController();
  String? _ageBand;
  String? _gender;
  String? _occupation;
  String? _parentId;
  int _generation = 0;
  bool _busy = false;
  bool _loading = true;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _parentId = widget.auth.session?.parentId;
    widget.auth.addListener(_authChanged);
    _load();
  }

  void _authChanged() {
    final next = widget.auth.session?.parentId;
    if (next == _parentId) return;
    _parentId = next;
    _generation++;
    _first.clear(); _last.clear(); _count.clear();
    _ageBand = null; _gender = null; _occupation = null;
    _error = null; _info = null;
    _load();
  }

  Future<T> _authorized<T>(Future<T> Function(ParentApi) operation) async {
    final original = widget.auth.session;
    if (original == null) throw StateError('Parent sign-in required');
    _clients.setAccessToken(original.accessToken);
    try {
      return await operation(_clients.parent);
    } on ApiException catch (e) {
      if (e.code != 401) rethrow;
      if (widget.auth.session?.parentId != original.parentId) throw StateError('Parent changed');
      final access = await widget.auth.refreshForChildProfiles();
      if (access == null || widget.auth.session?.parentId != original.parentId) throw StateError('Session expired');
      _clients.setAccessToken(access);
      return operation(_clients.parent);
    }
  }

  void _populate(OptionalParentProfile profile) {
    _first.text = profile.firstName ?? '';
    _last.text = profile.lastName ?? '';
    _count.text = profile.numberOfChildrenOptional?.toString() ?? '';
    _ageBand = profile.ageBandOptional?.toJson();
    _gender = profile.genderOptional?.toJson();
    _occupation = profile.occupationOptional?.toJson();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (mounted) setState(() { _loading = true; _error = null; _info = null; });
    try {
      final profile = widget.loadForTest != null
          ? await widget.loadForTest!()
          : await _authorized((api) => api.getParentProfile());
      if (!mounted || generation != _generation || widget.auth.session?.parentId != _parentId) return;
      if (profile == null) throw StateError('Missing profile response');
      setState(() => _populate(profile));
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _error = 'Profil yüklenemedi. Yeniden deneyin.');
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _save({bool clear = false}) async {
    if (_busy || widget.auth.session == null) return;
    final count = _count.text.trim();
    final number = count.isEmpty ? null : int.tryParse(count);
    if (!clear && ((number == null && count.isNotEmpty) || (number != null && (number < 0 || number > 30)) ||
        _first.text.trim().length > 100 || _last.text.trim().length > 100)) {
      setState(() => _error = 'Bilgileri kontrol edin.');
      return;
    }
    final generation = _generation;
    setState(() { _busy = true; _error = null; _info = null; });
    try {
      final input = UpdateOptionalParentProfile(
        firstName: _first.text.trim().isEmpty ? null : _first.text.trim(),
        lastName: _last.text.trim().isEmpty ? null : _last.text.trim(),
        numberOfChildrenOptional: number,
        ageBandOptional: UpdateOptionalParentProfileAgeBandOptionalEnum.fromJson(_ageBand),
        genderOptional: UpdateOptionalParentProfileGenderOptionalEnum.fromJson(_gender),
        occupationOptional: UpdateOptionalParentProfileOccupationOptionalEnum.fromJson(_occupation),
      );
      final result = clear
          ? (widget.clearForTest != null ? await widget.clearForTest!() : await _authorized((api) => api.clearParentProfile()))
          : (widget.saveForTest != null ? await widget.saveForTest!(input) : await _authorized((api) => api.updateParentProfile(input)));
      if (!mounted || generation != _generation || widget.auth.session?.parentId != _parentId) return;
      if (result == null) throw StateError('Missing save response');
      setState(() {
        _populate(result);
        _info = clear ? 'İsteğe bağlı bilgiler temizlendi.' : 'Profil kaydedildi.';
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _error = 'İşlem tamamlanamadı. Yeniden deneyin.');
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Widget _choice(String title, String? value, List<MapEntry<String, String>> options, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      key: ValueKey('parent-profile-$title'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: title),
      items: [
        const DropdownMenuItem(value: null, child: Text('Şimdi değil / Boş bırak')),
        ...options.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))),
      ],
      onChanged: _busy ? null : (next) => setState(() => onChanged(next)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const ageOptions = <String, String>{
      '18-24': '18–24', '25-34': '25–34', '35-44': '35–44', '45-54': '45–54',
      '55+': '55+', 'prefer_not_to_say': 'Belirtmek istemiyorum',
    };
    const genderOptions = <String, String>{
      'woman': 'Kadın', 'man': 'Erkek', 'non_binary': 'İkili olmayan',
      'self_describe': 'Kendim tanımlıyorum', 'prefer_not_to_say': 'Belirtmek istemiyorum',
    };
    const workOptions = <String, String>{
      'education': 'Eğitim', 'healthcare': 'Sağlık', 'technology': 'Teknoloji',
      'finance_business': 'Finans', 'public_service': 'Kamu', 'retail_services': 'Hizmetler',
      'manufacturing_trades': 'Üretim', 'creative_media': 'Medya',
      'homemaker_caregiver': 'Ev ve bakım', 'student': 'Öğrenci',
      'retired': 'Emekli', 'not_currently_employed': 'Şu anda çalışmıyorum',
      'other': 'Diğer', 'prefer_not_to_say': 'Belirtmek istemiyorum',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Ebeveyn profili'), leading: BackButton(onPressed: widget.onBack)),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Tüm alanlar isteğe bağlıdır. Daha sonra değiştirebilir veya silebilirsiniz.'),
                  const SizedBox(height: 12),
                  if (_error != null) ...[
                    Text(_error!, key: const Key('parent-profile-error')),
                    TextButton(onPressed: _load, child: const Text('Yeniden dene')),
                  ],
                  if (_info != null) Text(_info!, key: const Key('parent-profile-info')),
                  TextField(controller: _first, maxLength: 100, decoration: const InputDecoration(labelText: 'Ad')),
                  TextField(controller: _last, maxLength: 100, decoration: const InputDecoration(labelText: 'Soyad')),
                  _choice('Yaş aralığı', _ageBand, ageOptions.entries.toList(), (v) => _ageBand = v),
                  _choice('Cinsiyet', _gender, genderOptions.entries.toList(), (v) => _gender = v),
                  TextField(controller: _count, keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Çocuk sayısı')),
                  _choice('Mesleki durum', _occupation, workOptions.entries.toList(), (v) => _occupation = v),
                  const SizedBox(height: 16),
                  FilledButton(key: const Key('parent-profile-save'), onPressed: _busy ? null : () => _save(),
                    child: const Text('Kaydet ve devam et')),
                  TextButton(key: const Key('parent-profile-skip'), onPressed: _busy ? null : widget.onBack,
                    child: const Text('Şimdi değil / Atla')),
                  OutlinedButton(key: const Key('parent-profile-clear'), onPressed: _busy ? null : () => _save(clear: true),
                    child: const Text('Tüm isteğe bağlı bilgileri sil')),
                ]),
              ),
      ))),
    );
  }

  @override
  void dispose() {
    _generation++;
    widget.auth.removeListener(_authChanged);
    _first.dispose(); _last.dispose(); _count.dispose();
    super.dispose();
  }
}
