# Bagshui Empty Bag

Adds an **Empty Bag** button to the [Bagshui](https://github.com/absir/Bagshui) toolbar,
next to Organize and Restack. For WoW 1.12.

## Usage

| Do this | What happens |
|---|---|
| Click the button, then click a bag in the bag bar | Everything in that bag moves to free slots in the other bags of the same window |
| Click the button, then Shift-click a bag | Same, but when that window runs out of space the rest goes to the other one (bank bag to your bags, or your bag to the bank while it's open) |
| Alt-click the button | Compacts your bags: fills the leftmost ones and empties the rightmost, as far as space allows |
| Alt+Shift-click the button | Compacts the other way, filling the rightmost bags |
| Click the button again, or right-click a bag | Cancels |

Normal bags fill up before profession bags (herb, soul, ammo and so on). If a bag won't take
an item, the next free slot gets it instead. Items move one at a time, at the same pace as
Bagshui's restack.

It works on your current character's bags, and on the bank while you have it open. Closing
the window cancels a pending click. Bagshui's own files aren't modified.

## Install

Add `https://github.com/daev-code/BagshuiEmptyBag` to your launcher, or `git clone` it into
`Interface\AddOns`. Leave the `.git` folder in place: launchers that install from git need
it to pull updates.

You can also copy the folder to `Interface\AddOns\BagshuiEmptyBag` yourself, but then
you'll need to update it yourself too.
