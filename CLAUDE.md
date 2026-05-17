# fitparser_ex

Elixir wrapper for the Rust `fitparser` crate, distributed via `rustler_precompiled`. Precompiled NIFs are built by GitHub Actions and attached to a GitHub release; the Hex package only ships the Elixir + Rust sources plus a `checksum-*.exs` file.

## Release runbook

1. **Bump the version** in `mix.exs` (`@version "X.Y.Z"`). This single source feeds the workflow, the `RustlerPrecompiled` `base_url`, and the checksum filenames.
2. **Refresh deps** with `mix deps.get` (regenerates `mix.lock`).
3. **Test locally** with the right timezone — the fixtures in `test/fitparser_test.exs` bake in `+01:00` offsets:

   ```
   TZ='Etc/GMT-1' FITPARSER_TEST=1 mix test
   ```

   `FITPARSER_TEST=1` forces a local Rust build (see `force_build:` in `lib/fitparser.ex`). Without `TZ`, the timestamps fail in CEST.
4. **Commit, tag, push.** The tag is what triggers the precompile workflow's `softprops/action-gh-release` step:

   ```
   git commit -am "Release vX.Y.Z"
   git tag vX.Y.Z
   git push origin master
   git push origin vX.Y.Z
   ```
5. **Wait for `.github/workflows/release.yml`** to finish all matrix jobs and attach `.tar.gz` artifacts to the GitHub release. Watch with `gh run list --workflow=release.yml` and `gh run watch <id>`.
6. **Fetch checksums** once artifacts are live:

   ```
   mix rustler_precompiled.download Fitparser.Native --all --print
   ```

   This rewrites `checksum-Elixir.Fitparser.Native.exs`. Commit it.
7. **Publish to Hex**: `mix hex.publish`. The `package` whitelist in `mix.exs` ships `lib`, `native/fitparser_native/{.cargo,src,Cargo*}`, the checksum file, and `README*` — no `priv/` artifacts.

## Project facts worth remembering

- Supported NIF version is pinned to **2.15** (single value in workflow matrix and `Cargo.toml` feature flag).
- Unsupported targets are listed inline in `lib/fitparser.ex` (`aarch64-unknown-linux-musl`, `riscv64gc-unknown-linux-gnu`, `x86_64-unknown-linux-musl`, `arm-unknown-linux-gnueabihf`) and subtracted from `RustlerPrecompiled.Config.default_targets()`. Keep this in sync with the workflow matrix.
- Tests are timezone-sensitive (timestamps are formatted with local offset). CI does not run the Elixir tests — only the precompile workflow runs, so local testing is the only gate.
- `rustler` is declared `optional: true` in `mix.exs`; `rustler_precompiled` is the runtime path for consumers.
- GitHub auto-fails workflow runs that use deprecated action versions (e.g. `actions/upload-artifact@v3`). When a release run shows up as "queued" forever, check `gh run view <id>` annotations — a deprecated action will block every matrix job from starting. The fix is to bump versions in `.github/workflows/release.yml`, commit, then re-point the tag (delete remote + local, re-tag HEAD, push).
