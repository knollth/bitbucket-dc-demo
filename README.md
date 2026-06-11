# Bitbucket Data Center demo

Spin up a local, fully provisioned [Bitbucket Data Center][bbdc] backed by
PostgreSQL for testing. It uses an Atlassian 3-hour [timebomb license][timebomb]
and the container auto-setup variables, so there is no setup wizard and no
manual licensing — `make up` gives you a working instance.

## Requirements

- Docker (with the Compose plugin)
- ~4 GiB of memory available to Docker

## Usage

```bash
make up       # start Bitbucket + PostgreSQL (creates .env on first run)
make seed     # optional: create the demo project and repo
make down     # stop the containers, keep the data volumes
make destroy  # stop everything and delete volumes and images
```

`make up` copies `.env.example` to `.env` on first run. The defaults work out
of the box; edit `.env` to change ports, credentials, or the license.

First boot takes a few minutes while Bitbucket initialises the database. Follow
along with `make logs` or check `make status`. Once it is up:

- Web UI: <http://localhost:7990>
- Username / password: `admin` / `change-this-admin-password` (from `.env`)

## Timebomb license

The bundled license is an Atlassian 3-hour timebomb evaluation license that
expires a few hours after the container starts. To get a fresh instance:

```bash
make destroy && make up
```

Grab a newer license any time from the [Atlassian timebomb licenses][timebomb]
page (use the *10 user Bitbucket Data Center license, expires in 3 hours*) and
update `BITBUCKET_LICENSE` in `.env`.

[bbdc]: https://www.atlassian.com/software/bitbucket/enterprise/data-center
[timebomb]: https://developer.atlassian.com/platform/marketplace/timebomb-licenses-for-testing-server-apps/
