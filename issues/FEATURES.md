# Features

Every issue in `issues/` carries a short feature-slug prefix so that parallel
agents and sessions never collide on filenames or a shared counter. Numbering
(`<slug>-NNNN`) runs per feature, starting at `0001`. This table maps each slug
to the feature it covers. Append new rows; never edit or remove existing ones.

| Slug | Feature |
| --- | --- |
| sccache | Compilation and dependency caching for Rust jobs on the self-hosted ARC runners (sccache, cargo registry, target reuse) |
