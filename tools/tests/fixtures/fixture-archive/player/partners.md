# Partners

## Cold Storage

An off-site archive service: what is shipped there leaves the site and
is never read back. Its console, `http://cold-storage:8000/`, graphs the
rows received per day and data type; `GET /manifests` lists the
shipments as JSON (filters `type`, `source`, `from`, `to`). Uploads
(`POST /shipments`) take the account key.
