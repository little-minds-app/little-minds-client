import 'learning_activity.dart';

/// Typed registry for Flame learning activities (Blueprint OCP extension point).
///
/// Production bootstrap stays empty so Child Hub cards remain passive.
/// Real mechanics register at the composition root in later E03 tasks
/// (LMP-55+) without editing shared lifecycle code (LMP-44).
/// ADR-015: AI must not generate executable game mechanics.
class ActivityRegistry {
  ActivityRegistry([List<LearningActivity>? seed])
      : _byId = {
          for (final activity in seed ?? const <LearningActivity>[])
            activity.id: activity,
        };

  final Map<String, LearningActivity> _byId;

  bool get isEmpty => _byId.isEmpty;

  int get length => _byId.length;

  LearningActivity? findById(String id) => _byId[id];

  Iterable<LearningActivity> get all => _byId.values;

  void register(LearningActivity activity) {
    _byId[activity.id] = activity;
  }
}
