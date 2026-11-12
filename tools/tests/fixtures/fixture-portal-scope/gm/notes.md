# GM notes

`s5` (`security-policy-ownership-end-dropped`): planted by `gmctl inject`
after the data load, `portal_animals_scope`'s owner branch without
`o.until_at IS NULL`, so a former owner logged into the portal still
lists the animals they sold. The fixture exists for chunk 25's short test
(`run-short-test.sh`), which records a horse's sale two hours back before
planting and logs in as its former owner and its buyer. The record is
`vet-core`'s, the laboratory `vet-lab`'s and the owners' portal
`vet-portal`'s, loaded and derived by `load-data` from the domains; their
notes are `domains/vet-core/docs/gm.md`, `domains/vet-lab/docs/gm.md` and
`domains/vet-portal/docs/gm.md`; account `n`'s password is
`portal_password(n, load_epoch)` (vet-portal's, "The key, the passwords,
the links").
