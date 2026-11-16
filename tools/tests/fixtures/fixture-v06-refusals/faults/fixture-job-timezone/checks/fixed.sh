#!/bin/sh
# fixture sealed check (never run): the close-day job carries no timezone.
if grep -q 'timezone' /srv/scheduler/jobs/jobs.yaml; then
    echo "close-day still runs in a fixed zone"
    exit 1
fi
echo "close-day runs in the customer's time"
exit 0
