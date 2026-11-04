# Aldermoor Veterinary Hospitals: owners' portal data policy

The default policy of the centre's owners' portal (v0.5 master spec 9.7;
vet-portal-domain.md, "The business's own rules" and "The rules (ruled,
D320)"), beside the medical record's
([vet-core's policy](../../vet-core/docs/policy.md)) and the
laboratory's ([vet-lab's](../../vet-lab/docs/policy.md)). The GM copies
it into a scenario's `player/data-policy.md` with the core's and adapts
it there, with the `governance:` fragment beside it
(`data/governance.yaml`). The centre sits in an unnamed EU member state:
EU law applies as written; a figure marked *game value* is the portal's
choice, not the law. Sources: the GDPR (Arts 4(1), 5(1)(c), 7, 15, 17,
21, 25, 28, 32; recital 30) and the ePrivacy Directive 2002/58/EC
(Art 13).

## What an owner sees

1. **Owner scope.** An account sees the animals its owner owns now, by
   the core's current ownership, and of each the documents whose record
   falls within that ownership; never another owner's animal, never a
   record from before the sale, so never a former owner's identity (the
   core's rule 11). A keeper sees what the owner sees, while they keep
   the animal and while the owner's consent for them stands. A herd's
   documents go to its keeper. Enforced by the database's row-level
   security.
2. **The release gate.** A result is published once released by a
   clinical pathologist (the lab's rule 1), never on technical
   validation; a consultation once signed; a discharge once the stay has
   ended. An amended result is published as a new version, the first
   shown as superseded (the lab's rule 3). Each within 15 minutes of its
   gate (*game value*).
3. **Least data.** The portal's copies carry what it shows and no more:
   no address, no natural identifier (GDPR Art 5(1)(c), Art 25). A
   document carries no free text (the findings, a pathologist's comment,
   an alert) and no staff contact, the vet's name only (the core's rule
   11). The region's practices' patients never enter the portal (the
   lab's rule 10).

## Accounts and consents

4. **Accounts.** One per core owner, the clinic aside, invited at
   registration by a one-time link valid 14 days (*game value*); a
   password stored as a bcrypt hash at cost 6 (*game value*), never
   stored, sent or logged in clear; five failed logins lock the account
   for 30 minutes (*game value*); a session ends after 30 minutes idle
   or 12 hours (*game values*), its token stored as a hash (GDPR Art 32).
   Contacts are the core's, changed only at its desk.
5. **Closing an account** (GDPR Art 17). On the owner's request: its
   personal columns erased at once, its sessions ended, a closure
   message sent; the consent events kept as proof (Art 7(1)); never
   reopened by the copy from the core; the core's record untouched, its
   medicine records kept five years (the core's rule 10, Art 17(3)(b)).
6. **Consents.** Every grant and withdrawal is an event: the owner, the
   purpose (`reminders`, or `keeper-access` with the animal and the
   keeper), granted or withdrawn, when, and where (activation, the
   portal, a message's link, the desk). The truth is the latest event;
   the account's `reminders` flag is a convenience no job reads. A
   withdrawal takes effect at once, from the next message (Art 7(3)).
   Reminders only with consent (*game value*: the opt-in, where the
   existing-customer exception of the ePrivacy Directive, Art 13, would
   allow an opt-out).

## Messages

7. **Messages.** Only through the franchise's messaging service, the
   centre's processor (GDPR Art 28). A message carries its address, its
   template, the animal's name and a link; never a result, a diagnosis,
   a natural identifier, a password or another owner's data. An
   invitation or a reset carries a one-time token. Reminders are sent
   08:00 to 20:00, never for an animal that has died, never to anyone
   but its current owner, never to a closed account, each with a
   withdrawal link. Every message has its key, kept on a retry.

## Records

8. **Audit.** Every document opened is recorded: the account, the
   document, the time; with the notices, what was released to whom.
   pgaudit on the portal's database logs writes, schema changes and role
   changes (`pgaudit.log = 'write, ddl, role'`), its statements'
   parameters off (`pgaudit.log_parameter = off`), since passwords pass
   through SQL.
9. **Logs.** No password, token or personal data in the server's logs:
   on the portal's database no statement logging
   (`log_statement = none`), parameters never logged (the core's rule
   10).
10. **Reach.** The portal's API reaches the portal's database only, over
    TLS; never the medical record's or the back office's (`pg_hba.conf`,
    `CONNECT`).
11. **Retention** (*game values*). Documents as long as the record they
    show, five years (the core's rule 9); views and messages two years;
    sessions 30 days, purged nightly; consent events as long as the
    account and five years after, the proof of consent; a closed
    account's personal columns at once.

## Who reads what

| Role | Reads | Writes |
|---|---|---|
| `portal_api`, the portal's API | through the row-level security: the asker's animals, ownerships, herds and documents, its own account without the hashes and its own consent events; the settings | views, its own consent events, its account's channel and reminders flag; the sessions, the outbox and the authentication only through the portal's functions |
| `portal_housekeeping`, the sessions' purge | the sessions | deletes the sessions ended 30 days ago |

The tables belong to `portal`, a role nobody logs in as. The portal's
database is opened only by the roles named for it; no other application
of the centre connects to it.
