# Pages & Co

Pages & Co is an independent bookshop with two shops and a website. The
website, the back office and the staff's reports all use one PostgreSQL
database, `bookshop`: customers, books, orders and their lines.

For years the database ran on an ageing server, with a second server
kept in sync next to it in case the first one failed. Last month the
first server's disks started to fail. A contractor moved the database to
a new machine with fast SSD storage, restoring it from the last backup,
and set PostgreSQL up there. The second server was switched off with the
old one; nobody has decided yet whether the new set-up needs one.

The contractor's engagement ended the day after the move. There are no
notes beyond the configuration files themselves.

Three weeks after the move, things are not quite right, and the
year-end season, when the shop takes a third of its orders, is coming. Samira Haddad, who
runs the shop's IT on top of the accounts, has asked you for an audit of
the database server before then.

What she can tell you:

- The website and the back office connect as the role `shop_app`. The
  staff's reports run in the back office too.
- Month-end is when the staff run their heaviest reports, several at a
  time.
- The shop's insurer has sent a cyber-security questionnaire.
- Nobody at the shop knows PostgreSQL well. Whatever you recommend, she
  needs to understand why.

She has asked you to look at three issues in particular (`issues.md`),
and to report anything else you find that puts the database or the
business at risk.
