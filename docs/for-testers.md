# Reporting something, if you're testing an app

*Last updated: 2026-09-17*

Use the report button inside the app. It fills in your app version, your device and more, so you only write the part only you know. You don't need to be technical, just specific.

The button opens one of two things, depending on the app.

## If it opens a web page

1. Sign in to Claude if the page asks. You need to be a member of the team's Claude organization.
2. Check **Who you are**. It is your name or email, so your report is not anonymous and the team can reach you if they choose to.
3. Choose **Something's broken**, **Something's missing** or **Something else**, and fill in the form.
4. Add images if you have them. You can add up to 6. On a Mac you can also paste an image straight into the page.
5. Press **Send report**.

## If it opens a form inside the app

1. Sign in to GitHub the first time, if the app asks. The app shows a short code. Type it at [github.com/login/device](https://github.com/login/device) in your browser.
2. Read the notice about what happens to your report and accept it. You see it once, and again only if the wording changes.
3. Choose **Something's broken**, **Something's missing** or **Something else**, fill in the form, and press **Next**.
4. Read **Here's what we'll send**. Nothing has left your device yet.
5. Press **Check and send**, or **Send** if your device can't run the check.

**Check and send** means your Mac, iPhone or iPad reads your report over first, using Apple's on-device AI. It may ask up to 3 questions. Answer what you can, then press **Send it**. You can also press **Send it** without answering. The check only adds your answers. It never changes what you wrote.

## The three things every bug report needs

You can't send a bug report without them.

- **What you expected.** This one decides the most. If the app did what it was built to do and you expected something else, that is still worth fixing: the app isn't explaining itself. Say what you thought would happen, even if you turn out to be wrong.
- **What actually happened.** What was on the screen. "It broke" can't be acted on. "The window went white and stayed white for about a minute" can.
- **The steps you took.** Start from where you were. Include the boring steps. The one everybody leaves out is usually the one that matters.

## Does it happen again?

Nobody works on a bug they can't make happen, because a fix for something nobody saw is a guess. If you can, try it once more before you send. "Every time I follow those steps" is the most useful answer on the form.

If you haven't tried, say so. That answer is accepted.

## Show us

A picture of what you're looking at is usually worth more than another paragraph.

- **Take a screenshot** captures the app itself: its window on a Mac, its screen on an iPhone or iPad.
- **Record what happens** records the app while you make the problem happen. Only the app is recorded, never your desktop, other apps or sound. On an iPhone or iPad the form shrinks to a strip at the bottom so you can use the app, and iOS asks you to confirm first. Recording stops by itself after a few minutes.
- **Choose from Photos**, on an iPhone or iPad, adds a screenshot or screen recording you already took. Location and time details are removed from pictures.
- **Add a file** adds text, an image, a PDF or a video.

The web page takes images only.

## After you send

You get a short reference like `BN-8EA6C3`. You don't need to do anything else. Nothing writes back to you automatically, and the team may come back to you if they want to. If you notice something else, send it as its own report.

If the form in the app can't send, your report is saved on your device and the form tells you where. Nothing you wrote is lost.

## What the team can see

Your report isn't anonymous. Anyone on the team can read it. On the web page, that's anyone who can open the page. From the form in the app, your report becomes a GitHub issue.

| | Web page | Form in the app |
|---|---|---|
| Your app version and build, your device and its system, your language and time zone, light or dark mode and text size | Yes | Yes |
| Your name or email, or your account | Yes | Yes |
| What you write and what you attach | Yes | Yes |
| Your browser's name and version | Yes | No |
| Your memory and free disk space | No | Yes |
| Your settings inside the app. Secret settings show as "set (not shown)" | No | Yes |
| The last few hundred lines of the app's own log | No | Yes |
| The names and sizes of files in the folders the app uses. They are never opened | No | Yes |

Before the form in the app sends, it removes anything that looks like a password or key, then tells you what it removed.

## Hard to act on, and fixable

> It broke when I tried to save.

> I clicked Save on a project called Harbour. The spinner ran for about ten seconds, then the window went white and stayed white. I expected it to save and go back to the project list. It's done it three times today.

The second one gets fixed.
