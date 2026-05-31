# Prompts and Answers

## Service Restart and Dedicated User

**Prompt:** We want the app to restart on failure, and we also want the app to run as a non-root dedicated `myapp` user.

**Answer:** Updated the systemd service so it runs the process as `myapp:myapp`, starts `/opt/myapp/main`, and restarts on failure with a short delay. Updated the Ansible playbook to create the `myapp` system group and user, create `/opt/myapp`, deploy the binary there as `myapp`, and enable/start the service.

## Idempotent Deploy

**Prompt:** Is our deploy idempotent?

**Answer:** Mostly, but there were a few implicit pieces that could cause unnecessary changes or restarts. The playbook used idempotent Ansible modules, but the systemd unit copy did not pin ownership/mode, the restart handler did not reload systemd after unit changes, and the Go build command was not explicitly reproducible.

**Prompt:** Make it idempotent.

**Answer:** Added `daemon_reload: true` to the restart handler so changed unit files are loaded before restart.

**Prompt:** What about the `main` file being built every time?

**Answer:** Made the Jenkins build more reproducible with:

```groovy
go build -trimpath -buildvcs=false -o main app/main.go
```

This removes local path data, avoids VCS metadata in the binary, and writes the artifact to an explicit path. Repeated local builds with these flags produced the same SHA-256 checksum.

**Prompt:** Do your last check and ensure the deploy is idempotent, as much as possible.

**Answer:** Pinned the systemd unit file metadata in the playbook:

```yaml
owner: root
group: root
mode: "0644"
```

The app still runs as `myapp`; only `/etc/systemd/system/myapp.service` is owned by root because it is system configuration. The deployed binary remains owned by `myapp:myapp`.

**Prompt:** Why was what we had before not 100% idempotent?

**Answer:** It was mostly idempotent, but some desired state was implicit. The Jenkins build did not use reproducibility flags, so equivalent source could potentially produce different binary bytes and trigger unnecessary copies/restarts. The systemd unit copy did not pin `owner`, `group`, or `mode`, so file metadata could drift. The restart handler also restarted without `daemon_reload: true`, so a changed unit file might not be loaded before restart.

## Health Check

**Prompt:** Add a health check to the deploy, so once the service is restarted we curl it and get the expected JSON shape.

**Answer:** Added an Ansible health check using `ansible.builtin.uri` after `meta: flush_handlers`, so pending service restarts happen before validation. The deploy now calls `http://127.0.0.1:4444/`, retries up to 10 times with a 2-second delay, and requires HTTP `200` plus the expected JSON shape:

```json
{
  "Name": "Hello",
  "Description": "World",
  "Url": "<defined>"
}
```

**Prompt:** Does the deploy only succeed if the health check succeeds?

**Answer:** Yes. If the health check fails after retries, Ansible exits non-zero, so the Jenkins deploy stage fails.

**Prompt:** What real-world failure do we catch now that we have the health check?

**Answer:** The health check catches cases where systemd starts the service but the app is not actually serving the expected API, such as the process crashing after start, listening on the wrong port, returning invalid JSON, serving the wrong fields, returning HTTP `500`, or pointing the unit at the wrong binary.

## Validation Notes

- `git diff --check` passed after the deployment changes.
- `playbook.yml` parsed as valid YAML.
- `ansible-playbook --syntax-check` could not be run locally because `ansible-playbook` is not installed in the workspace.
