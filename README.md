# Bagshui Empty Bag

Companion addon for [Bagshui](https://github.com/absir/Bagshui) (WoW 1.12) that adds
an **Empty Bag** button to the Bagshui toolbar, next to Organize and Restack.

## Usage

| Action | Result |
|---|---|
| Click the button, then click a bag in the bag bar | Moves every item in that bag into free slots in the other bags of the same window |
| ... Shift-click the bag instead | Same, but once that window is full it overflows into the other one (bank bag → your bags, or your bag → bank bags while the bank is open) |
| Alt-click the button | Compact: fill the leftmost bags, empty the rightmost ones, as far as there's room |
| Alt+Shift-click the button | Compact the other way: fill the rightmost bags |
| Click the button again / right-click a bag | Cancel |

Normal bags are filled before profession bags (herb, soul, ammo...). If a bag refuses an
item, the next free slot is tried. Moves run one at a time at Bagshui's restack pace.
Works on your current character's live bags and on the bank while it's open. Closing the
window cancels a pending click.

It's a separate addon so the Bagshui folder stays an untouched git clone.

## Install

- **With a launcher or git:** add `https://github.com/daev-code/BagshuiEmptyBag` as an addon, or
  `git clone` it into `Interface\AddOns`. Keep the `.git` folder: launchers that install
  from git use it to fetch updates.
- **By hand:** copy this folder to `Interface\AddOns\BagshuiEmptyBag`. Updates are then manual too.
