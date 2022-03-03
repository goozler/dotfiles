dcr -v $(pwd)/dumps:/dumps postgres /bin/bash -c "pg_dump -Fc --no-acl --no-owner -h postgres -U postgres db > /dumps/db.dump"

dcr -v $(pwd)/sandbox/dumps:/dumps postgres /bin/bash -c "pg_restore --verbose --clean --no-acl --no-owner -h postgres -U postgres -d db /dumps/db.dump"

pg_dump "-Fc --no-acl --no-owner -h 192.168.1.3 -p 6000 -U postgres postgres > /mnt/dumps/db.dump"

pg_restore "--verbose --clean --no-acl --no-owner -h 192.168.1.3 -p 6000 -U postgres -d postgres /mnt/sandbox/dumps/db.dump"
