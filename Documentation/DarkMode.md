# Dark Mode

Tokens live in `MyTinyJungle/Assets.xcassets/Jungle/*.colorset` and are exposed as `Jungle.*` in `Design/Theme.swift`. Android mirrors the names and values. Follows the HIG Dark Mode page and WWDC19 session 214: near-neutral backgrounds, base vs elevated, vibrant label tiers, system fill opacities, one accent.

Rule: never hard-code a colour in a view. Selection is always accent (no brown, no terracotta). Dark cards separate by lightness, not shadow.

| Token (`Jungle.`) | Role | Light | Dark |
|---|---|---|---|
| background | Base screen | #FCFAF6 | #000000 |
| background (elevated) | Sheets, covers | #FCFAF6 | #1C1C1E |
| surface | Cards on base | #FFFFFF | #1C1C1E |
| surface (elevated) | Cards in sheets | #FFFFFF | #2C2C2E |
| surfaceRaised | Inputs, idle send button | #F3F6F0 | #2C2C2E |
| fillStrong | Primary fill | #D6E6CC | #787880 36% |
| fill / mint | Secondary fill, icon plates | #E6F1DF | #787880 32% |
| fillSubtle / mist | Tertiary fill | #F2F7EE | #767680 24% |
| separator / border | Hairlines | #DDE5D9 | #545458 65% |
| text | Primary label | #3E4E3D | #FFFFFF |
| subtle | Secondary label | #5C6B5B | #EBEBF5 60% |
| tertiary | Tertiary label (glyphs, chevrons) | #687567 | #EBEBF5 30% |
| quaternary | Quaternary label | #3E4E3D 22% | #EBEBF5 18% |
| tint / accentText | Accent, links, accent text | #2F5D3A | #6FD58C |
| forest | Primary button fill | #2F5D3A | #5ECB7D |
| onForest | Text on primary button | #FFFFFF | #06240F |
| accentFill | Tinted accent fill | #E6F1DF | #6FD58C 20% |
| chipSelected | Selected chip fill | #2F5D3A | #6FD58C 20% |
| onChipSelected | Selected chip label | #FFFFFF | #7DDB98 |
| leaf | Healthy icon tint | #5F8F62 | #7FCB8A |
| sage | Neutral status tint | #A8C7A5 | #8FA894 |
| sun / sunFill | Caution tint / fill | #F6D992 / #FBF0D2 | #F0C75E / #FFCC00 16% |
| terracotta / peach | Alert tint | #D9987B / #F8CDB6 | #FF9B7D / #F5A98A |
| warmFill / warmText | Warning banner fill / text | #FBE6DA / #7A3E22 | #FF8C5A 18% / #FFB496 |
| incoming / userBubble | Chat bubbles | #E8EEE4 / #DCEFD3 | #262628 / #1F4A2C |

Controls: primary = `.borderedProminent` + `.junglePrimary()` (forest fill, onForest ink). Secondary = `.bordered` tinted (accent fill, accent text). Chips = `.jungleChip(selected:)`. Toggles, segmented pickers and the tab bar take the app tint. Bars and chrome over imagery use system materials. The dark backdrop is near-black with a faint leaf glow at 18% intensity.

Contrast on #1C1C1E / #2C2C2E: secondary 5.9 / 5.3, accent 9.4 / 7.7, warmText 9.9 / 8.1, onForest on forest 8.1, selected chip label 6.5 / 5.3. Every value is at least 4.5:1. Tertiary and quaternary follow Apple's vibrant tiers and are used for glyphs and placeholders, not body text.
