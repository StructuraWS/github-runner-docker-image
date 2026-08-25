# Cut the cold compile out of the clippy validation step

## What to build

The validation step is where the Rust build time actually goes, and it is the one step
that deliberately runs *without* sccache: the shared validate action clears `RUSTC_WRAPPER`
before invoking clippy, presumably because sccache cannot wrap `clippy-driver`. Combined
with `CARGO_INCREMENTAL=0` from the image and a `target/` directory that is never carried
between jobs (the runner's work dir is a pod-local `emptyDir`, and the crate-source cache
action in the workflow is commented out), every job compiles the whole workspace from
scratch under clippy with no cache of any kind.

Measured on awsrs "Moreh and Account SAM build" run 32905865587 (2026-08-25): the job took
16m44s, of which the clippy/validate step took 13m50s and the subsequent arm64 lambda build
— the part that *does* use sccache, at a 97.43% Rust hit rate — took only 2m34s. Fixing
this step is worth more than every other caching change in this feature combined.

Deliver a validation step that reuses prior compilation work across jobs and prove the
saving on a real run. The approach is a genuine decision, not a detail, and needs to be
settled as part of this slice:

- Re-check whether the current sccache release can wrap clippy at all; if it can, the fix
  is to stop clearing the wrapper, and if it cannot, record that finding so nobody retries
  it blindly.
- Otherwise carry `target/` between jobs. Note that the scale set runs up to 10 concurrent
  runners against one RWX PVC, so a single shared target directory is not safe to write
  from several jobs at once — cargo will lock and serialize. Scope the reuse per repository
  and branch, or use a cache action against a backend that handles concurrency, rather than
  bolting another subPath onto the PVC and hoping.
- Revisit `CARGO_INCREMENTAL=0` in the image once target reuse exists: it is the right
  setting for a pure sccache setup, but it is not obviously right once a warm `target/` is
  in play. Measure rather than assume, and keep whichever wins.

This slice is HITL: the concurrency/backend choice should be agreed with the Human before
implementation, because it decides how the cache PVC is shaped for everything else.

Spans the consuming Rust repo (awsrs) for the validate action and workflows, the ARC runner
scale set (k3ssetup) if the chosen approach needs new storage, and this repo only if
`CARGO_INCREMENTAL` changes.

## Acceptance criteria

- [ ] It is established and written down whether the current sccache can wrap clippy, and
      the wrapper is no longer cleared blindly
- [ ] Validation reuses compilation work across jobs, by whichever mechanism was agreed
- [ ] Two jobs running concurrently on the same repository do not corrupt or serialise on
      the reused build artifacts, demonstrated rather than assumed
- [ ] The clippy/validate step's wall clock on a warm cache is recorded against the 13m50s
      baseline, on the same workflow and workspace
- [ ] `CARGO_INCREMENTAL=0` is re-measured with the warm cache in place and either kept
      with a recorded reason or changed
- [ ] If `CARGO_INCREMENTAL` changes in the image: that Dockerfile change is committed and
      pushed to `main` first, CI finishes building and pushing the new runner image, and
      the runner pods are cycled to pick it up before the rest is verified

## Blocked by

- sccache-0001 (its stats and cache-health reporting is how this slice's before/after is
  measured)
