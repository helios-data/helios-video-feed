# helios-video-feed

go2rtc capture bridge for the Helios mission-control video pipeline. This is the
**single owner** of the USB VTX capture card: it reads the card and restreams it
as WHEP so that both OBS and the Mission Control overlay pull the *same* feed
instead of fighting over the device.

It runs as a launcher GITHUB node — the launcher clones this repo, reads
[`config.json`](config.json), and builds the [`Dockerfile`](Dockerfile) at the
repo root.

## Layout

```
helios-video-feed/
├── Dockerfile      # FROM alexxit/go2rtc; bakes in go2rtc.yaml
├── config.json     # launcher schema (devices/ports/volumes/flags/websites)
├── go2rtc.yaml     # baked into the image; go2rtc reads it
└── README.md
```

## Required launcher binding

`config.json` declares `"devices": ["/dev/video0"]`. That path is the
**container-side target** — the launcher renders it under **"Required Device
Bindings (Target : Source)"** with an empty Source dropdown.

**Before starting, the operator must select the host capture card
(e.g. `/dev/video2`) as the Source.** If left unbound the device won't map into
the container and the stream will not come up. Because the target is fixed at
`/dev/video0`, `go2rtc.yaml` always reads `/dev/video0` regardless of which host
device is chosen — the go2rtc config never changes per host.

## Ports (both required)

Both ports are forwarded to the host and **both must be published**:

- **`1984`** — WHEP signaling (the browser's `fetch`).
- **`8555`** — WebRTC media (TCP). WHEP alone negotiates but carries no frames;
  without `8555` the panel connects and stays black forever.

The host browser reaches them at `localhost:1984` / `localhost:8555`.

## Consuming the stream

- Overlay / OBS pull WHEP at:
  `http://<host>:1984/api/whep?src=cloudburst`
- `config.json` lists `http://localhost:1984` under `websites`, so the launcher
  opens the go2rtc dashboard on spawn — use it to confirm the `cloudburst` stream
  is live independently of the overlay.

## Networking note

The launcher runs nodes on the default Docker **bridge** network (the
component-tree `DockerSpec` has no `network_mode` field). On bridge, go2rtc would
otherwise advertise its unreachable `172.x` address, so `go2rtc.yaml` pins an
explicit `127.0.0.1:8555` candidate that resolves through the published host
port. For an overlay/OBS on a *different* LAN machine, add the host LAN IP as an
extra candidate in `go2rtc.yaml`.

## Device-permission note

The host node is `crw-rw----+ root video`; the go2rtc process must be able to
open the device once it enters the container at `/dev/video0`. The
`alexxit/go2rtc` image runs as **root**, which works. Do **not** switch to a
non-root base: the process would need the `video` group, but the component-tree
`DockerSpec` exposes no `group_add`/`privileged`, so the open would fail with
`Permission denied`.

## Host-side smoke test (before Docker)

Proves capture + WHEP negotiate without the launcher in the loop:

```bash
go2rtc -config <(sed 's#/dev/video0#/dev/video2#' go2rtc.yaml)
# open http://localhost:1984 -> click "cloudburst": a BLACK frame = success
# (the card streams black with no VTX input — that's the pass condition)
```
