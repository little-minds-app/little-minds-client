import 'learning_activity.dart';

/// Typed registry for Flame learning activities (Blueprint OCP extension point).
///
/// Empty in LMP-24. Real mechanics land in later E03 / LMP-31+ tasks.
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
