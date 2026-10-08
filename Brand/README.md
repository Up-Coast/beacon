# Beacon's mark

`beacon-mark.svg` is the one source of Beacon's mark: a blue speech bubble with a line-drawn lighthouse (the same one Coast drew for its own badge). Everything else is made from it and must look the same:

- the website button: `Web/src/icon.ts` (same shapes, as a string)
- the Mac and iPhone button: `Sources/BeaconUI/BeaconMark.swift` (same shapes, drawn in code)
- the README and the documentation site: `beacon-mark.svg`
- `beacon-mark-512.png` and `beacon-mark-1024.png`: for any place that takes an uploaded image (a GitHub App logo, the repository's social preview, a marketplace listing)

Change the SVG first, then the two code copies, then the PNGs.
