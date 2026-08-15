# Fred and Luke Land

A disposable Paper + Floodgate + Geyser stack for a Java client on Linux and a
Bedrock client on iPad. Procman handles downloads, ordered startup, combined
logs, and teardown.

Only the Java world's files persist. Paper 26.2 stores all three dimensions in
one world tree:

```text
worlds/
└── world/
```

Everything under `.run/` is rebuilt on every launch. Downloaded, checksummed
artifacts and Paper's derived runtime libraries are retained under `.cache/` to
avoid repeated downloads; they are reproducible and are not application state.
Floodgate keys, Geyser configuration, player caches, plugin data, and server
logs are disposable.

## Requirements

- Linux
- Java 25 or newer
- `procman`, `curl`, `gh`, and `sha256sum`
- An authenticated GitHub CLI (`gh auth status`) to fetch the pinned Geyser
  development artifact on the first launch

## Start

```bash
procman procman.pman
```

Paper receives a 4 GiB maximum heap by default. Override it after procman's
argument separator:

```bash
procman procman.pman -- --memory 6G
```

Stop the complete stack with Ctrl-C. Procman sends termination to Paper and
Geyser together.

## Connect

- Fred, Java 26.2 on Linux: `<server-lan-ip>:25565` over TCP.
- Luke, Bedrock 26.44 on iPad: `<server-lan-ip>:19132` over UDP.

Use `hostname -I` on the server to find its LAN address. Permit TCP port 25565
and UDP port 19132 from the LAN in the host firewall. Floodgate lets Luke join
with his Bedrock/Microsoft identity without a Java account.

## Pinned software

- Paper 26.2 build 112
- Floodgate 2.2.5 build 140
- Geyser `feature/26.40`, GitHub Actions run 30923939558

Geyser's 26.40 support is still a development artifact. Replace the pin with an
official build once 26.40-family support reaches Geyser's normal downloads.

## Validate without starting

```bash
procman procman.pman --check
```
