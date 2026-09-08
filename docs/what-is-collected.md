# What is collected

*Last updated: 2026-09-07*

Written so you can tell your testers exactly what a report contains. Every item here is
either put into the link by the app or typed by the tester; nothing is read from their
machine by the page.

## Sent by the app, in the link

| What | Why |
|---|---|
| App name, version, build, commit | Without the build there is no way to tell a fixed bug from a live one; the commit lets the session check out the exact code |
| Operating system and version, device model, processor | Some bugs only exist on one of these |
| Language and time zone | Date, number and text-direction bugs |
| Appearance (light or dark), text size | A surprising share of "it looked wrong" is a large-text or high-contrast setting doing what it was asked |
| Who is signed in (name or account) | Reports are not anonymous, so they can be followed up |

## Written by the tester

- What they expected, what happened, the steps, whether it happens again; or the request
  and the reason; or the message.
- Which part of the app, in their words, if they say.
- How much it affects them.
- Up to six images. Each is shrunk on their device to at most 1600 pixels on its longest
  side and roughly 180 KB before it is sent.

## Never collected by the page

- Files, folders, or anything on the device beyond what is in the link.
- Other apps, the desktop, or anything behind the app.
- Audio.
- Logs or settings. (The GitHub route's in-app sheet does carry the app's own log and its
  settings, with secrets masked; see [The GitHub route](github-route.md).)

## Where it goes

Into the Beacon page's own store, owned by your Claude organisation, readable by its
members. From there, for apps tracked in GitHub, into an issue in your repository, which
whoever has access to the repository can read. Images are committed to a branch in the
repository that nothing is built from.

Anyone in your organisation can read a report; that is by design, so a report is never
lost with one person. Tell your testers that.
