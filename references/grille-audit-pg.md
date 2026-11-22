> **Informative reference, not a requirement** (spec D558). The owner's
> PostgreSQL audit grid, copied verbatim on 2026-11-19 (refreshed 2026-11-21, O299) from the owner's
> own material (`/home/bastien/audits/grille_audit_pg.md`), in French as
> written, for a separate workshop on the Bluebox dataset: its "Dans le
> labo" boxes, scripts (`revue_config_pg.sh`, `lab …`), Grafana dashboard
> names and file paths are that workshop's, not this game's. It shows how
> a real PostgreSQL audit is run, and goes beyond what the players may do
> in a game (restore tests, installing extensions, the host axis,
> week-long windows, 30 to 45 minutes per axis), where each issue's
> resolution, each node's write policy, the `sudo` wrappers and the
> validators' envelopes bound what they do. The game assistant may draw
> on it as an example; it is not its method, and nothing enforces it.
> It lives in `references/` at the clone's root, beside the game
> assistant's definitions (`.claude/agents/game-assistant.md`,
> `.opencode/agents/game-assistant.md`), whose section "The audit grid"
> says where it meets the game. A game-scoped English rewrite is
> optional and later.
> The text below this note is never edited: replace it with a fresh copy
> if the owner's grid changes.

# Grille d'audit PostgreSQL — méthode et axes de balayage

Méthode pour mener un audit sans se perdre dans la première anomalie venue.
Écrite pour l'atelier Bluebox, mais valable pour un audit réel : chaque axe
donne la question, où regarder, les requêtes, ce qui doit alerter et la
section du compte rendu (modèle `_template_cr_audit-tri.md`) qu'il alimente.
Les particularités du labo sont dans les encadrés « Dans le labo ».

Le registre des constats et les fiches d'investigation sont tenus à part
(pour l'atelier : `trouvailles_atelier_bluebox.md`).

Requêtes vérifiées sur PostgreSQL 19 (un serveur 19.0 jetable, 19/11/2026 ;
avant sur PostgreSQL 18, `pg-primary`, 27/10/2026). Toutes sont
en lecture seule ; les lancer dans une session
`SET default_transaction_read_only = on;`. Seule exception :
l'échantillonnage « Qui émet une requête » crée une table temporaire, ce
que PostgreSQL refuse dans une transaction en lecture seule (tout `CREATE`
l'est) ; le lancer dans une session à part, sans ce réglage. Il n'écrit
que dans sa table temporaire, propre à la session.

---

## 1. Déroulé

| Étape | But | Produit |
|---|---|---|
| 0. Cadrer | Savoir ce qu'on observe et depuis quand | Fenêtre, topologie, dates de remise à zéro, chronogramme |
| 1. Balayer | Passer **tous** les axes, sans creuser | Constats bruts dans le registre |
| 2. Trier | Gravité, regroupement par cause probable | Registre trié, ordre d'investigation |
| 3. Investiguer | Un groupe à la fois, gabarit fixe | Fiches : cause, recommandation, preuve |
| 4. Rédiger | Au fil de l'eau | Sections du CR, tableau de recommandations |

### Règles

1. **Balayer avant de creuser.** Un axe se passe en une fois (30 à 45 min).
   Ce qui intrigue devient une ligne du registre, et on passe à la suite.
   Seule exception : un risque d'arrêt ou de perte de données (disque plein,
   wraparound proche, archivage en échec), traité tout de suite.
   Creuser la première anomalie venue fait passer des heures sur un point
   peut-être secondaire, et laisse des axes entiers jamais regardés. Le
   tour complet donne aussi des liens entre constats qu'une investigation
   isolée ne voit pas.
2. **Un constat est un fait** : un chiffre, sa source, son heure ou sa
   période. L'interprétation vient à l'étape 3. « `commande` : 30 % de
   lignes mortes (`pg_stat_user_tables`, cumul au 15/03) » est un constat ;
   « l'autovacuum est mal réglé » n'en est pas un.
3. **Les compteurs sont cumulés** depuis leur remise à zéro : toujours la
   relever (`stats_reset`) et raisonner en débit (par jour, par appel).
   Pour une évolution dans le temps, utiliser l'historique de pgwatch.
4. **Une trouvaille rattachée à un axe ne dispense pas de finir l'axe.**
5. **Dans le labo** : ne pas ouvrir `bluebox-lab/images/load/INCIDENTS.md`
   ni `lab_load/incidents.py` avant la fin. C'est le corrigé : il sert à
   mesurer la couverture du balayage une fois l'audit rédigé.

### Gravité

| Niveau | Sens |
|---|---|
| Critique | Risque d'arrêt de l'instance ou de perte de données |
| Majeur | Dégradation visible des utilisateurs, ou dérive qui y mènera |
| Mineur | Optimisation, hygiène |
| Info | À savoir, sans action |

### Gabarit d'investigation (étape 3)

Constat → hypothèse → test → cause → recommandation → preuve avant/après.
La fiche T1 de `trouvailles_atelier_bluebox.md` en est le modèle.

---

## 2. Les axes

| Axe | Question | Section du CR |
|---|---|---|
| A0 | Que regarde-t-on, sur quelle période ? | Introduction |
| A1 | La configuration est-elle saine ? | Revue de configuration |
| A2 | Quelle charge, quelles sessions ? | Métriques |
| A3 | Quelles requêtes coûtent ? | Métriques, pgBadger |
| A4 | Les transactions se gênent-elles ? | pgCluu, pgBadger |
| A5 | Le VACUUM fait-il son travail ? | Procédures › Maintenance |
| A6 | Les index servent-ils, en manque-t-il ? | Procédures › Maintenance |
| A7 | Mémoire, écritures, WAL : où est le goulot ? | pgCluu, Persistance |
| A8 | Que disent les journaux ? | pgBadger |
| A9 | La réplication tient-elle ? | Réplication |
| A10 | Sait-on restaurer, en combien de temps ? | Procédures › Sauvegardes |
| A11 | Le système hôte suit-il ? | pgCluu, Paramètres kernel |

### A0 — Cadre et chronogramme

**Question** : qu'observe-t-on, depuis quand, et à quoi ressemble une
journée type ?

**Pourquoi c'est important** : Sans fenêtre ni date de remise à zéro, un
compteur ne veut rien dire : des interblocages en un jour ou en un an, ce
n'est pas le même constat. Le chronogramme transforme des anomalies isolées
en motifs : ce qui revient chaque jour à la même heure a une cause
planifiée, qu'on peut aller observer en direct au lieu de la reconstituer
après coup.

**À relever** :
- fenêtre d'observation (au moins 7 jours pour voir les cycles
  quotidiens ; un trimestre pour un audit trimestriel) ;
