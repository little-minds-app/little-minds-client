import 'package:flutter/material.dart';

import '../child_profiles/child_profiles_controller.dart';
import '../feedback/parent_feedback_banner.dart';
import '../orientation/app_surface.dart';
import '../orientation/orientation_binder.dart';
import '../shell/adaptive_shell.dart';

/// Selecting a known child is safe in Kids Mode. Create/edit is parent-only.
class ProfileSelectionSurface extends StatefulWidget {
  const ProfileSelectionSurface({
    super.key,
    this.onBackToHub,
    this.controller,
    this.allowManage = false,
  });

  final VoidCallback? onBackToHub;
  final ChildProfilesController? controller;
  final bool allowManage;

  static const Key surfaceKey = Key('surface-profile-selection');
  static const Key placeholderKey = Key('profile-selection-placeholder');
  static const Key scrollKey = Key('profile-selection-scroll');
  static const Key createKey = Key('profile-create');
  static const Key saveKey = Key('profile-save');
  static const Key retryKey = Key('profile-retry');

  @override
  State<ProfileSelectionSurface> createState() => _ProfileSelectionSurfaceState();
}

class _ProfileSelectionSurfaceState extends State<ProfileSelectionSurface> {
  final _nickname = TextEditingController();
  final _age = TextEditingController(text: '32');
  String? _editingId;
  bool _started = false;
  String? _saveSuccessMessage;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _started) return;
        _started = true;
        // ignore: discarded_futures
        widget.controller!.load();
      });
    }
  }

  @override
  void dispose() {
    _nickname.dispose();
    _age.dispose();
    super.dispose();
  }

  void _beginCreate() {
    setState(() {
      _editingId = null;
      _nickname.clear();
      _age.text = '32';
    });
  }

  void _beginEdit(String id, String? nickname, int months) {
    setState(() {
      _editingId = id;
      _nickname.text = nickname ?? '';
      _age.text = '$months';
    });
  }

  Future<void> _save() async {
    final controller = widget.controller;
    if (!widget.allowManage || controller == null || !controller.isAuthenticated) return;
    final ageMonths = int.tryParse(_age.text);
    if (ageMonths == null || ageMonths < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yaşı ay olarak girin.')),
      );
      return;
    }
    final success = await controller.save(
      childId: _editingId,
      nickname: _nickname.text.trim(),
      ageMonths: ageMonths,
    );
    if (!mounted) return;
    if (success) {
      setState(() {
        _editingId = null;
        _saveSuccessMessage = 'Profil sunucuda kaydedildi.';
      });
    } else if (controller.error != null) {
      setState(() => _saveSuccessMessage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = widget.controller;
    return OrientationBinder(
      surface: AppSurface.profileSelection,
      child: AdaptiveShell(
        title: 'Çocuk profilleri',
        actions: [
          TextButton(
            key: const Key('nav-back-hub'),
            onPressed: widget.onBackToHub,
            child: const Text('Geri'),
          ),
        ],
        body: KeyedSubtree(
          key: ProfileSelectionSurface.surfaceKey,
          child: profiles == null
              ? const Center(
                  child: Text(
                    'Profil seçimi yüklenemedi.',
                    key: ProfileSelectionSurface.placeholderKey,
                  ),
                )
              : AnimatedBuilder(
                  animation: profiles,
                  builder: (context, _) => SingleChildScrollView(
                    key: ProfileSelectionSurface.scrollKey,
                    padding: const EdgeInsets.all(20),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!profiles.isAuthenticated)
                              const Text('Profilleri görmek için ebeveyn olarak giriş yapın.'),
                            if (profiles.busy)
                              const LinearProgressIndicator(),
                            if (!profiles.busy && profiles.loaded && profiles.children.isEmpty)
                              const Text('Henüz çocuk profili yok.'),
                            if (_saveSuccessMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ParentFeedbackBanner(
                                  key: const Key('profile-save-success'),
                                  kind: ParentFeedbackKind.success,
                                  title: 'Kaydedildi',
                                  message: _saveSuccessMessage!,
                                ),
                              ),
                            if (profiles.error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ParentFeedbackBanner(
                                  key: const Key('profile-error'),
                                  kind: ParentFeedbackKind.error,
                                  title: 'Profil işlemi başarısız',
                                  message: profiles.error!,
                                  onRetry: profiles.busy ? null : () => profiles.load(),
                                  retryLabel: 'Tekrar dene',
                                  retryKey: ProfileSelectionSurface.retryKey,
                                ),
                              ),
                            for (final child in profiles.children)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Semantics(
                                        selected: profiles.selectedId == child.childId,
                                        child: OutlinedButton(
                                          key: Key('profile-select-${child.childId}'),
                                          onPressed: () => profiles.select(child.childId),
                                          child: Text('${child.nickname?.isNotEmpty == true ? child.nickname : 'Çocuk'} — ${child.ageMonths} ay'),
                                        ),
                                      ),
                                    ),
                                    if (widget.allowManage)
                                      TextButton(
                                        onPressed: profiles.busy ? null : () => _beginEdit(child.childId, child.nickname, child.ageMonths),
                                        child: const Text('Düzenle'),
                                      ),
                                  ],
                                ),
                              ),
                            if (widget.allowManage && profiles.isAuthenticated) ...[
                              const Divider(height: 28),
                              OutlinedButton(
                                key: ProfileSelectionSurface.createKey,
                                onPressed: profiles.busy ? null : _beginCreate,
                                child: const Text('Yeni profil oluştur'),
                              ),
                              Text(_editingId == null ? 'Profil oluştur' : 'Profili düzenle'),
                              TextField(
                                key: const Key('profile-nickname'),
                                controller: _nickname,
                                maxLength: 80,
                                decoration: const InputDecoration(labelText: 'Takma ad (isteğe bağlı)'),
                              ),
                              TextField(
                                key: const Key('profile-age-months'),
                                controller: _age,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Yaklaşık yaş (ay)'),
                              ),
                              const Text('Kesin doğum tarihi gerekli değildir.'),
                              FilledButton(
                                key: ProfileSelectionSurface.saveKey,
                                onPressed: profiles.busy ? null : _save,
                                child: Text(profiles.busy ? 'Kaydediliyor…' : 'Kaydet'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
