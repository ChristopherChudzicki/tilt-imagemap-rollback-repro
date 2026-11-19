# Tilt: a shared image's `ImageMap` goes back to an older build

## Summary
**Setup:** Tilt with two resources A and B that are `k8s_custom_deploy` which both deploy a single docker image and have `deps=...` kwarg. 

**Bug:**
1. One resource, say A, builds a newer image.
    - now the shared ImageMap records the newer image version
2. The next time Tilt reconciles resource B, it updates the shared ImageMap back to the older image.
3. A change to one of the `k8s_custom_deploy`'s `deps=...` files now causes the resource to re-apply the old image.

## Reproduce with this Repo

From repo root:
1. `tilt up`, and wait for `a` and `b` to go green.
2. Give each resource a build of its own: `tilt trigger a`, wait for green, then `tilt trigger b`.
3. Look at the three things the bug involves. All of them show the same tag:

    ```bash
    # the shared ImageMap
    tilt get imagemap repro-image -o jsonpath='{.status.image}{"\n"}'
    # the image each resource last built itself
    tilt get dockerimage -o custom-columns=NAME:.metadata.name,BUILT:.status.ref
    # the image each Deployment runs
    kubectl get deployments a b -o custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image
    ```
4. Build a newer image: `echo 2 > image/marker.txt`. `a` builds it and `b` reuses it. Run the three commands again. You should see:
    - Shared `ImageMap` has new image
    - both deployments using the new image
    - resource b last built the old image.
5. Make Tilt reconcile `b`'s `DockerImage` object. One way is by changing an annotation on it: `tilt patch dockerimage b:repro-image --type merge -p '{"metadata":{"annotations":{"poke":"1"}}}'`. Then, the `ImageMap` is back on the old tag, while both Deployments still run the new one. (If `b` was the one that built in step 4, patch `a:repro-image`.)
6. Change each resource's `deps` file: `touch a.yaml b.yaml`. Both apply commands run again without a build, and both Deployments are now on the old tag:

    ```
    NAME   IMAGE
    a      k3d-registry.localhost:5000/repro-image:tilt-17b4c1305ae394d8
    b      k3d-registry.localhost:5000/repro-image:tilt-17b4c1305ae394d8
    ```

These steps are automated in `repro.sh`.

## Environment

- Tilt v0.37.8, darwin-arm64
- k3d, Kubernetes v1.35.8+k3s1, with a local registry
- Docker 29.8.2 (OrbStack)

`reconciler.go` is the same on Tilt's `master` as of 2026-11-17; v0.37.9 has not been run.

🤖 Co-authored with [Claude Code](https://claude.com/claude-code)
