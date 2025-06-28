# SpaceAPI

fill static [SpaceAPI](https://spaceapi.io/) with dynamic sensor and state data

## Commands

set up

```bash
cp .env.example .env
nano .env
```

test individual components

```bash
./get_open-status.sh
./get_sensors.sh
```

generate dynamic spaceAPI

```bash
./fill_spaceapi.sh
```

## nginx setup

```nginx
server {
  listen 80;
  listen [::]:80;

  server_name spaceapi.alifeee.net;

# root /var/www/dynamic-space-api/;

  location = / {
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME /var/www/dynamic-space-api/spaceapi_cgi.sh;
    fastcgi_pass unix:/var/run/fcgiwrap.socket;
  }
}
```
