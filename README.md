# restic-pg-dump

Docker image that runs `pg_dump` individually for every database on a given server and saves incremental encrypted backups via [restic].

By default:

- Uses S3 as restic repository backend.
- Runs every hour via cron job.
- Keeps 24 latest, 7 daily, 4 weekly, and 12 monthly snapshots.
- Prunes old snapshots every week.

**NOTE:** Pruning requires an exclusive lock, and should be done infrequently from a single host.


# Usage

Run:

    $ docker run \
    -d \
    -e AWS_ACCESS_KEY_ID='...' \
    -e AWS_SECRET_ACCESS_KEY='...' \
    -e PGHOST='...' \
    -e PGPASSWORD='...' \
    -e PGUSER='...' \
    -e RESTIC_PASSWORD='...' \
    -e RESTIC_REPOSITORY='s3:s3.amazonaws.com/...' \
    --name restic-pg-dump \
    --restart always \
    interaction/restic-pg-dump

You can also pass the following environment variables to override the defaults:

    -e RESTIC_BACKUP_SCHEDULE='0 * * * *'  # Hourly
    -e RESTIC_PRUNE_SCHEDULE='0 14 * * 0'  # Sunday midnight, AEST. Use '' to disable.
    -e PGPORT='5432'
    -e RESTIC_KEEP_HOURLY='24'
    -e RESTIC_KEEP_DAILY='7'
    -e RESTIC_KEEP_WEEKLY='4'
    -e RESTIC_KEEP_MONTHLY='12'

You can backup 5 different database clusters with `PG*_[1..5]`, and assign an arbitrary hostname with `HOSTNAME_[1..5]` (if `PGHOST` is not a fully qualified domain name) environment variables.

    -e HOSTNAME_2='...'
    -e PGHOST_2='...'
    -e PGPASSWORD_2='...'
    -e PGPORT_2='5432'
    -e PGUSER_2='...'

A `docker-compose.yml` file is provided for convenience.


# Restore (macOS)

Create a `.envrc` file from `.envrc.example` and update with your AWS, PostgreSQL and Restic credentials.

    $ wget https://raw.githubusercontent.com/ixc/restic-pg-dump/master/.envrc.example -O .envrc

Restrict access to `.envrc`, because it contains AWS and restic credentials:

    $ chmod 600 .envrc

Install [direnv] via [Homebrew] and configure to ensure your `.envrc` file is always sourced when you change to this directory:

    $ brew install direnv
    $ eval "$(direnv hook bash)"  # Change bash to zsh/fish/tcsh, if necessary, and add to your shell's RC file
    $ direnv allow

Install [restic] via [Homebrew]:

    $ brew install restic

List snapshots:

    $ restic snapshots

Restore the latest snapshot for a given server:

    $ restic restore --host {HOSTNAME} --target "restore/{HOSTNAME}" latest

Restore files matching a pattern from latest snapshot for a given server:

    $ restic restore --host "{HOSTNAME}" --target "restore/{HOSTNAME}" --include '*-production.sql' latest

Mount the restic repository via fuse (read-only):

    $ restic mount mnt

Then, access the latest snapshot from another terminal:

    $ ls -l "mnt/hosts/{HOSTNAME}/latest"
    $ psql -f "mnt/hosts/{HOSTNAME}/latest/pg_dump/{DBNAME}.sql" {DBNAME}

**WARNING:** Mounting the restic repository via fuse will open an exclusive lock and prevent all scheduled backups until the lock is released.


[direnv]: https://direnv.net/
[Homebrew]: https://brew.sh/
[restic]: https://restic.net/
