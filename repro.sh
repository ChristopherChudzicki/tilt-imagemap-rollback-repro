#!/bin/bash
# Run while `tilt up` is running in this directory and `a` and `b` are green.
# Rolls both Deployments back to the previous image without building anything.
set -eu

settle() {
  sleep 5
  tilt wait --for=condition=Ready --timeout=120s uiresource/a uiresource/b >/dev/null
}
tag() { echo "${1##*:}"; }
imagemap() { tag "$(tilt get imagemap repro-image -o jsonpath='{.status.image}')"; }
record() { tag "$(tilt get dockerimage "$1:repro-image" -o jsonpath='{.status.ref}')"; }
deployed() { tag "$(kubectl get deployment "$1" -o jsonpath='{.spec.template.spec.containers[0].image}')"; }
show() {
  printf '%-34s imagemap=%s  a=%s  b=%s\n' "$1" "$(imagemap)" "$(deployed a)" "$(deployed b)"
}

tilt trigger a >/dev/null; settle
tilt trigger b >/dev/null; settle
show "1. a and b have each built:"

date +%s > image/marker.txt; settle
show "2. image/marker.txt changed:"

# The resource that reused the new image still holds its own older build result.
stale=a
[ "$(record a)" = "$(imagemap)" ] && stale=b
tilt patch dockerimage "$stale:repro-image" --type merge \
  -p "{\"metadata\":{\"annotations\":{\"poke\":\"$(date +%s)\"}}}" >/dev/null
sleep 2
show "3. $stale's DockerImage touched:"

touch a.yaml b.yaml; settle
show "4. a.yaml and b.yaml touched:"
