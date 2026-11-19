docker_build('repro-image', 'image')

# a and b deploy the same image. Touching a.yaml or b.yaml re-runs that
# resource's apply_cmd without rebuilding the image.

k8s_custom_deploy(
    'a',
    apply_cmd='sed "s|IMAGE|$TILT_IMAGE_0|" a.yaml | kubectl apply -f - -o yaml',
    delete_cmd='kubectl delete -f a.yaml --ignore-not-found',
    deps=['a.yaml'],
    image_deps=['repro-image'],
)

k8s_custom_deploy(
    'b',
    apply_cmd='sed "s|IMAGE|$TILT_IMAGE_0|" b.yaml | kubectl apply -f - -o yaml',
    delete_cmd='kubectl delete -f b.yaml --ignore-not-found',
    deps=['b.yaml'],
    image_deps=['repro-image'],
)