- topologie de mesure (« moteur seul » ou « de bout en bout ») ;
- dates de remise à zéro des statistiques ;
- traitements planifiés connus (sauvegardes, batchs, purges).

```sql
SELECT 'pg_stat_database' AS vue, stats_reset FROM pg_stat_database WHERE datname = current_database()
UNION ALL SELECT 'pg_stat_statements', stats_reset FROM pg_stat_statements_info
UNION ALL SELECT 'pg_stat_checkpointer', stats_reset FROM pg_stat_checkpointer
UNION ALL SELECT 'pg_stat_wal', stats_reset FROM pg_stat_wal;
```

Une valeur `NULL` : jamais remise à zéro depuis la création de la base.

**Chronogramme** : dans Grafana, sur 7 jours, les tableaux *2. Database
Overview* (transactions, blocs, temps), *Sessions overview* (états,
transaction la plus longue) et *Checkpointer / Bgwriter / Block IO Stats*.
Repérer ce qui revient **chaque jour à la même heure**, puis zoomer sur
24 h. Chaque motif devient une ligne du chronogramme, et souvent un
constat. C'est le fil conducteur des axes A2 à A8 : on sait à quelle heure
regarder en direct.

> **Dans le labo** : heures du labo en heure de Paris (`LAB_TZ`), heures
> PostgreSQL et journaux en UTC (`timezone = 'UTC'`). Statistiques
> cumulées depuis le 19/10 07:33 UTC (restauration de Bluebox).
> Planifié connu : sauvegarde pgBackRest à 01:30 (`BACKUP_AT`).

### A1 — Configuration

**Question** : version, fichiers, noyau, mémoire, persistance, réplication,
traces et maintenance sont-ils bien réglés ?

**Pourquoi c'est important** : La configuration est une cause fréquente et
la moins chère à corriger. C'est aussi la base des autres axes : on ne juge
un checkpoint ou un autovacuum qu'en connaissant les réglages qui le
pilotent. Les réglages posés hors de `postgresql.conf` (`ALTER SYSTEM`, par
table, par rôle) sont ceux qu'on oublie, et qui font qu'une instance ne se
comporte pas comme son fichier le laisse croire.

**Outil** : `scripts/revue_config_pg.sh`, qui pré-remplit la section et liste
ses points « à revoir ». Chaque point « à revoir » validé devient un constat.

**Ce qui doit alerter** : ce que le script relève ; s'y ajoutent les
réglages modifiés à chaud (`ALTER SYSTEM`) et les options posées table par
table, que le script ne voit pas :

```sql
SELECT name, setting, source, sourcefile FROM pg_settings
WHERE source NOT IN ('default', 'override', 'client', 'session') ORDER BY source, name;

SELECT c.oid::regclass AS objet, c.reloptions FROM pg_class c
WHERE c.reloptions IS NOT NULL
  AND c.relnamespace NOT IN ('pg_catalog'::regnamespace, 'information_schema'::regnamespace);

SELECT r.rolname, d.datname, s.setconfig FROM pg_db_role_setting s
LEFT JOIN pg_roles r ON r.oid = s.setrole LEFT JOIN pg_database d ON d.oid = s.setdatabase;
```

