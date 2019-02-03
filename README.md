# restic-pg-dump

Docker image that runs `pg_dump` individually for every database on a given server and saves incremental encrypted backups via [restic].

By default:

- Uses S3 as restic repository backend.
- Runs every hour via cron job.
- Keeps 24 latest, 7 daily, 4 weekly, and 12 monthly snapshots.


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

    -e CRONTAB_SCHEDULE='0 * * * *'
    -e PGPORT='5432'
    -e RESTIC_KEEP_DAILY='7'
    -e RESTIC_KEEP_LAST='24'
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


[direnv]: https://direnv.net/
[Homebrew]: https://brew.sh/
[restic]: https://restic.net/
