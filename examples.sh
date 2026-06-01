# Examples of common operations I keep forgetting.
# Mostly Postgres dump/restore via Docker (the volume-mount trick is easy to misremember),
# plus a couple of kubectl/git incantations.
#
# `dcr` = `docker compose run --rm` (alias in zshrc). Mounting $(pwd) into the container
# is what lets the dump file land back on the host filesystem instead of inside the
# ephemeral container.

# pg_dump from a docker-compose postgres service to a host-side dumps dir.
dcr -v $(pwd):/mnt postgres /bin/bash -c "pg_dump -Fc --no-acl --no-owner -h postgres -U <db-user> <db-name> > /mnt/sandbox/dumps/<db-name>_$(date +%Y_%m_%d).dump"

# pg_restore from a host-side dumps dir into the docker-compose postgres service.
dcr -v $(pwd)/sandbox/dumps:/dumps postgres /bin/bash -c "pg_restore --verbose --clean --no-acl --no-owner -h postgres -U postgres -d <db-name> /dumps/db.dump"

# Same as above, but pick the dump file interactively with fzf.
dcr -v $(pwd):/mnt postgres /bin/bash -c "pg_restore --verbose --clean --no-acl --no-owner -h postgres -U <db-user> -d <db-name> /mnt/sandbox/dumps/`find sandbox/dumps -type f -exec basename {} \; | fzf`"

# Shell into a kubernetes pod, picking the pod interactively with fzf.
kubectl exec -it -n <namespace> `kubectl get pods -n <namespace> | fzf` -- /bin/sh

# pg_dump using a Vault-issued dynamic db credential (paste the username from `vault read database/creds/<role>`).
pg_dump "-Fc --no-acl --no-owner -h host.docker.internal -p 6000 -U <vault-username> <db-name> > /mnt/dumps/<db-name>_$(date +%Y_%m_%d).dump"

# Plain pg_restore from a remote host into local postgres.
pg_restore "--verbose --clean --no-acl --no-owner -h <remote-host> -p 6000 -U postgres -d postgres /mnt/sandbox/dumps/db.dump"

# Generate a changelog: commits reachable from origin/master but not from a release tag,
# excluding noisy paths (generated code, test fixtures, etc).
glgp --reverse origin/master ^<release-tag> -- ':!path/to/tests' ':!path/to/generated' ':!path/to/schema.json' > changes
