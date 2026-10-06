{ ... }:
{
  _class = "clan.service";
  manifest.name = "slask/postgresql-collation";
  manifest.description = "Reindex Postgres databases and refresh their collation version after glibc updates";
  manifest.readme = ''
    Postgres records the glibc version each database's default collation was built with, and
    warns ("collation version mismatch") once glibc moves on, since indexes on text may then be
    out of order. Whenever Postgres starts (a glibc bump rebuilds and restarts it) and weekly,
    this reindexes every database whose recorded version differs from the OS's and records the
    new one. Databases already in sync are untouched. No app quiescing: on small databases the
    reindex takes seconds and writers just wait on its locks.
  '';

  roles.default = {
    description = "Machine running PostgreSQL";
    perInstance =
      { ... }:
      {
        nixosModule =
          {
            config,
            lib,
            ...
          }:
          let
            psql = "${config.services.postgresql.package}/bin/psql -X -v ON_ERROR_STOP=1";
          in
          lib.mkIf config.services.postgresql.enable {
            systemd.services.postgresql-refresh-collation = {
              description = "Reindex Postgres databases whose collation version is stale";
              after = [ "postgresql.service" ];
              requires = [ "postgresql.service" ];
              # Also runs whenever Postgres (re)starts, e.g. after a deploy that bumps glibc.
              wantedBy = [ "postgresql.service" ];
              serviceConfig = {
                Type = "oneshot";
                User = "postgres";
                Group = "postgres";
              };
              script = ''
                stale="$(${psql} -d postgres -tAc "
                  SELECT datname FROM pg_database
                  WHERE datallowconn
                    AND datcollversion IS DISTINCT FROM pg_database_collation_actual_version(oid)")"
                if [ -z "$stale" ]; then
                  echo "all databases' collation versions are current"
                  exit 0
                fi
                for db in $stale; do
                  echo "$db: collation version stale, reindexing"
                  ${psql} -d "$db" -c "REINDEX DATABASE \"$db\";"
                  ${psql} -d "$db" -c "ALTER DATABASE \"$db\" REFRESH COLLATION VERSION;"
                done
              '';
            };
            systemd.timers.postgresql-refresh-collation = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = "weekly";
                Persistent = true;
              };
            };
          };
      };
  };
}
