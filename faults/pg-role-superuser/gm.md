# pg-role-superuser — GM notes

**What.** The role the application logs in with has `SUPERUSER`.

**Why it matters.** A superuser bypasses every permission check: it reads
and changes every database, can alter or drop any object, change server
settings, and run operating-system commands as `postgres` (`COPY ... TO
PROGRAM`). One SQL injection in the application, or one leaked password,
gives all of that away. Least privilege says the application owns its own
database objects, or holds grants on them, and nothing more.

**Why it happens.** "It did not work, so we made it superuser" during a
migration or a first install; restored role definitions carried over.

**What a good answer says.** Lists the superusers (`\du`), recognises the
application role among the administrators, explains the risk, and
proposes `ALTER ROLE <role> NOSUPERUSER`, checking that the role keeps
what the application needs (ownership of its objects, or grants on them;
the scenario's answer key says which it has). Dropping the role is not a
fix: the application could no longer log in.

**Fix path.** SQL only, as `dba`: `ALTER ROLE <role> NOSUPERUSER;`. Not a
setting, so no file or `ALTER SYSTEM` path.

**Sealed check.** Reads `rolsuper` in `pg_roles`. A dropped role reads
*fixed* with a line saying the application lost its login: judge it as
not acceptable.
