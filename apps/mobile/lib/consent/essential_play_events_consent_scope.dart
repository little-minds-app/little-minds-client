import 'package:flutter/widgets.dart';

import 'essential_play_events_consent_service.dart';

class EssentialPlayEventsConsentScope extends InheritedNotifier<
    EssentialPlayEventsConsentService> {
  const EssentialPlayEventsConsentScope({
    required super.notifier,
    required super.child,
    super.key,
  });

  static EssentialPlayEventsConsentService of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<EssentialPlayEventsConsentScope>();
    assert(scope != null, 'EssentialPlayEventsConsentScope not found');
    return scope!.notifier!;
  }

  static EssentialPlayEventsConsentService? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<EssentialPlayEventsConsentScope>()
        ?.notifier;
  }
}
