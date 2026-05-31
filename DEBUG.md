# Debug Task

## Most Likely Causes

1. The application was probably launched directly from the SSH deployment shell, such as `./main &`. In that setup the process can stay attached to the login session and may receive `SIGHUP`, or otherwise be cleaned up, when SSH disconnects. This fits the symptom where the app is reachable during the session but disappears as soon as the session ends.

2. The deployment may only confirm that the file was copied and the start command exited successfully. That does not prove the app survived after the remote shell closed, or that port `4444` is still accepting requests. A pipeline can pass while the real service is already dead by the time someone tests it.

## How To Verify

To check whether the app is tied to the SSH session, inspect the process while it is still running:

```sh
ps aux | grep main
```

If the `main` process has the SSH shell in its ancestry or belongs to the SSH session instead of being managed by a supervisor, it is not safely detached from the login lifecycle.

To check whether the pipeline actually validates the running service, inspect the Jenkins output:

```sh
grep curl jenkins-console.log
grep systemctl jenkins-console.log
```

If the logs show copy/start commands but no listener check, `systemctl status`, or HTTP request to `http://<target-host>:4444/`, then the pipeline is not proving the deployed app is still healthy.

## Fix

Run the app under a service manager. A small `systemd` unit is the preferred approach because the process becomes independent of SSH and can be restarted, inspected, and logged consistently:

```sh
sudo cp main /opt/myapp/main
sudo cp myapp.service /etc/systemd/system/myapp.service
sudo systemctl daemon-reload
sudo systemctl enable myapp.service
sudo systemctl restart myapp.service
sudo systemctl status myapp.service
```

After restarting the service, make the pipeline verify the actual HTTP contract:

```sh
curl http://127.0.0.1:4444/
```

If `systemd` is not available, detaching with `nohup` is a fallback:

```sh
nohup /opt/myapp/main >/var/log/myapp.log 2>&1 </dev/null &
```

That fallback is weaker. It does not provide the same restart behavior, status reporting, or log integration that `systemd` gives.

## Lesson

Starting a process is not the same thing as deploying a service. A raw background process still depends on the environment that launched it, while a supervised service has an owner that can keep it running, report its state, and give the deployment pipeline something reliable to manage.
