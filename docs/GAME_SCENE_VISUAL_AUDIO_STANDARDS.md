# Little Minds — Game Scene Visual, Mascot & Audio Standards

**Status:** Approved baseline for new Kids Mode game scenes (2026-11-06)  
**Reference implementation:** [Shape Matching — Playful Learning Garden, PR #41](https://github.com/little-minds-app/little-minds-client/pull/41), merged to `main` as `88c8661cb448b66a4ce06d05e43c05002d339436`.  
**First consumer:** [LMP-56 — Color Sorting](https://little-minds-app.atlassian.net/browse/LMP-56).  
**Applies to:** New or substantially redesigned Kids Mode games (LMP-56 onward); changes to older games should apply the same principles without silently expanding their Jira scope.

> **Binding product direction:** All games must feel like members of the **same Little Minds universe**. Reuse the approved Shape Matching *visual, mascot, motion, interaction and audio design language*, while giving each game its own theme and original musical/SFX variations. Do not independently invent a visually incompatible scene, mascot family, HUD, or audio style.

## 1. Source-of-truth implementation references

Read these from the *current* `main` branch before designing a new game. These files are **references**, not license to copy Shape Matching's scoring or task logic:

| Concern | Reference |
| --- | --- |
| Scene / playful environment | `apps/mobile/lib/shape_matching/shape_matching_garden_scene.dart` |
| Friendly character art / facial design | `apps/mobile/lib/shape_matching/shape_matching_shape_character.dart` |
| Mascot character, mood, clap/jump and reduced motion | `apps/mobile/lib/shape_matching/shape_matching_bunny_mascot.dart` |
| Age-dependent *presentation* density | `apps/mobile/lib/shape_matching/shape_matching_visual_profile.dart` |
| Landscape layout, target axis, drag/tap feedback and praise | `apps/mobile/lib/shape_matching/shape_matching_play_field.dart` |
| Decorative scoring-neutral Flame feedback | `apps/mobile/lib/shape_matching/shape_matching_flame_layer.dart` |
| One BGM player, SFX player, gain/ducking, lifecycle | `apps/mobile/lib/shape_matching/shape_matching_audio.dart` |
| Existing locally bundled effects | `apps/mobile/assets/audio/shape_matching/sfx/` |
| Original Happy Garden music provenance | `apps/mobile/assets/audio/shape_matching/bgm/PROVENANCE.md` |
| Reproducible audio creation examples | `scripts/generate_shape_matching_bgm.py`, `scripts/generate_shape_matching_sfx.py` |
| Existing visual and audio regression examples | `apps/mobile/test/shape_matching_widget_test.dart`, `apps/mobile/test/shape_matching_audio_test.dart` |

Consult existing product blueprint/accepted ADRs, session-controller interfaces, screen-time, parent sound controls, localization and accessibility conventions. An implementation reference does not supersede approved contracts.

## 2. Mandatory visual consistency

1. **One design family:** Preserve Playful Learning Garden's warm, bright, friendly, softly layered cartoon illustration style; rounded shapes; legible foreground hierarchy; consistent shadows, outlines, color saturation and celebration feedback. New locations (e.g. orchard, beach, forest, playroom) may change props and palette *within* this family.
2. **Mascot continuity:** Reuse the existing bunny where appropriate. If a different animal or character is pedagogically preferable, derive it from the same original character language: comparable proportions, face/eye treatment, softness, animation rhythm, emotion states and cheerful non-punitive reactions. Do not introduce realistic photography, visually unrelated stock characters, emoji stand-ins or a new clashing mascot style.
3. **Coaching states:** Support coherent idle, encouragement/try-again, correct-match celebration and completion states. Correct actions should cause clear but brief celebration (e.g. clapping/jumping), not continuous visual noise. Incorrect actions receive supportive, non-shaming feedback.
4. **Age bands:** Maintain the approved 24–35, 36–47 and 48–71 month groupings where a game supports them. Younger ages receive larger, calmer, fewer visual choices and simpler instructions; older ages may get richer details/labels. **Do not alter game difficulty solely by copying Shape Matching's presentation profile.**
5. **Layout and input:** Protect the actual center axis of the primary target/task area. Decorative mascots must not push the task off-center or intercept gestures; prefer independent overlay placement with `IgnorePointer` for decorative characters. Honor landscape safe areas, small phone, tablet, text scaling and reachable drag/tap targets. Use accessible semantics; never rely on color alone to communicate correctness.
6. **Motion:** Keep bounce, lift, sparkle, praise and celebration timing in the same restrained family. Respect `reduceMotion` with stable static feedback. Ensure animation state and timers reset on replay, child/activity replacement, pause and dispose.
7. **Content:** All screen text must be child-friendly, localized TR/EN via existing l10n, with no developer labels (e.g. "Playing"), UUIDs or debug metadata. Avoid copyrighted/third-party art; produce project-owned original graphics.

## 3. Mandatory audio consistency — same pattern, different variations

**Every new game may have its own recognizable original soundtrack and sounds**, but must follow the approved Shape Matching *musical and technical pattern*.

### Background music (BGM)

- Use Happy Garden as the **sound-design reference**, not as an obligatory reused file. A new game can use a different **original composition/variation** with a similar warm, light, child-friendly mood (marimba, xylophone, gentle piano/bells; moderate tempo, simple melodic phrasing, restrained percussion). Color Sorting should have its own recognizable variation.
- Baseline reference: Happy Garden ~100 BPM, 57.6-second loop, compressed mono MP3. These are *reference values*, not rigid requirements; prefer a natural phrase and verified clean, unobtrusive loop.
- No recognizable copyrighted melody, unlicensed samples, voice-over masquerading as music or runtime network downloads. Store music inside the app package; document authorship/provenance and reproducible generation/asset origin.
- One idempotent looping music player per active activity, not one per round or widget rebuild. No overlapping music after replay. Stop on exit/child switch; pause on background, screen-time block and other forbidden states; resume **only** when gameplay is eligible. Respect iOS silent behavior, Android audio-focus conventions and existing parent sound-off controls.
- Keep the BGM quieter than interaction feedback. Shape Matching's software gains (BGM idle 0.20, ducked 0.05, SFX 0.85) are **starting references only**, subject to real-device listening and safe levels; not absolute loudness specifications.
- Duck BGM temporarily beneath success/complete effects, with a longer window for completion and one orderly restoration on rapid consecutive events. Guard async start/resume, volume changes, timers and dispose against stale operations and screen-time/navigation races.

### Sound effects (SFX)

- Preserve the **cue vocabulary**: gentle tap/pop, drag/lift/bounce, friendly wrong/try-again, distinct positive correct cue, mascot clap/reaction, sparkly accent and richer final completion jingle.
- **Use a matching sound-design family with new variants:** Color Sorting's correct/wrong/drag/finish cues may vary by tone/timbre/melody, but should sound related to Shape Matching, not like a different game/product. Avoid loud punishment buzzers, harsh alarms and repetitive audio spam.
- Favor original, small, bundled offline assets. No third-party samples without verified rights. Do not reuse an identical sound in every game by default, but do reuse proven playback contracts and mixing/lifecycle patterns rather than copying entire activity implementations.
- SFX must never delay gameplay or scoring; guard duplicate events with per-match/round identities. Pause/exit/replay/switch must cancel pending celebrations and prevent stale sounds.
- Sound-off mutes **both** BGM and SFX; missing audio assets fail softly and must not block game mechanics. Reduced motion and muted sound are independent preferences.

### Implementation boundary

Reuse established `audioplayers` audio-session configuration, BGM/SFX injectable ports, and test-double patterns where sensible. Extract a **shared** primitive only when it meaningfully reduces duplication and preserves tested behavior. Do not make Color Sorting dependent on Shape Matching gameplay types, change the finished Shape Matching mechanic, or silently alter telemetry/privacy/session contracts.

## 4. Color Sorting (LMP-56) starting direction

- **Scene:** A child-friendly sorting play area in the same Garden universe, e.g. a colorful orchard with gentle props. The core task (objects and destination bins) must stay visually dominant and easily understood.
- **Mascot:** The approved bunny style (preferably the actual existing bunny when technically appropriate), reacting to correct sort, friendly retry and completion. Keep it separate from gesture hit regions.
- **Age-responsive mechanics:** Choose object/bin counts, complexity, prompts and accessibility cues through the approved game/age rules, **not** by silently assuming Shape Matching's choice count.
- **Music:** Create an original "Happy Garden family" variation for Color Sorting with the same instruments/mood/mix principles, but a distinguishable melody/arrangement and clean seamless loop.
- **SFX:** Original related variants for pick-up/drag, correct placement, supportive incorrect placement and final success; coordinate mascot timing with audible celebrations.
- **Technical guardrails:** Offline-first, existing child session/parent gate/screen-time lifecycle, TR/EN, replay-safe state, small memory footprint. Preserve production event-outbox behavior and consent; never invent `content_version_id`, send cross-child events or change other games.
- **Scope:** This document is a design contract only. **Do not implement Color Sorting in the documentation PR.** Its feature code, tests, UAT and Jira workflow belong to a separate LMP-56 branch/PR, developed with Cursor.

## 5. Acceptance checklist for each future game scene

A new game is not accepted merely because it compiles. Reviewers must record:

- [ ] Visual comparison against current Shape Matching: same illustration, shape/face and mascot family; original scene personality within shared brand
- [ ] Appropriate mascot moods, meaningful praise/encouragement, coherent celebration animation and SFX sync
- [ ] Target/task visually balanced (including actual screen center when applicable); mascot does not steal touch input
- [ ] Age bands, accessibility, reduced motion, hit targets, safe areas, compact phone and tablet verified
- [ ] TR/EN text and no technical UI labels
- [ ] Original offline BGM variation, documented provenance, seamless loop, pleasant listening quality
- [ ] Related original SFX variations; BGM duck/restore, sound-off and accessibility rules respected
- [ ] No double music on replay; no audio after pause, background, screen-time block, exit or child switch; deterministic async race tests
- [ ] Deterministic gameplay, offline/reconnect, lifecycle, telemetry/privacy and regression tests; no gameplay delay from sound
- [ ] Flutter analyze, focused/full tests, GitHub CI, and real iPhone/iPad (and applicable Android) visual+audible UAT evidence before merge

## 6. How to apply in Cursor

Before each new game scene task:

1. Read **this Markdown file** and the Shape Matching references listed in §1 from current `main`.
2. Produce a short visual/audio consistency plan naming what is reused, what is adapted, and which original game-specific BGM/SFX variants will be made.
3. Implement only on the target game's dedicated branch/PR (e.g. `LMP-56`), preserving the approved architecture and existing games.
4. Run the acceptance checklist and show concrete automated + human UAT evidence; do not claim device listening from a cloud agent.
5. Do not merge or mark Jira Done before explicit user approval.

**If a new design deliberately deviates from this baseline, document the proposed exception and request product approval before implementation.**
