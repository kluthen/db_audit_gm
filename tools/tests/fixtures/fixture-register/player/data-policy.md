# Data policy

Aldermoor Veterinary Hospitals' centre: our rules for the data we hold.
We sit in an EU member state; EU law applies as written. A figure marked
*game value* is our own choice, not the law. Beside this policy we keep
what we hold, where and for how long: our register of processing (`data-register.md`).

**Owners and keepers.** An owner's name and contacts are personal data,
and so is an animal's record or natural identifier (microchip, UELN,
passport, ear tag) beside them. They stay in the medical record
(`records`, database `clinic`). The portal (`portal`) holds copies without
address or natural identifier; the lab (`lab`) an order's identifiers; the
imaging archive (`machines`, `pacs`) the owner's family name in a study.
Each reader gets the least data its work needs: the lookup API no contact,
the ward displays and the board no identifier, the machines' logs a staff
id only. No personal data in any server's logs.

**Staff and trainees.** Staff are named in the record and the portal's
documents, never with a contact outside the clinic's. An absence records
its kind only, never a reason. A trainee's contacts are erased three years
after their last session (*game value*).

**The practices' clients.** For a practice's order the lab is the
practice's processor: their data serves that order only, and each practice
gets back only its own orders. A send-out to the external lab carries no
owner, client or natural identifier.

**What leaves.** The portal's messages go only through the franchise's
messaging service, our processor: an address, a template, the animal's
name and a link, nothing else. Results leave the lab once released.

**Retention** (*game values*). Clinical records, the lab's orders and
results, images and reports: 5 years from the last entry; medicines 5
years, controlled drugs 10; the working-time record 2 years; the machines'
logs 12 months; the portal's messages and views 2 years, sessions 30 days.
Then erased or anonymised.
