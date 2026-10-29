import 'package:little_minds_api/api.dart';

import 'auth_session.dart';

/// Parent profile fetch may rotate tokens (401 → refresh); always use [session].
class ParentAuthProfileResult {
  const ParentAuthProfileResult({
    required this.profile,
    required this.session,
  });

  final ParentMeResponse profile;
  final AuthSession session;
}
