# Release Smoke Tests

Use this checklist on a real iPhone before App Store submission and again after the first TestFlight upload.

## Install and permissions

- [ ] Fresh install opens without layout glitches
- [ ] Photo permission prompt copy looks correct
- [ ] Limited Photos access works
- [ ] Full Photos access works
- [ ] Settings screen legal links open correctly

## Core cleanup flow

- [ ] Swipe right keeps a photo
- [ ] Swipe left adds a photo to delete queue
- [ ] Keep/Delete buttons stay disabled while image is still loading
- [ ] Undo restores the previous decision correctly
- [ ] Review Delete screen shows correct counts
- [ ] Delete confirmation completes without UI lockup

## Guided cleanup and persistence

- [ ] Guided Cleanup opens the expected nested groups
- [ ] Completed months auto-advance to the next leaf
- [ ] Finishing all children returns to the parent level
- [ ] Resume prompt appears for partially viewed groups
- [ ] Progress survives app relaunch
- [ ] Completed badges still show after relaunch

## Media-specific checks

- [ ] Live Photo badge plays inline on card
- [ ] Videos are included/excluded based on settings
- [ ] Photo info sheet opens and closes correctly

## Release sanity

- [ ] App icon and display name are correct on device
- [ ] Haptics feel present but not excessive
- [ ] No obvious stutter on home screen scroll
- [ ] No English/Turkish string errors in the selected language
