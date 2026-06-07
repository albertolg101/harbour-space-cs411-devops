## Hypotheses

1. **Expired TTL on the image.** The `:2h` tag on ttl.sh means the image gets
   deleted after roughly two hours. Jenkins can still pull it because it has a
   local copy cached from when it built and pushed the image, but the k8s node
   needs to download it fresh from the registry — and by that point the tag
   might not exist anymore.

2. **Network issue on the node side.** Jenkins and the k8s nodes don't
   necessarily share the same network config. The node might not be able to
   resolve `ttl.sh` or might have some firewall/proxy blocking outbound traffic
   to it, so the pull times out even though Jenkins has no issues.

## Verification

For each hypothesis, start with:

```sh
kubectl describe pod myapp
```

and scroll to the `Events` at the bottom.

- If I see `manifest unknown` or a 404-type error, the image is gone from the
  registry → expired tag (hypothesis 1).
- If I see `dial tcp: i/o timeout` or `no such host`, the node can't reach
  ttl.sh at all → network problem (hypothesis 2).

## Fix

The expired tag is the more common case with ttl.sh. Two things to do:

1. Make sure `docker push` and `kubectl apply` happen back-to-back in the same
   pipeline run so there's no gap where the tag could expire.
2. Add `imagePullPolicy: Always` to the container spec so the kubelet always
   pulls a fresh copy instead of skipping the pull if it thinks it already has
   the image.

```yaml
imagePullPolicy: Always
```

(For a private registry the fix would be adding `imagePullSecrets`; for a wrong
tag it would just be fixing the tag string in the manifest.)

## Lesson

Being able to pull an image from my machine just means that *my* machine has
network access and possibly a cached copy. What actually matters is whether the
kubelet on the cluster node can pull it on its own, with its own network and
credentials — those are two completely different environments.
