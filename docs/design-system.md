# Design system (short)

Full version: docs/plan.md (Design system). Widgets use tokens only, never hex literals.

## Color tokens (dark, default; the Editor is always dark)
| Token | Hex | Use |
| --- | --- | --- |
| background | #0E0E11 | Screen background |
| surface | #17171B | Card, panel |
| elevated | #222228 | Bottom sheet, popup, clip |
| border | #2E2E36 | Decorative divider (no contrast requirement); ColorScheme.outlineVariant |
| outline | #6C6C75 | Boundary of interactive controls: outlined button, chip, canvas edge (3:1 on background, surface, elevated); ColorScheme.outline |
| textMuted | #9A9AA5 | Secondary text |
| text | #F4F4F6 | Main text |
| accentFill | #6E4CF5 | Primary button, toggle, slider fill (white text 5.23:1) |
| accentText | #A271FF | Accent text/icon/selected outline on dark surfaces (4.78:1 on elevated) |
| onAccent | #FFFFFF | Text/icon on accentFill |

Light theme (Home, Settings only): textMuted #666670; accentText = accentFill #6E4CF5.

## Rules
- Near-neutral grays: red = green, blue at most +12 (a slight cool bias), no other tint, so users judge color correctly. No pure black. app/test/core/ui/gray_rule_test.dart enforces it.
- ColorScheme built by hand from tokens (no fromSeed); extra tokens in the FramixColors ThemeExtension.
- Accent only on the one primary action per screen and selected state.
- Track colors (audio green, text amber, sticker pink, effect teal, overlay blue) always come with an icon.
- Contrast: text 4.5:1 on background, surface, and elevated; UI component boundaries 3:1.
- Accent presets each define fill, text, and onAccent; coral and aqua use dark onAccent (#0E0E11).
- Material You dynamic color: accent only, never surfaces, never the Editor.

## Type
- UI: Plus Jakarta Sans (800 logo, 700 heading/button, 500 label, 400 body) with Anek Bangla as fallback.
- Timecode: Plus Jakarta Sans tabular figures, or Inter as the single exception.
- Bangla needs taller lines: bn line-height token (start 1.4-1.5x, final from screenshot tests); no fixed-height text containers.

## Motion and touch
- Animations 200-300 ms; respect reduce motion.
- Touch targets at least 44 pt / 48 dp; important controls in the lower half.
