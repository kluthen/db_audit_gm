# Aldermoor Veterinary Hospitals: the agenda's, the rota's and the training centre's rules

The default policy of the centre's scheduling (v0.5 master spec 9.4,
"Scale, roles, classification, rules"; vet-scheduling-domain.md, "The
rules", ruled D317), beside the medical record's rules (vet-core
`docs/policy.md`). The GM copies it into a scenario's
`player/data-policy.md` with the core's and adapts it there, with the
`governance:` fragment beside it (`data/governance.yaml`). The centre
sits in an unnamed EU member state: EU law applies as written; a figure
marked *game value* is the clinic's choice, not the law.

1. **One place at a time.** No staff member, room, machine or teaching
   animal is allocated twice at once; the database refuses it (an
   exclusion constraint per kind of resource).
2. **Bookings follow the rota and the hours.** A booking takes a staff
   member on a shift covering it and on no absence, in its room's or
   machine's opening hours; the slot function offers no other.
3. **Working time.** Every shift is planned and clocked; at least 11
   consecutive hours' rest between two shifts, a weekly rest of 24 hours,
   at most 48 hours a week on average over four months, night work 8
   hours in 24 on average (Directive 2003/88/EC, Arts 3, 5, 6, 8, 16(b);
   the daily record of CJEU C-55/18, *CCOO*); a night shift 12 hours at
   most (*game value*); on call at home counts for the time clocked on a
   call-out (*game value*, the clinic's reading of *SIMAP*, *Jaeger*,
   *Matzak*). The rota is published each Friday for the week after next.
4. **Absences without a reason.** An absence records its kind only
   (leave, training, absent); never a diagnosis, an illness or a reason
   (GDPR Art 9: a staff member's health is special-category data), so the
   screens showing the rota show no health data.
5. **Least data in a booking.** A booking names the animal by id; the
   owner's contact stays in the record; its notes carry no owner's name
   or contact (the record's rule 10). No appointment reminder goes out in
   v0.5.
6. **Cancellations.** A cancelled booking frees its resources at once; a
   booking not checked in 30 minutes after its start is a no-show; a dead
   animal's future bookings are cancelled (`deceased`) within minutes
   (*game values*).
7. **Teaching animals.** The clinic's twelve dogs and eight horses are
   handled and examined only, nothing above a needle's insertion
   (Directive 2010/63/EU, Art 1(5)(f)); at most two sessions and four
   hours a day, and a rest day after two days in a row (*game values*).
8. **Certificates.** A certificate names the course, the dates, the hours
   attended and the lead instructor; issued only for 80 % of the course's
   hours attended (*game value*).
9. **Trainees.** Processed to run the course (GDPR Art 6(1)(b)); their
   contacts erased three years after their last session, enrolments and
   certificates kept five years (*game values*).
10. **Retention.** Bookings five years, as the clinical record (the
    record's rule 9); shifts and the working-time record two years
    (*game value*, Germany's rule); then erased.
