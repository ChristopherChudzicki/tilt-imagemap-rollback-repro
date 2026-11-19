# Tilt: a shared image's `ImageMap` goes back to an older build

Two `k8s_custom_deploy` resources deploy one `docker_build` image. Once one of them has built a newer image, reconciling the other resource's `DockerImage` object sets the shared `ImageMap` back to the older image, and the next apply that reuses the image deploys it. Seen on Tilt v0.37.8.

## Run it

Needs a local cluster that Tilt can build for, and `kubectl` pointed at it.

```bash
tilt up
```

When `a` and `b` are green, in a second terminal:

```bash
./repro.sh
```

Output from one run (the columns are image tags):

```
1. a and b have each built:        imagemap=tilt-17b4c1305ae394d8  a=tilt-17b4c1305ae394d8  b=tilt-17b4c1305ae394d8
2. image/marker.txt changed:       imagemap=tilt-d334d26ed591eb5c  a=tilt-d334d26ed591eb5c  b=tilt-d334d26ed591eb5c
3. b's DockerImage touched:        imagemap=tilt-17b4c1305ae394d8  a=tilt-d334d26ed591eb5c  b=tilt-d334d26ed591eb5c
4. deploy.yaml touched:            imagemap=tilt-17b4c1305ae394d8  a=tilt-17b4c1305ae394d8  b=tilt-17b4c1305ae394d8
```

Nothing is built after step 2, yet by step 4 both Deployments are back on the image from step 1. Tilt's log for step 4 names the new image and passes the old one in `$TILT_IMAGE_0`:

```
a │ 1 File Changed: [deploy.yaml]
a │ STEP 1/2 — Loading cached images
a │      - localhost:5001/repro-image:tilt-d334d26ed591eb5c
a │ STEP 2/2 — Deploying
a │      Running cmd: sed "s|NAME|a|g; s|IMAGE|$TILT_IMAGE_0|" deploy.yaml | kubectl apply -o yaml -f -
```

## What `repro.sh` does

1. `tilt trigger a`, then `tilt trigger b`, so each resource has built the image once and holds a build result of its own.
2. Changes `image/marker.txt`. One resource builds the new image and the other reuses it.
3. Adds an annotation to the reusing resource's `DockerImage` object with `tilt patch`, which makes Tilt reconcile that object. The `ImageMap` now points at the older image.
4. Touches `deploy.yaml`, a `deps` file of both resources. Both apply commands run again, without a build, and get the older image.

## Why it happens

- The `DockerImage` reconciler keeps one build result per `<resource>:<image>` object. Each time it reconciles one of those objects, [`maybeUpdateImageMapStatus`](https://github.com/tilt-dev/tilt/blob/v0.37.8/internal/controllers/core/dockerimage/reconciler.go#L178-L201) writes that object's result to the shared `ImageMap` if the two differ.
- A resource that reused another resource's build keeps its own older result, so reconciling its object moves the `ImageMap` backwards.
- Step 3 forces a reconcile with `tilt patch`. A resource's own build does it too: during `tilt trigger b`, `tilt get imagemap repro-image -w` shows `b`'s previous image until the build finishes.
- *Not tested, from reading the code:* a `Cluster` status change, or a `DockerImage` spec change on Tiltfile reload, should reconcile the object as well.

*Note: with two `k8s_yaml` Deployments the `ImageMap` goes back the same way, but editing the YAML made Tilt rebuild the image, so nothing stale was deployed.*

## Environment

- Tilt v0.37.8, darwin-arm64
- k3d, Kubernetes v1.35.8+k3s1, with a local registry
- Docker 29.8.2 (OrbStack)

`reconciler.go` is the same on Tilt's `master` as of 2026-11-17; v0.37.9 has not been run.

🤖 Co-authored with [Claude Code](https://claude.com/claude-code)
