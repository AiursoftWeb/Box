# Box

This project tries to describe a datacenter based on pure files and configuration:

```bash
├── declare
│   └── configuration
│       ├── caddy
│       ├── gitlab
│       ├── grafana
│       ├── prometheus
│       └── ...
├── docker-compose.yml
├── stage
│   ├── configuration
│   │   ├── caddy
│   │   ├── gitlab
│   │   ├── grafana
│   │   ├── prometheus
│   │   └── ...
│   ├── datastore
│   │   ├── gitlab
│   │   ├── grafana
│   │   ├── prometheus
│   │   └── ...
│   └── logs
│       ├── caddy
│       ├── grafana
│       ├── prometheus
│       └── ...
└── start.sh
```

## Structure

### Declare

It defines how the app it runs should behave.

### Stage

The 'Stage' is a real app running environment. And it should never be checked in.

#### Configuration

This part is copied from the 'declare' folder directly so the apps can use it.

This part only contains configuration files.

#### Datastore

This part contains the data that the apps need to run.

For example, the files in Nas, the database file for a database, etc.

#### Logs

This part contains the logs that the apps generate.

## How to run

Make sure you have `docker` and `docker-compose` installed.

```bash
./start.sh
```

That's it!
