# Testing Recipes

This documents collects testing recipes to test the ownCloud iOS app and SDK against

**These recipes are targeted for use by developers and are not designed to run secured instances of ownCloud. If you're using any of these recipes, please take action as necessary to secure your computer and any services and instances you spin up against unauthorized use.**

## Simple instance

This `docker-compose.yml` can be used to bring up a simple instance:

```
version: '3'

services:
  owncloud:
    image: owncloud/server:latest
    restart: always
    ports:
      - 36080:8080
      - 36180:80
      - 36443:443
```

Run in the same directory:
- `docker-compose up`: brings up the instance and shows its log. Stop with `Ctrl+C`.
- `docker-compose up -d`: brings up the instance and returns immediately
- `docker-compose stop`: stops a running instance
- `docker-compose start`: starts an existing instance
- `docker-compose down`: stops the instance and deletes all of its data

The instance can be accessed through  `https://localhost:36443/`  and `http://localhost:36080/` while running.

## Running an docker instance in a `/owncloud` sub-directory

Append this snippet in the scope of `services: owncloud:` (same level as `ports:` above) to the `docker-compose.yml` file:

```
    environment:
      - OWNCLOUD_SUB_URL=/owncloud
```

## Enabling and disabling maintenance mode

The shell commands inside the instance for enabling and disabling maintenance mode are:

- `occ maintenance:mode --on` turns on maintenance mode
- `occ maintenance:mode --off` turns off maintenance mode

For dockerized instances spun up using the above `docker-compose.yml`, the following can be used:

- `docker-compose exec owncloud occ maintenance:mode --on` turns on maintenance mode
- `docker-compose exec owncloud occ maintenance:mode --off`  turns off maintenance mode

## Simulating certificate changes

Pre-requisites:
- running a simple instance as described above
- files from `doc/testing-resources/mitmproxy/` placed in the current directory
- `mitmproxy` installed (f.ex. via homebrew)

### New certificate using same public key
`mitmweb --web-port 10001 --listen-port 443 --mode reverse:http://localhost:36080 --set keep_host_header --cert "*=cert-pkey-A-cert1.pem"`
`mitmweb --web-port 10001 --listen-port 443 --mode reverse:http://localhost:36080 --set keep_host_header --cert "*=cert-pkey-A-cert2.pem"`

### New certificate using different public key
`mitmweb --web-port 10001 --listen-port 443 --mode reverse:http://localhost:36080 --set keep_host_header --cert "*=cert-pkey-A-cert1.pem"`
`mitmweb --web-port 10001 --listen-port 443 --mode reverse:http://localhost:36080 --set keep_host_header --cert "*=cert-pkey-B-cert1.pem"`

The OC instance is then accessible via `https://localhost:443/` by the app in the Simulator.
