# Reporting something, if you're testing an app

You don't need to know anything technical. You need to be specific.

## Use the button in the app

There's a report button inside the app itself. Use it rather than emailing
or opening a GitHub issue by hand — it picks up your version, your
settings, what the app was doing and the last few minutes of its log, so
you don't have to describe any of that. You write the part only you know.

## The three things you'll always be asked

You can't send a bug report without them, and they're not paperwork:

**What you expected to happen.** This one decides everything. If the app
did what it was designed to do and you expected something different, that's
still worth fixing — it means the app isn't explaining itself. Say what you
thought would happen even when it turns out you were wrong.

**What actually happened.** What was on the screen. "It broke" can't be
acted on; "the window went white and stayed white for about a minute" can.

**The steps you took.** Start from where you were. Include the boring
ones — the step everybody leaves out is usually the one that matters.

## The question that changes the most

*Does it happen again?*

Nobody is allowed to work on a bug they can't make happen — a fix for
something you never saw is a guess. So if you can, try it once more before
you send. "Every time I follow those steps" is the single most useful thing
you can write on the whole form.

If you genuinely haven't tried, say that. It's a true answer and it's
accepted.

## Show us

- **Take a screenshot** — one button. It grabs the app itself: its window
  on a Mac, its screen on an iPhone or iPad.
- **Record it** — if you can make the problem happen on demand, press
  record, do it, press stop. Only the app itself is recorded. Never your
  desktop, never anything behind the app. On an iPhone the form shrinks to
  a strip at the bottom so you can use the app while it records, and iOS
  asks you first.
- **Choose from Photos** — on an iPhone or iPad, a screenshot or screen
  recording you already took the usual way.
- **Add a file** — text, an image, a PDF.

A picture of what you're looking at beats another paragraph nearly every
time.

## What we can see, and what we can't

- Your app version and build, your system version, your device's model,
  your language and time zone, and your appearance and text-size settings.
- Your settings inside the app. Anything secret shows as "set (not shown)".
- The last few hundred lines of the app's own log.
- **The names and layout of your project files** — like a table of
  contents. We never open them and never read what's inside.
- Anything you attach yourself. That one is entirely your choice, file by
  file.

Before anything is sent you get a screen showing all of it. Nothing has
left your device until you press send.

## Who sees it

Your report isn't anonymous. It goes out with your account, we may come
back to you about it, and it becomes an issue on GitHub that everyone on
the team can read. Write it as something other people will see, because
they will.

## The check before it sends

If your Mac, iPhone or iPad can run Apple's on-device AI, it reads your
report over before it goes and might ask a question or two — usually
"which project was it?" or "what happened right after that?". That happens
on your device; nothing is sent to do it. Answer what you can, or send it as
it is. It asks, it never blocks.

## Hard to act on, and fixable

> It broke when I tried to save.

> I clicked Save on a project called Harbour. The spinner ran for about ten
> seconds, then the window went white and stayed white. I expected it to
> save and go back to the project list. It's done it three times today.

Same person, same bug, ten seconds apart in effort. The second one gets
fixed.
