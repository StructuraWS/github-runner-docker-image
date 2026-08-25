# Share the cargo registry cache with the user jobs actually run as

## What to build

The runner scale set mounts the shared cache PVC over the cargo registry and cargo git
caches under the `runner` user's home. Jobs, however, run as root: the image never reverts
from `USER root`, and the deployment sets `RUNNER_ALLOW_RUNASROOT`. Cargo therefore reads
and writes its registry under root's home, which is *not* on the PVC — so those two mounts
cache nothing, and every job re-downloads and re-unpacks the full dependency set from
crates.io and from the private git dependencies. The sccache mount in the same deployment
is already pointed at root's home, which is what makes the mismatch easy to miss.

Make the registry and git caches land on the shared PVC for the user jobs really run as,
and prove it with a job that shows no re-download of already-cached crates. Pick one
direction deliberately — either point the mounts at the home cargo actually uses, or pin
`CARGO_HOME` so the existing mount paths become correct — and write down which, so the
next person changing the runner user does not silently undo it.

While in here, take the registry trim off the critical path: the consuming Rust workflow
runs `cargo cache --autoclean` inside the build job every tenth run, which its own comment
records as roughly 4.5 minutes of build time. With the registry finally shared across jobs
it will actually need pruning, and a build job is the wrong place to pay for it — move it
to a scheduled job or a maintenance workflow against the PVC.

Verify against the same build job used for the sccache baseline, so the saving is
attributable: crate download/unpack time in the validate step, and total job wall clock.

Spans two repos: the ARC runner scale set values (k3ssetup) and the consuming Rust repo
(awsrs) for the trim relocation. Touches this repo only if pinning `CARGO_HOME` in the
image is the chosen direction.

## Acceptance criteria

- [ ] Cargo's registry and git caches for the user jobs run as are backed by the shared
      cache PVC
- [ ] A second consecutive job on an unchanged dependency set downloads no crates it has
      already cached, evidenced in the job log
- [ ] The choice between relocating the mounts and pinning `CARGO_HOME` is documented
      alongside the setting, including what breaks if the runner user changes
- [ ] `cargo cache --autoclean` no longer runs inside the build job; registry pruning
      happens outside the critical path and is proven to still bound PVC growth
- [ ] Before/after wall clock for the same build job is recorded on the issue
- [ ] If the chosen direction changes the Dockerfile: that change is committed and pushed
      to `main` first, CI finishes building and pushing the new runner image, and the
      runner pods are cycled to pick it up before the rest is verified

## Blocked by

- sccache-0001 (its stats and cache-health reporting is how this slice's before/after is
  measured)