**Section du CR** : Revue de configuration.

### A2 — Charge et sessions

**Question** : qui se connecte, combien, avec quel taux d'échec, et comment
la charge varie-t-elle dans la journée ?

**Pourquoi c'est important** : C'est le contexte de tout le reste : une
requête lente à 3 h du matin et la même à l'heure de pointe ne pèsent pas
pareil. Le nombre de connexions est une limite dure : au-delà de
`max_connections`, l'application reçoit des erreurs, et chaque connexion
coûte un processus et de la mémoire. Les rollbacks et les sessions
interrompues sont souvent le premier signe d'erreurs applicatives que
personne ne remonte.

**Où regarder** : Grafana *2. Database Overview* (TPS, commits / rollbacks),
*Sessions overview*, *PgBouncer stats* ; console PgBouncer (`SHOW POOLS;`,
`SHOW STATS;`).

```sql
-- Sessions par utilisateur, application et état
SELECT usename, application_name, state, count(*) AS n
FROM pg_stat_activity WHERE backend_type = 'client backend'
GROUP BY 1, 2, 3 ORDER BY n DESC;

-- Volume, rollbacks, sessions anormalement terminées (cumul)
SELECT numbackends, current_setting('max_connections') AS max_connections,
       xact_commit, xact_rollback,
       round(100.0 * xact_rollback / nullif(xact_commit + xact_rollback, 0), 2) AS pct_rollback,
       sessions, sessions_abandoned, sessions_fatal, sessions_killed, stats_reset
FROM pg_stat_database WHERE datname = current_database();
```

**Ce qui doit alerter** :
- connexions au-delà de 80 % de `max_connections`, ou beaucoup de sessions
  `idle` : besoin d'un pooler ou pooler mal dimensionné ;
- `pct_rollback` au-dessus de 1 à 2 % : erreurs côté application (à
  croiser avec A8) ;
