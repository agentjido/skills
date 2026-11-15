# Jido skill evaluation proof

This Mix project proves a small evaluation pattern for the two public Jido
Work System skills. It uses the `release/v3` branch of Jido.Harness.

The proof has two suites and one case in each suite:

| Suite | Skill | Case |
| --- | --- | --- |
| `jido_core` | Jido | Inspect two files and return a checked read-only report. |
| `tutor_core` | Tutor | Review a weak work request without doing the work. |

Each case follows the same path:

```text
case -> harness run -> observation -> deterministic metrics -> JSON report
```

An observation contains the final text, tool signals, usage, status, and a
workspace snapshot result. The metrics check the outcome, safety, and required
protocol. There is no LLM judge in this proof.

## Setup

```sh
mix deps.get
mix compile
mix jido_harness.check
```

The readiness check does not send a model request. Each provider needs its
base CLI, ACP entry point, and normal authentication.

## Inspect the case dataset

```sh
mix evals.run --list
mix evals.run --list --suite tutor_core
```

These commands do not send a model request.

## Run the proof

Run both cases against one provider and model:

```sh
mix evals.run --provider codex --model MODEL_ID --reasoning-effort medium
```

Run one suite when you want one model request:

```sh
mix evals.run --provider pi --model MODEL_ID --suite tutor_core
```

Valid reasoning levels are `low`, `medium`, `high`, and `xhigh`. Provider and
model support can differ. Jido.Harness returns an error for an unsupported
option.

A full run sends two live model requests. A selected suite sends one request.
These requests can use API or subscription capacity. The runner makes a new
temporary workspace for each case and installs only the skill under test. It
removes the workspace after the run.

Each batch saves one JSON report under `results/`. The report contains the
case data, normalized observation, metric results, model settings, and batch
summary. Use separate commands for separate model profiles. Compare the JSON
reports after each profile has the same two cases.

## Local checks

```sh
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

The tests use fixed observations. They verify the case catalog and metric
pipeline without a live model call.
