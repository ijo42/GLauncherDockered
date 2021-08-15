# GravitLauncherDockered

[![Docker Pulls](https://img.shields.io/docker/pulls/ijo42/glauncher?style=for-the-badge&logo=Docker&labelColor=325358&color=c0ffee&logoColor=white)](https://hub.docker.com/repository/docker/ijo42/glauncher)
[![Docker Image Size (latest by date)](https://img.shields.io/docker/image-size/ijo42/glauncher?label=Image%20size&sort=date&style=for-the-badge&logo=Docker&labelColor=325358&color=c0ffee&logoColor=white)](https://hub.docker.com/repository/docker/ijo42/glauncher)
[![GitHub Repo stars](https://img.shields.io/github/stars/ijo42/GLauncherDockered?label=GitHub%20Stars&style=for-the-badge&logo=Github&labelColor=325358&color=c0ffee)](https://github.com/ijo42/GLauncherDockered)
[![GitHub forks](https://img.shields.io/github/forks/ijo42/GLauncherDockered?label=GitHub%20Forks&style=for-the-badge&logo=Github&labelColor=325358&color=c0ffee)](https://github.com/ijo42/GLauncherDockered)

---

Repo contains [GravitLauncher](https://github.com/GravitLauncher), with [lsiobase/alpine](https://hub.docker.com/r/lsiobase/alpine) as the base image and minimal [liberica](https://bell-sw.com) JDK for image size reduce.

The [lsiobase/alpine](https://hub.docker.com/r/lsiobase/alpine) image is a custom base image built with [Alpine linux](https://alpinelinux.org/) and [S6 overlay](https://github.com/just-containers/s6-overlay).
Using this image allows us to use the same user/group ids in the container as on the host, making file transfers much easier

# Deployment

Tags | Description
-----|------------
`latest` | Using the `latest` tag will pull the weekly-builded image.

## Pre-built images `latest`

using docker-compose:

```docker-compose.yml
version: "2"
services:
  launchserver:
    image: ijo42/glauncher:latest
    container_name: launchserver
    restart: unless-stopped
    environment:
      - TZ=Europe/Moscow # Timezone
      - PUID=1000 # User ID
      - PGID=1000 # Group ID
    ports:
      - 9274:9274
    volumes:
      - /host/path/to/launchserver:/app/launchserver
```

Using CLI:

```bash
docker create \
  --name=launchserver \
  -it -p 9274:9274 \
  -e TZ=Europe/Moscow `# Timezone` \
  -e PUID=1000 `# User ID` \
  -e PGID=1000 `# Group ID` \
  -v /host/path/to/launchserver:/app/launchserver `# Where conf will be stored` \
  --restart unless-stopped \
  ijo42/glauncher:latest
```

# Configuration

Configuration | Explanation
------------ | -------------
[Restart policy](https://docs.docker.com/compose/compose-file/#restart) | "no", always, on-failure, unless-stopped
TZ | Timezone
PUID | for UserID
PGID | for GroupID


## User / Group Identifiers

When using volumes, permissions issues can arise between the host OS and the container. [Linuxserver.io](https://www.linuxserver.io/) avoids this issue by allowing you to specify the user `PUID` and group `PGID`.

Ensure any volume directories on the host are owned by the same user you specify and any permissions issues will vanish like magic.

In this instance `PUID=1000` and `PGID=1000`, to find yours use `id user` as below:

```
  $ id $(whoami)
    uid=1000(dockeruser) gid=1000(dockergroup) groups=1000(dockergroup)
```

# Building the image yourself

Use the [Dockerfile](https://github.com/ijo42/GLauncherDockered/Dockerfile) to build the image yourself, in case you want to make any changes to it

docker-compose.yml:

```docker-compose.yml
version: '2'
services:
  launchserver:
    container_name: launchserver
    build:
        context: ./GLauncherDockered
        args:
        - LAUNCHER_VERSION=a4355d1d
        - RUNTIME_VERSION=aa6fe1a8
    restart: unless-stopped
    volumes:
      - /host/path/to/launchserver:/app/launchserver
    environment:
      - TZ=Europe/Moscow # Timezone
      - PUID=1000  # User ID
      - PGID=1000  # Group ID
```

1. Clone the repository: `git clone https://github.com/ijo42/GLauncherDockered.git`
2. Prepare docker-compose.yml file as seen above
3. `docker-compose up -d --build launchserver`
4. ???
5. Profit!
