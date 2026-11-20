# Partners

The companies and services the centre works with, as the centre knows
them: what each does for us, what it promises, how our systems talk to
it, and our credentials with it. Their systems are theirs: you may call
what they publish (plain HTTP on port 8000, at the hostname given, from
the bastion or any node of ours), with our credentials where one is
needed (`Authorization: Bearer <credential>`), and nothing more. Their
support desks take messages, but none will answer before your audit
ends: write in your report the message you would send them.

## Northfield Veterinary Laboratories

The external reference laboratory. Our lab sends it what it does not run
itself (PCR panels, histology, rarer serologies): the send-outs leave at
16:00 on working days.

- **Contract**: a result within one to five days of receipt, depending on
  the test (a PCR panel takes up to four days); a send-out not
  acknowledged is to be resent.
- **Interface**: `http://northfield-lab:8000/`: `POST /orders` (a
  send-out: our accession, the sample's label, species, sex, age, the
  tests), `POST /orders/<key>/resend`. Northfield posts its answers to
  our lab's order API.
- **Our credential**:
  fx-xlab_customer-0123456789abcdef
- **Support**: lab-support@northfield-vetlabs.example, working days
  08:00 to 17:00.

## The region's practices

About 120 veterinary practices with an account at our lab: they post
their orders to our lab's order API and pay for the tests every month
(the statements).

- **Contract**: each practice receives the results of its own orders,
  interim, final and amended, on its callback as soon as they are
  released; a monthly statement on the 1st.
- **Interface**: `http://practices:8000/`: `POST /results`, the practices'
  shared callback for our results.
- **Our credential**:
  fx-practices_customer-0123456789abcdef
- **Support**: the practices' network coordinator,
  practices@aldermoor-region-vets.example.

## Aldermoor Central

The franchise's central national centre (site `ALD-C`). It takes our
transfers and examination requests, answers them within a working day,
reports an examination one to three days after it, and asks us for
examinations of its own patients through our lookup API.

- **Interface**: `http://aldermoor-central:8000/`: `POST /exchanges` (a
  request), `POST /exchanges/<key>/answer`, `POST /exchanges/<key>/report`.
- **Our credential** with the franchise's centres (Central, South and
  abroad alike):
  fx-centres_customer-0123456789abcdef
- **Support**: the franchise's IT desk, it-desk@aldermoor-vets.example.

## Aldermoor South

The franchise's southern national centre (site `ALD-S`), as Aldermoor
Central: `http://aldermoor-south:8000/`, the same endpoints and our same
credential.

## Aldermoor abroad

The franchise's three centres abroad (Liège, Aachen, Luxembourg: sites
`ALD-BE`, `ALD-DE`, `ALD-LU`), reached as one at
`http://aldermoor-abroad:8000/`, as Aldermoor Central, with our same
credential.

## The franchise's head office

The regional franchise's head office receives each centre's monthly
activity figures (consultations, admissions, stays, new owners, the lab's
tests and turnaround).

- **Contract**: the figures for a month from the 1st of the next, each
  acknowledged with a reference; a centre late by the 5th is chased.
- **Interface**: `http://head-office:8000/`: `POST /figures`. It is
  sometimes unavailable for a moment: retry later.
- **Our credential**:
  fx-headoffice_customer-0123456789abcdef
- **Support**: the franchise's IT desk, it-desk@aldermoor-vets.example.

## The franchise's messaging service

The franchise's e-mail and text-message service: it delivers the
portal's invitations, document notices and vaccination reminders to the
owners. A processor: it sends what we give it and keeps nothing longer
than its delivery needs.

- **Contract**: each message accepted with a delivery id; a busy service
  answers 503, and the message is to be sent again.
- **Interface**: `http://messaging:8000/`: `POST /messages` (the address,
  the template, the animal's name, the portal's link).
- **Our credential**:
  fx-messaging_customer-0123456789abcdef
- **Support**: the franchise's IT desk, it-desk@aldermoor-vets.example.

## Cold Storage

An off-site archive service, the vault: it keeps the record's and the
lab's write-ahead log as it is archived, every server's nightly base
backup, and the machines' old days. A processor.

- **Contract**: every shipment acknowledged on receipt and listed, with
  what was declared and what was received.
- **Interface**: `http://cold-storage:8000/`: its page (`GET /`), each
  day's shipments over the last 35 days, declared against received, and
  `GET /manifests`, each shipment's manifest (`?type=`, `?source=`,
  `?from=` and `?to=` filter it, dates as `YYYY-MM-DD`). Our servers ship
  with a credential of their own, kept on them.
- **Support**: support@coldstorage-archive.example, around the clock by
  ticket.

## The veterinary authority

The national veterinary services. They receive the notifications of
listed diseases, from our vets and from our laboratory, and the yearly
antimicrobial-use report, and answer each with a reference.

- **Contract**: a category A disease notified within the hour, another
  listed disease within the day; the yearly report by mid-January. The
  service is sometimes unavailable for a moment: retry.
- **Interface**: `http://authority:8000/`: `POST /notifications`,
  `POST /amu-reports`.
- **Our credential**:
  fx-authority_customer-0123456789abcdef
- **Support**: the veterinary services' helpdesk,
  helpdesk@vet-services.example.