- `sessions_fatal`, `sessions_killed` ou `sessions_abandoned` en hausse ;
- nombre de sessions très élevé rapporté à la durée : connexion par requête
  (coût d'établissement, voir PgBouncer) ;
- côté PgBouncer : `cl_waiting` non nul, `maxwait` qui grandit.

**Section du CR** : Analyse des métriques.

### A3 — Requêtes

**Question** : quelles requêtes consomment le temps, les lectures, les
fichiers temporaires et les WAL ?

**Pourquoi c'est important** : Quelques requêtes concentrent presque
toujours l'essentiel du temps : c'est là que l'effort rapporte le plus,
souvent par un index ou une réécriture, sans matériel en plus. Classer selon
plusieurs critères évite de manquer une requête peu coûteuse en temps mais
qui lit le disque, déborde en fichiers temporaires ou produit des WAL, donc
de l'archivage et de la réplication.

**Où regarder** : `pg_stat_statements` (cumul), Grafana *3. Query
Performance Analysis* et *Single query details* (par queryid, dans le
temps), pgBadger (requêtes au-delà de `log_min_duration_statement`).

```sql
-- Top par temps total ; changer l'ORDER BY pour les autres classements
SELECT s.queryid, r.rolname, s.calls,
       round(s.total_exec_time / 1000) AS total_s,
       round(s.mean_exec_time::numeric, 1) AS moy_ms,
       round(s.stddev_exec_time::numeric, 1) AS ecart_type_ms,
       round((100 * s.total_exec_time / sum(s.total_exec_time) OVER ())::numeric, 1) AS pct,
       (s.shared_blks_hit + s.shared_blks_read) / nullif(s.calls, 0) AS blocs_par_appel,
       s.rows / nullif(s.calls, 0) AS lignes_par_appel,
       s.temp_blks_written, pg_size_pretty(s.wal_bytes) AS wal,
       left(regexp_replace(s.query, '\s+', ' ', 'g'), 60) AS requete
FROM pg_stat_statements s JOIN pg_roles r ON r.oid = s.userid
ORDER BY s.total_exec_time DESC LIMIT 15;

-- L'extension perd-elle des requêtes ?
SELECT dealloc, stats_reset FROM pg_stat_statements_info;
```

**Qui émet une requête** : `pg_stat_statements` ne connaît que le rôle.
Plusieurs applications peuvent partager un rôle ; pour retrouver
l'`application_name`, on relie le `queryid` au `query_id` de
`pg_stat_activity` (renseigné si `compute_query_id` vaut `auto` ou `on`).
Les requêtes courtes échappent à une photo : on échantillonne quelques
minutes dans une table temporaire (elle disparaît à la fin de la session
`psql`). Le `CREATE TEMP TABLE` est refusé en lecture seule : lancer ce
bloc dans une session ouverte sans `default_transaction_read_only`, à part
des autres requêtes.

```sql
-- Session à part, sans default_transaction_read_only (le CREATE y serait refusé)
CREATE TEMP TABLE echantillons AS
SELECT now() AS t, pid, usename, application_name, state, query_id,
       wait_event_type, wait_event
FROM pg_stat_activity WHERE false;

-- Pas de « ; » final : \watch exécute la requête (ici 300 fois, toutes les secondes ; psql 16 et plus)
INSERT INTO echantillons
SELECT now(), pid, usename, application_name, state, query_id,
       wait_event_type, wait_event
FROM pg_stat_activity
WHERE backend_type = 'client backend' AND pid <> pg_backend_pid()
  AND query_id IN (/* queryid du top */)
\watch i=1 c=300

SELECT query_id, application_name, usename,
       count(*)                                              AS echantillons,
       count(DISTINCT pid)                                   AS sessions,
       count(*) FILTER (WHERE state = 'active')              AS actif,
       count(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_tx,
       string_agg(DISTINCT coalesce(wait_event_type || ':' || wait_event, 'CPU'), ', ')
           FILTER (WHERE state = 'active')                   AS attentes_si_actif
FROM echantillons
GROUP BY 1, 2, 3
ORDER BY 1, 4 DESC;
```

Lecture : hors de l'état `active`, `query_id` est celui de la **dernière**
requête de la session (un `idle in transaction` avec le queryid d'un
`UPDATE` : écriture faite, `COMMIT` pas encore envoyé). `CPU` signifie
qu'aucune attente n'est déclarée ; `Lock:…` ou `LWLock:…` renvoie à A4.
Seules les requêtes de premier niveau ont un `query_id` : les contrôles
de clé étrangère (`SELECT 1 FROM ONLY … FOR KEY SHARE`, exécutés sous le
propriétaire de la table parente) n'y figurent pas. Autre source :
`%a` dans `log_line_prefix`, puis pgBadger.

Classements à faire, un par un : `total_exec_time` (ce qui coûte au
serveur), `calls` (le bruit de fond), `mean_exec_time` (ce que voit
l'utilisateur), `shared_blks_read` (ce qui sollicite le disque),
`temp_blks_written` (tris et hachages qui débordent de `work_mem`),
`wal_bytes` (ce qui écrit).

**Ce qui doit alerter** :
- une requête à plus de 10 % du temps total ;
- beaucoup de blocs pour peu de lignes (`blocs_par_appel` /
  `lignes_par_appel` au-delà de 100) : index manquant ou inadapté (A6) ;
- un temps moyen élevé pour peu de blocs : attente (verrou, contention sur
  une ligne : A4) plutôt que calcul ;
- `ecart_type_ms` supérieur à la moyenne : plans ou paramètres instables ;
- une requête très rapide appelée énormément : boucle côté application ;
- `temp_blks_written` non nul sur une requête fréquente ;
- `dealloc` non nul : `pg_stat_statements.max` trop petit, classement faussé.

**Section du CR** : Analyse des métriques, Analyse pgBadger.

### A4 — Transactions, verrous, concurrence

**Question** : des transactions restent-elles ouvertes, se bloquent-elles,
retiennent-elles l'horizon du VACUUM ?

**Pourquoi c'est important** : Une transaction ouverte ne coûte presque rien
en CPU, mais elle touche toute l'instance : elle garde ses verrous et bloque
d'autres sessions, et elle fige l'horizon du VACUUM, qui ne peut plus
nettoyer les lignes mortes plus récentes, dans aucune table. Ces problèmes
sont intermittents et invisibles dans les moyennes : il faut aller les
chercher.

**Où regarder** : en direct `pg_stat_activity` ; dans le temps Grafana
*Sessions overview* (transaction la plus longue, sessions bloquées) ;
pgBadger (*Locks*, grâce à `log_lock_waits`).

```sql
-- Transactions ouvertes, de la plus ancienne à la plus récente
SELECT pid, usename, application_name, state,
       now() - xact_start AS duree_tx, now() - state_change AS dans_cet_etat_depuis,
       backend_xid, backend_xmin, wait_event_type, wait_event,
       left(query, 60) AS derniere_requete
FROM pg_stat_activity
WHERE xact_start IS NOT NULL AND pid <> pg_backend_pid()
ORDER BY xact_start;

-- Qui bloque qui
SELECT a.pid, a.usename, a.application_name, now() - a.xact_start AS duree_tx,
       a.wait_event_type, a.wait_event, pg_blocking_pids(a.pid) AS bloque_par,
       left(a.query, 50) AS requete
FROM pg_stat_activity a WHERE cardinality(pg_blocking_pids(a.pid)) > 0;

-- Ce qui retient l'horizon du VACUUM (sessions, slots, transactions préparées)
SELECT 'session' AS source, pid::text AS qui, backend_xmin AS xmin, age(backend_xmin) AS age
FROM pg_stat_activity WHERE backend_xmin IS NOT NULL
UNION ALL
SELECT 'slot', slot_name::text, xmin, age(xmin) FROM pg_replication_slots WHERE xmin IS NOT NULL
UNION ALL
SELECT 'transaction préparée', gid, transaction, age(transaction) FROM pg_prepared_xacts
ORDER BY age DESC LIMIT 10;

-- Interblocages et conflits de réplication (cumul)
SELECT deadlocks, conflicts FROM pg_stat_database WHERE datname = current_database();
```

**Ce qui doit alerter** :
- `idle in transaction` au-delà d'une minute ;
- une transaction de plusieurs minutes, surtout si elle a un `backend_xid`
  ou un `backend_xmin` : elle empêche le VACUUM de nettoyer toute la base ;
- des sessions bloquées de façon répétée (même heure, même application) ;
- `deadlocks` non nul : retrouver les requêtes dans les journaux ;
- une transaction préparée oubliée, un slot avec un `xmin` ancien.

**Méthode** : les incidents de concurrence sont souvent passagers. Le
chronogramme (A0) dit quand ils se produisent ; y être en direct avec les
requêtes ci-dessus.

**Section du CR** : Analyse pgCluu, Analyse pgBadger.

### A5 — Maintenance : VACUUM, ANALYZE, gel

**Question** : les lignes mortes sont-elles récupérées, les statistiques
sont-elles à jour, le gel des identifiants de transaction suit-il ?

**Pourquoi c'est important** : Avec le MVCC, chaque `UPDATE` et chaque
`DELETE` laisse une ligne morte. Si le VACUUM ne les récupère pas, tables et
index grossissent, les parcours lisent des pages à moitié vides, les Index
Only Scans retournent à la table, et l'espace ne revient pas sans opération
lourde (`VACUUM FULL`, `pg_repack`). Les statistiques d'ANALYZE guident le
planificateur : périmées, elles donnent de mauvais plans. Le gel est le seul
point de maintenance qui peut arrêter l'instance : à l'approche de la limite
des identifiants de transaction, PostgreSQL refuse les écritures pour
protéger les données.

**Où regarder** : `pg_stat_user_tables` ; Grafana *4. Tables Overview* et
*5. Table Details* (courbe `n_dead_tup` : des dents de scie montrent un
autovacuum qui passe, une rampe sans fin le contraire) ; pgBadger
(*Vacuums*, grâce à `log_autovacuum_min_duration` ; sur PostgreSQL 19, les
ANALYZE automatiques ont leur propre réglage, `log_autoanalyze_min_duration`).

```sql
-- Lignes mortes et derniers passages
SELECT relname, n_live_tup, n_dead_tup,
       round(100.0 * n_dead_tup / nullif(n_live_tup + n_dead_tup, 0), 1) AS pct_mortes,
       n_mod_since_analyze, last_autovacuum, last_autoanalyze,
       autovacuum_count, round(total_autovacuum_time / 1000) AS autovacuum_s,
       pg_size_pretty(pg_total_relation_size(relid)) AS taille
FROM pg_stat_user_tables ORDER BY n_dead_tup DESC LIMIT 15;

-- Seuil réel de déclenchement, options de table comprises (PostgreSQL 18 :
-- plafonné par autovacuum_vacuum_max_threshold)
WITH o AS (
  SELECT c.oid, c.relname, c.reltuples,
         (SELECT option_value::float8 FROM pg_options_to_table(c.reloptions) WHERE option_name = 'autovacuum_vacuum_threshold') AS t,
         (SELECT option_value::float8 FROM pg_options_to_table(c.reloptions) WHERE option_name = 'autovacuum_vacuum_scale_factor') AS sf,
         (SELECT option_value FROM pg_options_to_table(c.reloptions) WHERE option_name = 'autovacuum_enabled') AS actif
  FROM pg_class c WHERE c.relkind IN ('r', 'm')
    AND c.relnamespace NOT IN ('pg_catalog'::regnamespace, 'information_schema'::regnamespace))
SELECT o.relname, coalesce(o.actif, 'défaut') AS autovacuum_enabled, s.n_dead_tup,
       round(least(coalesce(o.t, current_setting('autovacuum_vacuum_threshold')::float8)
             + coalesce(o.sf, current_setting('autovacuum_vacuum_scale_factor')::float8) * greatest(o.reltuples, 0),
             current_setting('autovacuum_vacuum_max_threshold')::float8)) AS seuil_vacuum
FROM o JOIN pg_stat_user_tables s ON s.relid = o.oid
ORDER BY s.n_dead_tup DESC LIMIT 15;

-- Gel : distance au VACUUM forcé anti-wraparound
SELECT datname, age(datfrozenxid) AS age_xid, mxid_age(datminmxid) AS age_mxid,
       round(100.0 * age(datfrozenxid) / current_setting('autovacuum_freeze_max_age')::int, 1) AS pct_avant_freeze_force
FROM pg_database ORDER BY age_xid DESC;

-- VACUUM en cours
SELECT pid, relid::regclass, phase, heap_blks_scanned, heap_blks_total FROM pg_stat_progress_vacuum;
```

**Ce qui doit alerter** :
- `autovacuum_enabled = off` sur une table qui reçoit des écritures ;
- plus de 20 % de lignes mortes sur une table volumineuse, ou une table
  écrite chaque jour dont le dernier autovacuum date de plusieurs jours ;
- un seuil de déclenchement hors de portée (comparer `seuil_vacuum` au
  nombre de lignes mortes produites par jour) ;
- un autovacuum qui passe sans faire baisser les lignes mortes : horizon
  retenu (A4) ;
- `pct_avant_freeze_force` au-delà de 50 % : à surveiller ; au-delà de
  80 % : critique ;
- statistiques jamais recalculées sur une table qui change (`last_autoanalyze`
  ancien, `n_mod_since_analyze` élevé) : plans faussés (A3).

**Pour mesurer le gonflement** (bloat) d'une table suspecte, l'extension
`pgstattuple` est disponible mais pas installée sur le labo :
`pgstattuple_approx('table')` lit la table, à éviter en pleine charge.

**Section du CR** : Procédures › Maintenance.

### A6 — Index

**Question** : les index existants servent-ils, en manque-t-il, les mises
à jour restent-elles HOT ?

**Pourquoi c'est important** : Un index manquant fait lire des tables
entières. Un index en trop se paie à chaque écriture, occupe du cache,
rallonge chaque VACUUM et peut empêcher les mises à jour HOT. Les deux se
corrigent sans toucher à l'application : le rapport gain / effort est
souvent le meilleur de l'audit.

**Où regarder** : `pg_stat_user_indexes`, `pg_stat_user_tables` ; Grafana
*Index overview*.

```sql
-- Index jamais utilisés (hors unicité et clés primaires)
SELECT s.relname, s.indexrelname, s.idx_scan, pg_size_pretty(pg_relation_size(s.indexrelid)) AS taille
FROM pg_stat_user_indexes s JOIN pg_index i USING (indexrelid)
WHERE s.idx_scan = 0 AND NOT i.indisunique AND NOT i.indisprimary
ORDER BY pg_relation_size(s.indexrelid) DESC;

-- Index en double (mêmes colonnes, mêmes opérateurs, même prédicat)
SELECT indrelid::regclass AS table_, array_agg(indexrelid::regclass) AS index_identiques
FROM pg_index GROUP BY indrelid, indkey::text, indclass::text,
     coalesce(indexprs::text, ''), coalesce(indpred::text, '')
HAVING count(*) > 1;

-- Index invalides (CREATE INDEX CONCURRENTLY interrompu)
SELECT indexrelid::regclass AS index_invalide FROM pg_index WHERE NOT indisvalid;

-- Tables lues en parcours séquentiel
SELECT relname, seq_scan, seq_tup_read, seq_tup_read / nullif(seq_scan, 0) AS lignes_par_parcours,
       idx_scan, n_live_tup
FROM pg_stat_user_tables WHERE seq_scan > 0 ORDER BY seq_tup_read DESC LIMIT 10;

-- Part des mises à jour HOT (sans toucher aux index)
SELECT s.relname, s.n_tup_upd, s.n_tup_hot_upd,
       round(100.0 * s.n_tup_hot_upd / nullif(s.n_tup_upd, 0), 1) AS pct_hot,
       (SELECT option_value FROM pg_options_to_table(c.reloptions) WHERE option_name = 'fillfactor') AS fillfactor
FROM pg_stat_user_tables s JOIN pg_class c ON c.oid = s.relid
WHERE s.n_tup_upd > 0 ORDER BY s.n_tup_upd DESC LIMIT 10;
```

**Ce qui doit alerter** :
- un index en double : pure perte (écritures, cache, VACUUM) ;
- un index jamais utilisé sur une table écrite, si les statistiques couvrent
  un cycle complet d'activité (traitements mensuels compris) ;
- un index invalide ;
- une grosse table souvent parcourue en entier (`lignes_par_parcours`
  proche de `n_live_tup`) : à relier aux requêtes de A3 ;
- moins de 50 % de mises à jour HOT sur une table très mise à jour :
  colonne modifiée indexée, ou pages pleines (`fillfactor`).

**Prudence** : supprimer un index est une recommandation, jamais un geste
de l'audit. Vérifier aussi les répliques, qui ont leurs propres compteurs.

**Section du CR** : Procédures › Maintenance (et pistes post-audit).

### A7 — Mémoire, écritures, WAL

**Question** : le cache suffit-il, les checkpoints sont-ils réguliers, qui
écrit sur disque, combien de WAL produit-on ?

**Pourquoi c'est important** : C'est là qu'on distingue un problème de
dimensionnement (mémoire, disque) d'un problème de requêtes. Les checkpoints
et le volume de WAL rythment toutes les écritures : mal réglés, ils créent
des pics de latence réguliers et gonflent l'archivage et la réplication. Une
seule somme de contrôle en échec signale une corruption, à traiter avant
tout le reste.

**Où regarder** : Grafana *Checkpointer / Bgwriter / Block IO Stats* ;
pgBadger (*Checkpoints*, *Temporary files*) ; pgCluu.

```sql
-- Cache, fichiers temporaires, temps d'I/O (track_io_timing), sommes de contrôle
SELECT round(100.0 * blks_hit / nullif(blks_hit + blks_read, 0), 2) AS hit_ratio,
       temp_files, pg_size_pretty(temp_bytes) AS temp,
       round(blk_read_time / 1000) AS lecture_s, round(blk_write_time / 1000) AS ecriture_s,
       checksum_failures
FROM pg_stat_database WHERE datname = current_database();

-- Checkpoints : planifiés ou forcés par le volume de WAL
SELECT num_timed, num_requested,
       round(100.0 * num_requested / nullif(num_timed + num_requested, 0), 1) AS pct_demandes,
       round(write_time / 1000) AS ecriture_s, round(sync_time / 1000) AS sync_s,
       buffers_written, stats_reset
FROM pg_stat_checkpointer;
SELECT buffers_clean, maxwritten_clean, buffers_alloc, stats_reset FROM pg_stat_bgwriter;

-- WAL : volume, pages complètes, tampon plein
SELECT wal_records, wal_fpi, round(100.0 * wal_fpi / nullif(wal_records, 0), 1) AS pct_fpi,
       pg_size_pretty(wal_bytes) AS volume, wal_buffers_full, stats_reset
FROM pg_stat_wal;

-- Qui écrit et qui synchronise (pg_stat_io)
SELECT backend_type, object, context, reads, writes, extends, fsyncs, evictions
FROM pg_stat_io WHERE coalesce(writes, 0) + coalesce(fsyncs, 0) > 0
ORDER BY writes DESC NULLS LAST;
```

**Ce qui doit alerter** :
- `hit_ratio` sous 99 % en transactionnel. L'inverse ne prouve rien : un
  hit ratio de 100 % peut cacher une requête qui lit des centaines de
  milliers de blocs par appel, tous en cache (A3) ;
- des fichiers temporaires nombreux ou volumineux : retrouver les requêtes
  dans pgBadger (`log_temp_files`) avant de toucher à `work_mem` ;
- plus de 10 % de checkpoints demandés : `max_wal_size` trop petit ;
- `write_time` élevé : normal, l'écriture est étalée exprès
  (`checkpoint_completion_target`) ; `sync_time` élevé : disque lent ;
- `maxwritten_clean` qui grimpe : le bgwriter est bridé
  (`bgwriter_lru_maxpages`) ;
- des écritures de `client backend` en `relation / normal` du même ordre
  que celles du checkpointer : les sessions évincent elles-mêmes des pages
  sales, `shared_buffers` ou le bgwriter ne suivent pas ;
- `wal_buffers_full` qui augmente vite : `wal_buffers` trop petit ;
- `checksum_failures` non nul : **critique**, corruption.

**Section du CR** : Analyse pgCluu, Persistance.

### A8 — Journaux

**Question** : quelles erreurs, quelles requêtes lentes, quels
avertissements ?

**Pourquoi c'est important** : Les journaux gardent ce que les statistiques
cumulées perdent : le texte des erreurs, les requêtes réelles avec leurs
paramètres, les attentes de verrou, les fichiers temporaires requête par
requête. Une erreur répétée en boucle est souvent un bug applicatif que
personne n'a vu, parce que l'application la masque ou la rejoue.

**Outil** : pgBadger sur au moins 24 h, idéalement toute la fenêtre.

```sql
-- Journaux disponibles (rôle pg_monitor ou superutilisateur)
SELECT name, pg_size_pretty(size) AS taille, modification FROM pg_ls_logdir() ORDER BY modification DESC;
```

Décompte rapide par niveau, sur l'hôte :
`grep -hoE '(PANIC|FATAL|ERROR|WARNING):' postgresql-*.log | sort | uniq -c`

**À lire dans pgBadger** : *Events* (erreurs les plus fréquentes, avec la
requête), *Top* (requêtes lentes, à croiser avec A3), *Locks* (attentes de
verrou au-delà de `deadlock_timeout`), *Temporary files*, *Checkpoints*,
*Vacuums*, *Sessions*.

**Ce qui doit alerter** :
- tout `PANIC` ; un `FATAL` qui n'est pas une erreur d'authentification
  ponctuelle ;
- une erreur qui revient en boucle (violation de contrainte, annulation
  par `statement_timeout`, interblocage) : bug applicatif ou incident de A4 ;
- des avertissements de checkpoints trop rapprochés ;
- des journaux qui manquent sur la période (rotation, saturation disque).

> **Dans le labo** : `lab pgbadger`, puis `lab fetch-reports`.
> Format de `log_line_prefix` déjà compatible.

**Section du CR** : Analyse pgBadger.

### A9 — Réplication

**Question** : les répliques suivent-elles, un slot menace-t-il `pg_wal` ?

**Pourquoi c'est important** : Une réplique en retard protège mal : en cas
de bascule, on perd ce qu'elle n'a pas rejoué. Un slot abandonné est plus
dangereux encore : il retient les WAL jusqu'à remplir le disque du primaire
et, avec `hot_standby_feedback`, peut retenir l'horizon du VACUUM.

```sql
SELECT application_name, client_addr, state, sync_state, write_lag, flush_lag, replay_lag
FROM pg_stat_replication;

SELECT slot_name, slot_type, active, wal_status, pg_size_pretty(safe_wal_size) AS marge,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS wal_retenu
FROM pg_replication_slots;
```

Sur la réplique : `pg_stat_wal_receiver`, et `conflicts` de
`pg_stat_database` (requêtes annulées par la réplication).

**Ce qui doit alerter** :
- un retard (`replay_lag`) qui grandit au lieu d'osciller ;
- un slot inactif, `wal_status` à `extended` ou `unreserved`, `lost` :
  la réplique est perdue ;
- `hot_standby_feedback = on` avec de longues requêtes sur la réplique : elles
  retiennent l'horizon du primaire (A4, A5).

> **Dans le labo** : réplique dans le profil `standby`, arrêtée par défaut
> (`lab standby-up`). Sans elle, l'axe se résume à vérifier qu'aucun slot
> orphelin ne traîne. pgwatch la surveille déjà (`bluebox-standby`).

**Section du CR** : Réplication.

### A10 — Sauvegardes et restauration

**Question** : l'archivage est-il continu, les sauvegardes réussissent-elles,
et a-t-on **prouvé** une restauration dans les délais (RPO, RTO) ?

**Pourquoi c'est important** : Une sauvegarde jamais restaurée reste une
hypothèse. C'est le seul axe où un échec coûte les données elles-mêmes, et
il ne se voit qu'au pire moment. L'archivage conditionne aussi la
disponibilité : s'il échoue, les WAL s'accumulent dans `pg_wal` jusqu'à
pouvoir arrêter l'instance.

```sql
SELECT archived_count, last_archived_wal, last_archived_time,
       failed_count, last_failed_wal, last_failed_time, stats_reset
FROM pg_stat_archiver;
```

Côté outil : `pgbackrest info` (dernière complète, différentielles, durée,
taille), journaux de la tâche planifiée.

**Ce qui doit alerter** :
- `failed_count` non nul ou `last_failed_time` récent : WAL qui s'accumulent
  dans `pg_wal` (risque disque, A1) ;
- `last_archived_time` plus ancien que deux `archive_timeout` en activité ;
- pas de sauvegarde complète réussie dans le cycle prévu ;
- dépôt sur la même machine que la base : pas de sauvegarde hors site ;
- aucun test de restauration daté, ou une durée mesurée au-delà du RTO.

> **Dans le labo** : `lab info` ; test de restauration avec
> `lab pitr "<horodatage UTC>"` (checklist, sections 7 et 8).

**Section du CR** : Procédures › Sauvegardes.

### A11 — Système hôte

**Question** : CPU, mémoire, disque et réseau suivent-ils la charge ?

**Pourquoi c'est important** : PostgreSQL ne va pas plus vite que la
machine. Regarder le système évite deux erreurs opposées : optimiser des
requêtes quand le serveur est saturé par autre chose, ou réclamer du
matériel quand quelques requêtes suffisent à expliquer la charge.

**Où regarder** : pgCluu (données `sar` : CPU, `iowait`, mémoire, swap,
disques) ; paramètres noyau dans la revue de configuration (A1).

**Ce qui doit alerter** :
- CPU saturé aux heures de pointe du chronogramme ;
- `iowait` au-delà de 10 à 20 % de façon durable ;
- swap utilisé, ou mémoire disponible qui s'effondre (`shared_buffers` +
  `work_mem` × sessions au-delà de la RAM) ;
- latence disque en hausse en même temps que les checkpoints (A7).

> **Dans le labo** : les métriques système sont celles de la VM WSL2, pas
> du Windows. pgwatch ne collecte pas le système (préréglage
> `exhaustive_no_python`) : pgCluu est la seule source. PostgreSQL est
> épinglé sur `PG_CPUSET`, la charge sur `BENCH_CPUSET`.

**Section du CR** : Analyse pgCluu, Paramètres kernel.
