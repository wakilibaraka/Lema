# Lema design

Later passes must match this file. Change it first if a decision changes.

**Product:** Lema helps solo creators plan, publish and measure posts across their social channels.
**Character:** steady, exact, a little warm. **World:** a broadcast rundown, a studio's schedule board.
**Register:** R1 Utility. Dense and calm, with no hero.

## The memorable thing
The on-air tick: a mono `09:00` time with a small status dot. It appears on scheduled items only, in the queue, calendar and composer. The dot never pulses.

Two moments get visual weight: the reach trend on Analytics and the week timeline in the calendar. Everything else stays quiet.

## Tokens (`lib/core/theme.dart`)
| Token | Value | Why |
|---|---|---|
| Accent | `#D9690B`, text shade `#A84F06` | A tally light's amber. Used once or twice a screen |
| Text on accent | ink `#1C1C1A` (4.86:1) | White on this amber is only 3.51:1 |
| Neutrals | Graphite, light `#F6F6F5` to `#1C1C1A`, dark `#111110` to `#EDEDEB` | Equipment, not paper. One slightly warm tint throughout |
| Status | Green `#2F8A55`, red `#C4392F` | Meaning only, always with text |
| Platforms | Small dots | Brand colors identify a channel without competing with the accent |
| Spacing | 4, 8, 12, 16, 20, 24, 32 | Rundown rows need a strict rhythm |
| Radii | Controls 8, cards 14, sheets 20 | Nested: inner radius = outer minus padding |
| Type | Native faces; 12/13/15/17/22/28; weights 400/500/600 | A tool should feel native. 12-13 is metadata only |
| Mono | Times and data only | A schedule board's numerals, not decoration |
| Motion | `easeOutCubic`; 120 and 200ms controls, 320ms sheets | Marks a state change, nothing else |

## Rules
- Separate with whitespace, then a surface step, then a hairline, and rarely a shadow. No cards inside cards.
- Page edges 24 on desktop, 16 on phones. A screen gets a title only when nothing else names it: Analytics and Settings do; Queue has its tab; Composer and Vault open on their own controls.
- The week grid's fixed-height hour cells keep 1 and 2pt gaps; nothing else goes off the grid.
- Blur only on the mobile bottom bar. No gradients.
- Icons: one outline set at 18pt in a text color, never in a tinted tile, never emoji.
- Copy: sentence case, verb + object buttons, and every change says what it compares to.
- Demo client content in `demo_seed.dart` is sample data, not UI, and keeps its own voice unless the user says otherwise.

## Credits
Passes follow heydamir/unslop and agshinrajabov/no-slop-design (MIT), applied by hand.
