# Fernway Veterinary Clinics

Fernway runs four veterinary clinics in and around Ashford, with
fourteen vets and about forty staff. Pet owners book online, on the
phone or at the desk; everything goes into one PostgreSQL database,
`clinic`: the clinics, the vets, the owners and their pets, and the
appointments, which are booked, moved, confirmed and cancelled all day.
The booking site was built by a small web agency and connects as the
role `clinic_app`.

Last March the database server filled its disk overnight, and nobody knew
until the receptionists could not open the agenda the next morning. After
that, Fernway hired Tomás, a freelance system administrator, to set up
monitoring. In April he installed Prometheus, a PostgreSQL exporter and
Grafana, each on its own small machine, with a node-health dashboard
("every machine: CPU, memory, disk, services"), a PostgreSQL dashboard
and a set of alert rules. Grafana's alert list has been on a screen at
the Riverside reception desk ever since. Nothing is sent by e-mail or
phone: the staff look at the screen.

Tomás opened up access to the database while he set the exporter up. In
May the database crashed once during the night; he changed a few things
while he looked for the cause, never found it, and the crash did not
happen again. His contract ended in June and he has since moved abroad.
His notes are the configuration files themselves. One alert, "Scrape
target down", has been red since April: Tomás said it was a leftover from
the installation and harmless, and the staff have learned to ignore it.

PostgreSQL writes its log to files on the database server. Nobody at
Fernway has ever opened them.

Beatriz Lund, the practice manager, looks after IT on top of the
accounts. The winter vaccination campaign starts in a month and is the
busiest time of the year. She asks you to audit the monitoring and the
database before then: does the monitoring actually tell Fernway when
something goes wrong, and is the database in good shape? She has three
issues in particular (`issues.md`), and wants to hear about anything else
that puts the clinics at risk. She is not a database specialist:
whatever you recommend, she needs to understand why, and to know what is
worth doing first.
