docker_build('repro-image', 'image')

# Two resources deploy the same image. A change to deploy.yaml re-runs both
# apply commands without rebuilding the image.
for name in ['a', 'b']:
    k8s_custom_deploy(
        name,
        apply_cmd='sed "s|NAME|%s|g; s|IMAGE|$TILT_IMAGE_0|" deploy.yaml | kubectl apply -o yaml -f -' % name,
        delete_cmd='kubectl delete deployment %s --ignore-not-found' % name,
        deps=['deploy.yaml'],
        image_deps=['repro-image'],
    )
