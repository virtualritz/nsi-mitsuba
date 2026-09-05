# Quickstart: ɴsɪ Scene Recording And Resolution

## Build

```bash
cd ~/code/crates/nsi-mitsuba
cargo build --workspace
```

`nsi-record` depends on `nsi` **by path**, so it tracks that working
tree, uncommitted changes included. A red test here may originate there.

## Verification Commands

```bash
# Everything.
cargo test --workspace

# Per contract.
cargo test -p nsi-record --lib owned         # recording.md
cargo test -p nsi-record --test classifier   # classification.md
cargo test -p nsi-record --lib resolve       # resolution.md
cargo test -p nsi-record --test stream_roundtrip  # stream.md
```

Expected at the time of writing: 43 passing, 0 failing.

## Manual QA Path

`stream_roundtrip` needs a working 3Delight; it creates a real
`apistream` context. Confirm with:

```bash
cargo test -p nsi-record --test stream_roundtrip -- --nocapture 2>&1 \
  | rg '3Delight'
```

A banner such as `# 3Delight 2.9.207 linux64 ... "Re-Animator"` proves
the reference side really ran. **Without 3Delight this test cannot
pass, and its absence is not a licence to mark `stream.md` `Covered`.**

## Regenerating The Stream Oracle

There is no checked-in fixture: the reference is produced live by
3Delight in the same test run, from the same `build` function. If
3Delight's format changes, the test fails and `stream.rs` is corrected —
never the expectation.
