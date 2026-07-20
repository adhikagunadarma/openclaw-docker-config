# PollyReach Personal Trial Notes

Last reviewed: 2026-07-05

## Decision

PollyReach is enabled as a personal-use trial. It is not approved for
unattended calling, automatic payments, or high-risk tasks.

PollyReach is useful if the OpenClaw agent should make real phone calls or
answer a dedicated phone number for personal tasks such as:

- Calling restaurants, hotels, offices, or customer service.
- Checking booking availability or confirming appointments.
- Calling personal services where email/chat is slower.
- Taking incoming-call summaries when the user is unavailable.

It is not a general-purpose skill. It creates real-world side effects, uses
credits, stores call records/transcripts, and may contact real people.

## Source Reviewed

- ClawHub page: `https://clawhub.ai/pollyreach/skills/pollyreach`
- Direct skill file: `https://pollyreach.ai/SKILL.md`
- Referenced shell helpers:
  - `send.sh`
  - `query.sh`
  - `inbound.sh`
  - `prompt_update.sh`
  - `balance.sh`
  - `activation.sh`
  - `get_payment_config.sh`
  - `check_recharge_status.sh`

## Local Implementation Complexity

Estimated complexity: medium.

The skill itself is mostly shell wrappers around PollyReach API endpoints, so
installation is not technically large. The complexity comes from operating it
safely.

Repo changes for a controlled trial:

- PollyReach is listed in `config/skills-manifest.txt`.
- Missing runtime packages are included in `docker/Dockerfile`:
  - `jq`, required by `inbound.sh`.
  - `bc`, required by `balance.sh`.
- Personal-trial guardrails are listed in `config/security-rules.md`.
- Rebuild the OpenClaw gateway image.
- Deploy only when ready; do not run deploy from this repo review step.

## Activation Flow

The skill requires manual activation:

1. Register with PollyReach.
2. Save the returned token in the mounted OpenClaw home.
3. Open the activation link and sign in.
4. Poll activation until a dedicated number is assigned.

The token should be treated as a secret. Do not commit it and do not print it in
logs or notes.

## Personal Trial Scope

Use only for explicit personal tasks.

Allowed during trial:

- Outbound calls requested directly by the user.
- Low-risk personal inquiries and bookings.
- Incoming-call answering only after the user explicitly shares the number and
  accepts that PollyReach will answer callers.
- Manual balance checks.

Not allowed during trial:

- Financial, legal, medical, employment, or government commitments.
- Calls that authorize purchases, cancellations, refunds, or account changes
  without a fresh explicit confirmation.
- Bulk calling.
- Automatic top-up or autopay.
- Silent scheduled polling that sends summaries somewhere the user did not
  approve.

## Guardrails

Before every outbound call, require a short confirmation containing:

- Who/what to call.
- Purpose of the call.
- Any limits or forbidden commitments.
- Language preference.
- Whether the agent may leave a voicemail or message.

After every call, report:

- Target and phone number.
- Purpose.
- Result.
- Transcript or summary.
- Credits used and remaining balance if available.
- Detail or recording link if provided.

## Risks Found

- The ClawHub page showed version `v1.0.3`, while the direct
  `https://pollyreach.ai/SKILL.md` and `skill.json` showed `1.0.0`.
- The direct `SKILL.md` contains payment/autopay instructions that are too broad
  for an initial personal trial.
- Some helper scripts interpolate user text directly into JSON, so quotes or
  newlines can break requests.
- `inbound.sh` depends on `jq`; the image now installs it explicitly.
- `balance.sh` depends on `bc`; the image now installs it explicitly.
- The credential path expected by PollyReach is linked into the persistent
  OpenClaw state directory so activation survives container replacement.
- The skill requires polling for results; PollyReach does not push completion
  messages directly to the agent.

## Recommendation

For the first trial, install PollyReach only after reviewing the exact installed
package in the OpenClaw workspace. Keep autopay disabled, make every outbound
call require explicit confirmation, and avoid scheduled inbound polling until
the notification destination and privacy behavior are clear.
