# Background Work Example

An app that accepts jobs, answers `202` at once, and runs the jobs in a job worker that a supervisor starts. It uses [`gleam_otp`](https://hexdocs.pm/gleam_otp/1.2.0/) and [`dream_ets`](https://hexdocs.pm/dream_ets/3.0.0/), with no job library. The guide [Run background work](https://hexdocs.pm/dream/3.0.0/guides/background-work.html) explains each part.

## What This Demonstrates

- **A supervised worker** - an actor that a supervisor starts before the server, held in the services as a subject
- **A job table** - ETS tables from `dream_ets` that a process owns for the whole life of the app, so a status read never calls the worker
- **A bounded queue** - `503` with `retry-after` when too many jobs wait
- **A timeout for each job** - the worker stops a job that runs too long
- **A job crash** - the worker links each job and traps exits, so a crash marks only that job `failed`, and the queue goes on
- **A worker crash** - the link ends the running job, the supervisor starts a new worker, and the new worker marks the old jobs as lost
- **A periodic cleanup** - a timer message, not a sleep loop
- **A clean stop** - the running job finishes, and the jobs that wait are cancelled
- **Tests with no sleep** - each test waits for a message, with a limit

## Endpoints

- `POST /jobs` - the input of the job as the body. Answers `202` with the id and the status route.
- `GET /jobs/:id` - the state of the job: `queued`, `running`, `done` (with the result), `failed` (with the reason), `timed_out`, `lost` or `cancelled`

## Tests

### The test target <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/Makefile#L8-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```makefile
test:
	@gleam test
```

`make test` runs `gleam test`. The tests send requests through the routes, and compare the answers with the files in `test/outputs/`:

### A job from 202 to done <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/background_work/test/outputs/job_accepted.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
log: the job worker started (lost jobs: 0)
POST /jobs sales by region and team
  202 {"id":1,"status_url":"/jobs/1"}
log: job 1 started
GET /jobs/1
  200 {"id":1,"state":"running"}
log: job 1 done
GET /jobs/1
  200 {"id":1,"state":"done","result":"words: 5, lines: 1"}
```
