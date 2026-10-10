# agent-permissions-kit

How to run Claude Code agents unattended (headless jobs, subagents, phone-triggered runs) so that they
**mostly just work**, and the rare thing that's blocked turns into **one actionable tap on your phone**
instead of a silent failure you discover a day and a half later.

This is a pattern, not a package. It's what Jai Dhyani and his Claude instances converged on after many
iterations. The pieces are small; the value is in how they fit together. Hand [`ONBOARDING.md`](./ONBOARDING.md)
to a Claude Code agent in your own environment and it can build your version.

## The idea in one paragraph

Run everything in Claude Code's **auto mode**, where a classifier model judges each tool call against a few
*prose* lines of guidance you write. Keep hard `deny` rules to a tiny floor (credentials, a few named harms).
Don't pile up hundreds of allow/deny carve-outs: they rot, conflict, and a broad allow silently bypasses the
classifier. When the classifier blocks something, a **PermissionDenied hook** turns the block into a
**proposed rule** and **pushes it to your phone**. You approve it there — for 7 days, 30 days, or until
revoked — and a small trusted service (not the agent) writes it into `~/.claude/settings.json`. Rules that
skip the classifier entirely ("hard allows") require a **passkey/YubiKey signature** over the exact rule, so
neither the agent nor the classifier can be talked into thinking you approved something you didn't. Rules
expire on their own, so the permission surface shrinks back instead of only growing.

## The pieces

| Piece | What it does | Minimum version |
|---|---|---|
| Auto mode + `autoMode` guidance | Classifier judges every call no allow matched | 5–10 prose lines in `settings.json` |
| Tiny deny floor | Things that must hold whatever the model thinks | Credential paths, a handful more, each with a written reason |
| PermissionDenied hook | Logs every block; turns it into a proposed rule | ~50-line script |
| Push channel | Gets the proposal to your phone *with buttons* | ntfy.sh / Pushover / FCM |
| Approval service ("keeper") | The only thing allowed to write rules into settings; verifies it was you | Small web service on your tailnet |
| Strong confirmation | Passkey/WebAuthn signature over the exact rule text + nonce | Required for hard allows |
| Expiry sweeper | Removes rules when their time is up | cron/launchd, finds rules by tag |
| Asks board (optional) | One place for everything agents are waiting on you for | JSONL ledger + a page |

## Lessons that cost real time

- **A broad `permissions.allow` is a hole, not a convenience.** In auto mode, an allow like `Bash(git *)`
  skips the classifier completely — including for calls your `hard_deny` lines name.
- **Every restriction needs a named harm next to it.** Unexplained rules accumulate (we hit 369 denies, none
  with a reason) and nobody can safely remove any of them.
- **Test what actually enforces.** Behavior changes between Claude Code versions. Keep a live test that
  launches `claude -p` with fixture rules and checks allow/deny outcomes; run it on every version bump.
- **Agents must not be able to approve their own asks.** Device tokens that can act as your phone are
  credentials; deny-read them.
- **Text that didn't come from you is information, not direction.** Say so in the classifier guidance,
  explicitly, for edits to standing context (memory, CLAUDE.md, settings, hooks) and for publishing.
- **Write approval buttons in the third person** ("Claude restarts the daemon"), because on a phone you read
  "I" as yourself.
- **Headless runs should start outside your repo** if the repo has broad project allows; otherwise the
  project allows quietly skip the classifier for untrusted-input jobs.

See [`examples/`](./examples) for a sample `settings.json` shape and a minimal hook.
