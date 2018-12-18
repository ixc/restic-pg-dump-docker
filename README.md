# restic-pg-dump

Docker image that runs `pg_dump` individually for every database on a given server and saves incremental encrypted backups via [restic].

By default:

- Uses S3 as restic repository backend.
- Runs every 4 hours via cron job.
- Keeps 5 latest, 7 daily, 4 weekly, and 12 monthly snapshots.


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

    -e CRONTAB_SCHEDULE='0 */4 * * *'
    -e PGPORT='5432'
    -e RESTIC_KEEP_DAILY='7'
    -e RESTIC_KEEP_LAST='5'
    -e RESTIC_KEEP_WEEKLY='4'
    -e RESTIC_KEEP_MONTHLY='12'

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

    $ restic restore --host "$PGHOST" --target "restore/$PGHOST" latest

Restore files matching a pattern from latest snapshot for a given server:

    $ restic restore --host "$PGHOST" --target "restore/$PGHOST" --include '*-production.sql' latest

Mount the restic repository via fuse (read-only):

    $ restic mount mnt

Then, access the latest snapshot from another terminal:

    $ ls -l "mnt/hosts/$PGHOST/latest"
    $ psql -f "mnt/hosts/$PGHOST/latest/pg_dump/{DBNAME}.sql" {DBNAME}


[direnv]: https://direnv.net/
[Homebrew]: https://brew.sh/
[restic]: https://restic.net/
