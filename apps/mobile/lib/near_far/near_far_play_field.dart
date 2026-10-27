import 'package:flutter/material.dart';

import '../game/hitbox_scaler.dart';
import '../l10n/app_localizations.dart';
import 'near_far_activity.dart';
import 'near_far_constants.dart';
import 'near_far_relation.dart';

/// Landscape drag-position field for sock + soft toy (F-034 / ≥44dp targets).
class NearFarPlayField extends StatelessWidget {
  const NearFarPlayField({
    super.key,
    required this.activity,
    this.reduceMotion = false,
  });

  final NearFarActivity activity;
  final bool reduceMotion;

  static const Key fieldKey = Key('near-far-play-field');
  static const Key sockKey = Key('near-far-sock');
  static const Key softToyKey = Key('near-far-soft-toy');
  static const Key promptKey = Key('near-far-prompt');
  static const Key relationKey = Key('near-far-relation-label');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      key: fieldKey,
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final sockRect = HitboxScaler.scaleRect(
          Rect.fromCenter(
            center: activity.sockPosition,
            width: NearFarConstants.designObjectSize,
            height: NearFarConstants.designObjectSize,
          ),
          viewport: viewport,
        );
        final toyRect = HitboxScaler.scaleRect(
          Rect.fromCenter(
            center: activity.softToyPosition,
            width: NearFarConstants.designObjectSize,
            height: NearFarConstants.designObjectSize,
          ),
          viewport: viewport,
        );

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFE3F2FD),
                Color(0xFFFFF8E1),
              ],
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    Text(
                      key: promptKey,
                      _promptText(l10n, activity.prompt),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      key: relationKey,
                      _relationText(l10n, activity.currentRelation),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF1565C0),
                          ),
                    ),
                  ],
                ),
              ),
              _DraggableObject(
                key: sockKey,
                label: l10n.nearFarSockLabel,
                color: const Color(0xFFEF9A9A),
                icon: Icons.dry_cleaning_rounded,
                rect: sockRect,
                reduceMotion: reduceMotion,
                onDragDesign: (design) => activity.moveSock(design),
                viewport: viewport,
              ),
              _DraggableObject(
                key: softToyKey,
                label: l10n.nearFarSoftToyLabel,
                color: const Color(0xFF81C784),
                icon: Icons.cruelty_free_rounded,
                rect: toyRect,
                reduceMotion: reduceMotion,
                onDragDesign: (design) => activity.moveSoftToy(design),
                viewport: viewport,
              ),
            ],
          ),
        );
      },
    );
  }

  String _promptText(AppLocalizations l10n, NearFarPromptStep step) {
    switch (step) {
      case NearFarPromptStep.makeNear:
        return l10n.nearFarPromptNear;
      case NearFarPromptStep.makeFar:
        return l10n.nearFarPromptFar;
      case NearFarPromptStep.complete:
        return l10n.nearFarPromptDone;
    }
  }

  String _relationText(AppLocalizations l10n, NearFarRelation relation) {
    switch (relation) {
      case NearFarRelation.near:
        return l10n.nearFarLabelNear;
      case NearFarRelation.far:
        return l10n.nearFarLabelFar;
      case NearFarRelation.neither:
        return l10n.nearFarLabelNeither;
    }
  }
}

class _DraggableObject extends StatelessWidget {
  const _DraggableObject({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.rect,
    required this.onDragDesign,
    required this.viewport,
    required this.reduceMotion,
  });

  final String label;
  final Color color;
  final IconData icon;
  final Rect rect;
  final ValueChanged<Offset> onDragDesign;
  final Size viewport;
  final bool reduceMotion;

  Offset _toDesign(Offset globalLocal) {
    final scale = HitboxScaler.containScale(viewport);
    final letterboxed = Size(
      HitboxScaler.designCanvas.width * scale,
      HitboxScaler.designCanvas.height * scale,
    );
    final origin = Offset(
      (viewport.width - letterboxed.width) / 2,
      (viewport.height - letterboxed.height) / 2,
    );
    final design = Offset(
      (globalLocal.dx - origin.dx) / scale,
      (globalLocal.dy - origin.dy) / scale,
    );
    return Offset(
      design.dx.clamp(0.0, HitboxScaler.designCanvas.width),
      design.dy.clamp(0.0, HitboxScaler.designCanvas.height),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = Size(
      rect.width.clamp(HitboxScaler.minLogicalSize, double.infinity),
      rect.height.clamp(HitboxScaler.minLogicalSize, double.infinity),
    );

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: size.width,
      height: size.height,
      child: Semantics(
        label: label,
        button: false,
        child: GestureDetector(
          onPanUpdate: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) {
              return;
            }
            final local = box.globalToLocal(details.globalPosition);
            // Convert from object-local to field-local.
            final fieldLocal = Offset(rect.left + local.dx, rect.top + local.dy);
            onDragDesign(_toDesign(fieldLocal));
          },
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 90),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: reduceMotion
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: size.shortestSide * 0.42, color: Colors.white),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
