# Make the sccache cache location explicit and report cache health per job

## What to build

Today the runner image sets `RUSTC_WRAPPER=sccache` and `CARGO_INCREMENTAL=0` but never
says *where* sccache should cache. It works only because sccache's default
(`$HOME/.cache/sccache`, and `HOME=/root` since the image never reverts to the `runner`
user) happens to match the path the ARC deployment mounts from the shared cache PVC. That
coupling is invisible from both sides: change the user in the image, or the mount path in
the runner scale set, and caching silently degrades to zero with no failure anywhere.

Make the contract explicit and self-verifying end to end:

- The image declares its cache location and limits instead of relying on defaults that
  depend on which user the job happens to run as, and on a cache size limit that nobody
  has compared against the PVC.
- The runner deployment mounts exactly that declared path.
- A real Rust job proves it: the sccache stats block is emitted readably (today the whole
  block is crammed into a single `::notice::` because of the backtick interpolation, so
  only the first line is annotated), and a hit rate below a sane floor is surfaced as a
  warning rather than passing silently.

Measured baseline to improve against (awsrs, "Moreh and Account SAM build", run
32905865587, 2026-08-25): 2206 compile requests, 99.33% overall hit rate, 97.43% for Rust,
0 cache read/write errors, cache location `/root/.cache/sccache`. sccache itself is
healthy — this slice is about making that state guaranteed and observable rather than
accidental, and it produces the before/after harness the other two slices are measured
with.

Also settle the idle-timeout question here: the sccache server should not exit mid-job on
long builds, and the consuming workflows should not have to work around it.

Spans two repos: the image (this repo) and the ARC runner scale set values (k3ssetup).
The workflow-side stats reporting lands in the consuming Rust repo (awsrs).

## Acceptance criteria

- [ ] The image declares the sccache cache directory, cache size limit and idle timeout
      explicitly, rather than inheriting defaults tied to `HOME`
- [ ] The declared cache size limit is reconciled with the actual capacity of the shared
      cache PVC, and the reasoning is written down next to the setting
- [ ] The runner scale set mounts the cache at exactly the path the image declares; a
      mismatch between the two is impossible to introduce without one side failing loudly
- [ ] A consuming Rust workflow prints the full sccache stats block as readable log output
      (not collapsed into one annotation line) and emits a warning when the Rust hit rate
      falls below an agreed floor
- [ ] A build run after the change shows a Rust hit rate at least as good as the 97.43%
      baseline, with 0 cache read/write errors
- [ ] Because this changes the Dockerfile: the Dockerfile change is committed and pushed to
      `main` first, CI is allowed to finish building and pushing the new runner image to
      the registry, and the runner pods are cycled so new jobs pick up that image — only
      then is the rest of the work verified

## Blocked by

None - can start immediately.
