---
status: accepted
date: 2026-08-24
---

# PlanningAlerts gets two Postal mail servers

Every other application gets one Postal mail server, but PlanningAlerts gets two: `planningalerts` (alert emails
and other transactional mail) and `planningalerts-comments` (the comment emails it sends to councils).

Comment emails must never be silently suppressed - a council has to receive the public comments made on its
applications, which is why the app set cuttlefish's `X-Cuttlefish-Ignore-Deny-List` header on them. Postal has no
per-message bypass: its suppression list applies per mail server, and mail to a suppressed address is held rather
than sent. PlanningAlerts' alert emails to subscribers are by far OAF's highest-volume mail and produce a steady
stream of hard bounces, so on a shared mail server a council address could end up suppressed by alert traffic
alone.

Splitting the mail servers makes that structurally impossible: alert bounces land on `planningalerts`'s
suppression list and can never touch council delivery. The remaining case - a council's own address bouncing a
comment email - degrades to loud-and-manual instead of silent: `MessageHeld` webhook events from
`planningalerts-comments` go to the app's Slack notifier for a human to act on.

## Consequences

- The app carries two SMTP credentials: the default mailer configuration uses `planningalerts`, and the comment
  mailer overrides it to use `planningalerts-comments`.
- Both mail servers send from planningalerts.org.au, so the domain is added (with its SPF/DKIM records in
  `terraform/planningalerts/dns.tf`) on both.
- Both mail servers' webhooks point at the same PlanningAlerts event endpoint.
- Alternatives rejected: one mail server with automated clearing of council addresses from the suppression list
  (needs an API surface Postal may not offer, and is a moving part that can fail silently); one mail server with
  purely manual suppression-list operations (silent failure window between bounce and human).
