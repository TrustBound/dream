# Add a cache and a rate limit

Your app works, and now it has two new problems. One page reads a slow lookup, and every request waits for it again. One client sends a hundred requests in a second, and the other clients wait behind it. A cache fixes the first problem. A rate limit fixes the second. Both need state that every request can read and change, and this is where a Dream app on the BEAM differs from an app in other languages. This guide builds both in two small Dream apps, with an ETS table for the state, and tests them with a clock that the tests control.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Why a request cannot hold shared state](#why-a-request-cannot-hold-shared-state)
- [Step 1: Make the tables in a process that lives with the app](#step-1-make-the-tables-in-a-process-that-lives-with-the-app)
- [Step 2: Read the time from a clock in services](#step-2-read-the-time-from-a-clock-in-services)
- [Step 3: Read through the cache](#step-3-read-through-the-cache)
- [Step 4: Remove the entry after a write](#step-4-remove-the-entry-after-a-write)
- [Step 5: Count each request in one step](#step-5-count-each-request-in-one-step)
- [Step 6: Answer 429 in route middleware](#step-6-answer-429-in-route-middleware)
- [Step 7: Delete the rows of ended windows](#step-7-delete-the-rows-of-ended-windows)
- [The limits of this design](#the-limits-of-this-design)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide, we:

- Make each table in a process that starts with the app and lives as long as the app, and put the tables in services.
- Give the app a clock in its services, so that a test can move time forward without a sleep.
- Build a read-through cache with expiry for a slow product lookup, and see a miss, then a hit.
- Remove a cache entry after a write, so that the next read gets the new value.
- Count the requests of each client with an atomic `dream_ets` counter, and answer `429 Too Many Requests` with a `Retry-After` header.

The cache is in [`examples/cache`](https://github.com/TrustBound/dream/tree/3.0.0/examples/cache), and the rate limit is in [`examples/rate_limiter`](https://github.com/TrustBound/dream/tree/3.0.0/examples/rate_limiter). Their tests compare each output on this page with the real answers of the apps.

## Before you start

You need a Dream app with services, and Dream Test for its tests. If you do not have them, start with [Build your first Dream server](https://hexdocs.pm/dream/3.0.0/guides/getting-started.html) and [Test your controllers and your app](https://hexdocs.pm/dream/3.0.0/guides/testing.html).

Both apps use [`dream_ets`](https://hexdocs.pm/dream_ets/3.0.0/), a typed layer over ETS. ETS is the in-memory store of the BEAM. The clock uses `gleam_time`:

### The dependencies <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/cache/gleam.toml#L8-L11"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```toml
dream_ets = ">= 3.0.0 and < 4.0.0"
gleam_erlang = ">= 1.0.0 and < 2.0.0"
gleam_stdlib = ">= 0.44.0 and < 2.0.0"
gleam_time = ">= 1.5.0 and < 2.0.0"
```

## Why a request cannot hold shared state

Dream runs each connection in its own process. A value that a controller makes lives in that process, and goes away when the connection ends. No other request can see it. So a cache in a variable of a controller is empty on each new connection.

The next idea is one process that holds the state, and that every request calls. That works, but the process answers one message at a time. Under load, all requests wait in a line for it. The BEAM guide shows this line in [One process that every request calls](https://hexdocs.pm/dream/3.0.0/guides/beam.html#one-process-that-every-request-calls).

An ETS table removes the line. It holds the data outside of any process heap, and each process reads and writes it directly, at the same time as the others. But a table has an owner: the process that made it. The table goes away when its owner ends. If a request makes the table, the table goes away with the request. The BEAM guide shows this trap in [An ETS table dies with its owner](https://hexdocs.pm/dream/3.0.0/guides/beam.html#an-ets-table-dies-with-its-owner).

So the plan is: one process that makes the tables at startup, and lives as long as the app. The requests do not call it. They get the tables from services, and use them directly.

## Step 1: Make the tables in a process that lives with the app

The shop app has two tables: the catalog, which stands in for a slow database, and the product cache. `start_services` starts the owner process, and waits up to five seconds for the services that it makes:

### Start the process that owns the tables <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/cache/src/services.gleam#L34-L60"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Starts the process that owns the tables, and gives the services that
/// hold them.
pub fn start_services(settings: Settings) -> Result(Services, String) {
  let reply = process.new_subject()
  process.spawn(fn() { own_tables(settings, reply) })
  process.receive(reply, within: 5000)
  |> result.replace_error("The table owner did not start in 5 seconds")
  |> result.flatten
}

/// Stops the process that owns the tables. The tables go away with it.
pub fn stop_services(services: Services) -> Nil {
  process.send(services.table_owner, Nil)
}

/// Runs in the owner process: makes the tables, sends the services back,
/// and waits for the stop message. The tables live while this process
/// lives.
fn own_tables(settings: Settings, reply: Subject(Result(Services, String))) {
  let stop = process.new_subject()
  let started = create_services(settings, stop)
  process.send(reply, started)
  case result.is_ok(started) {
    True -> process.receive_forever(stop)
    False -> Nil
  }
}
```

The owner process makes the tables in `create_services`, sends the services back, and then waits for a stop message. While it waits, the tables live. `process.spawn` links the owner to the process that started it. In the running app, that is `main`, which never returns while the server runs. If the owner crashes, the link stops the app, and you see the crash at once.

`main` gives the settings, and starts the server only when the services started:

### Start the shop <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/cache/src/main.gleam#L14-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn main() -> Nil {
  let settings =
    Settings(
      table_prefix: "shop",
      catalog_delay_milliseconds: 500,
      time_to_live: duration.seconds(60),
      clock: SystemClock,
    )
  case start_services(settings) {
    Ok(services) -> start_server(services)
    Error(message) -> io.println_error("The shop did not start: " <> message)
  }
}
```

The catalog waits 500 milliseconds on each read, as a query on a busy database can. A test gives it 0 milliseconds.

## Step 2: Read the time from a clock in services

A cache entry expires, and a rate limit window ends. Both depend on the time. A test that waits 60 seconds for an entry to expire is slow, and a test that waits for a real clock is flaky. So the app does not read the clock of the computer directly. It reads a `Clock` from its services:

### The clock <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/cache/src/clock.gleam#L7-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Clock {
  /// The time of the computer
  SystemClock
  /// Always the same time. A test makes a new clock to move time forward.
  FixedClock(time: Timestamp)
}

/// The current time of `clock`
pub fn read_time(clock: Clock) -> Timestamp {
  case clock {
    SystemClock -> timestamp.system_time()
    FixedClock(time:) -> time
  }
}
```

The running app uses `SystemClock`. A test uses `FixedClock`, and moves time forward with a copy of the services that holds a later clock. The tables stay the same, because services hold references to the tables, not copies of them:

### Move time forward in a test <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/cache/test/shop_setup.gleam#L29-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The same services, with the clock `seconds` after `start_time`
pub fn at_second(services: Services, seconds: Int) -> Services {
  let time = timestamp.add(start_time(), duration.seconds(seconds))
  services.Services(..services, clock: FixedClock(time))
}
```

## Step 3: Read through the cache

A read-through cache sits in front of the slow lookup. On a read, it looks in the table first. A fresh entry is a hit, and the catalog does not run. A missing or expired entry is a miss: the cache reads the catalog, and keeps the product with an expiry time.

The cache table holds a product and its expiry. `dream_ets` stores any Gleam value when you give it an encoder and a decoder:

### Make the cache table <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/cache/src/product_cache.gleam#L32-L44"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Makes the cache table. The process that calls this function owns the
/// table. Each entry stays for `time_to_live`.
pub fn new(
  name: String,
  time_to_live: Duration,
) -> Result(ProductCache, EtsError) {
  config.new(name)
  |> config.key_string()
  |> config.value(encode_entry, entry_decoder())
  |> config.read_concurrency(True)
  |> config.create()
  |> result.map(fn(entries) { ProductCache(entries:, time_to_live:) })
}
```

`find_product` takes the time as a parameter. The controller reads it from the clock in services:

### Read through the cache <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/cache/src/product_cache.gleam#L46-L86"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The product with `id`: from the cache while its entry is fresh at `now`,
/// otherwise from the catalog, and then into the cache.
pub fn find_product(
  cache: ProductCache,
  catalog: Catalog,
  id: String,
  now: Timestamp,
) -> Result(Lookup, CatalogError) {
  case operations.get(cache.entries, id) {
    Ok(Some(entry)) -> use_entry(cache, catalog, id, entry, now)
    Ok(None) -> load_product(cache, catalog, id, now)
    Error(error) -> Error(catalog.store_failed(error))
  }
}

fn use_entry(
  cache: ProductCache,
  catalog: Catalog,
  id: String,
  entry: Entry,
  now: Timestamp,
) -> Result(Lookup, CatalogError) {
  case timestamp.compare(now, entry.expires_at) {
    order.Lt -> Ok(Hit(entry.product))
    order.Eq | order.Gt -> load_product(cache, catalog, id, now)
  }
}

fn load_product(
  cache: ProductCache,
  catalog: Catalog,
  id: String,
  now: Timestamp,
) -> Result(Lookup, CatalogError) {
  use product <- result.try(catalog.find_product(catalog, id))
  let entry =
    Entry(product:, expires_at: timestamp.add(now, cache.time_to_live))
  operations.set(cache.entries, id, entry)
  |> result.map_error(catalog.store_failed)
  |> result.replace(Miss(product))
}
```

The controller turns a `Hit` or a `Miss` into an `x-cache` header, so the client and the tests can see where the product came from. The test reads the lamp at second 0, at second 10 and at second 61, with a time to live of 60 seconds:

### A miss, a hit, and a miss after expiry <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/cache/test/cache_tests.gleam#L22-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
      it(
        "reads the catalog, then the cache, then the catalog after 60 s",
        fn(services: Services) {
          let first = get(services, 0, "/products/lamp")
          let second = get(services, 10, "/products/lamp")
          let third = get(services, 61, "/products/lamp")

          [first, second, third]
          |> match_output("cache_read_through")
        },
      ),
```

### The answers of the three reads <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/cache/test/outputs/cache_read_through.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
after 0 s: GET /products/lamp
  200, x-cache: miss
  Desk lamp: 4500 cents
after 10 s: GET /products/lamp
  200, x-cache: hit
  Desk lamp: 4500 cents
after 61 s: GET /products/lamp
  200, x-cache: miss
  Desk lamp: 4500 cents
```

The first read is a miss, so it waits for the catalog. The second read is a hit, and does not wait. At second 61 the entry expired, so the third read goes to the catalog again. The test needs no sleep: it gives each request a clock with the time that it wants.

## Step 4: Remove the entry after a write

Expiry alone is not enough when the data changes. After a price change, the cache can show the old price for up to 60 seconds. So the write removes the entry:

### Change the price, then remove the entry <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/cache/src/products_controller.gleam#L72-L84"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn change_price(
  services: Services,
  id: String,
  price_in_cents: Int,
) -> Response {
  let changed = {
    use _product <- result.try(catalog.change_price(
      services.catalog,
      id,
      price_in_cents,
    ))
    product_cache.forget_product(services.cache, id)
  }
```

The order is important. The controller writes the catalog first, and removes the entry after. In the other order, a read between the two steps puts the old price back into the cache. The test changes the price of the mug, and reads it again:

### The answers around a price change <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/cache/test/outputs/cache_invalidation.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
after 0 s: GET /products/mug
  200, x-cache: miss
  Coffee mug: 1200 cents
after 5 s: PUT 1500 to /products/mug
  204
  (no body)
after 6 s: GET /products/mug
  200, x-cache: miss
  Coffee mug: 1500 cents
after 7 s: GET /products/mug
  200, x-cache: hit
  Coffee mug: 1500 cents
```

The read at second 6 is a miss with the new price, and the read at second 7 is a hit with the new price.

## Step 5: Count each request in one step

Now the rate limit. The rate limiter app gives each client 10 requests in a window of 60 seconds. The first request of a client starts its first window, and the next windows follow each other from that time.

A counter looks simple: read the count, add one, write it back. But two requests of the same client can run at the same time, in two processes. Both read 9, both write 10, and both go through. Under load, a client gets far more than its limit. The count must change in one step, so that no other process can come between the read and the write.

`dream_ets` has this step. A counter table holds `String` keys and `Int` values, and [`helpers.increment`](https://hexdocs.pm/dream_ets/3.0.0/dream_ets/helpers.html#increment) adds one to a key in one atomic ETS operation, `ets:update_counter`. A key that is not in the table starts at 0. The rate limiter keeps two counter tables: the time of the first request of each client, and the count of each window:

### Make the two counter tables <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/src/services/rate_limiter_service.gleam#L50-L69"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Makes the two tables. The process that calls this function owns them:
/// call it in a process that lives as long as the app.
pub fn new(
  name: String,
  config: RateLimitConfig,
) -> Result(RateLimiter, EtsError) {
  use starts <- result.try(
    config.new(name <> "_starts")
    |> config.counter()
    |> config.write_concurrency(True)
    |> config.create(),
  )
  use counts <- result.map(
    config.new(name <> "_counts")
    |> config.counter()
    |> config.write_concurrency(True)
    |> config.create(),
  )
  RateLimiter(starts:, counts:, config:)
}
```

`count_request` finds the first request of the client, finds the window that holds the time now, and adds one to the count of that window:

### Count each request in one step <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/src/services/rate_limiter_service.gleam#L71-L104"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Counts one request of `client` at `now`, and says if it can go on
pub fn count_request(
  limiter: RateLimiter,
  client: String,
  now: Timestamp,
) -> Result(Decision, RateLimitError) {
  let now_milliseconds = to_milliseconds(now)
  use first_start <- result.try(find_first_start(
    limiter,
    client,
    now_milliseconds,
  ))
  let window_start = find_window_start(limiter, first_start, now_milliseconds)
  use count <- result.map(
    helpers.increment(limiter.counts, count_key(window_start, client))
    |> result.map_error(store_failed),
  )
  decide(limiter, count, window_start, now_milliseconds)
}

/// The time of the first request of `client`. `insert_new` is atomic: when
/// two first requests come at the same time, one start wins, and both use
/// it.
fn find_first_start(
  limiter: RateLimiter,
  client: String,
  now_milliseconds: Int,
) -> Result(Int, RateLimitError) {
  case operations.insert_new(limiter.starts, client, now_milliseconds) {
    Ok(True) -> Ok(now_milliseconds)
    Ok(False) -> read_first_start(limiter, client, now_milliseconds)
    Error(error) -> Error(store_failed(error))
  }
}
```

Each step is atomic on its own. `operations.insert_new` writes the start only when the client has no start yet. When two first requests come at the same time, one of them writes its time, and both read that time. `helpers.increment` gives back the new count, so the decision uses the count that this request made, not a count that it read before:

### Decide with the new count <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/src/services/rate_limiter_service.gleam#L119-L144"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The start of the window that holds `now`. The windows of a client follow
/// each other from its first request.
fn find_window_start(
  limiter: RateLimiter,
  first_start: Int,
  now_milliseconds: Int,
) -> Int {
  let window = window_milliseconds(limiter)
  first_start + { now_milliseconds - first_start } / window * window
}

fn decide(
  limiter: RateLimiter,
  count: Int,
  window_start: Int,
  now_milliseconds: Int,
) -> Decision {
  let limit = limiter.config.max_requests
  case count <= limit {
    True -> Allowed(limit:, remaining: limit - count)
    False -> {
      let left = window_start + window_milliseconds(limiter) - now_milliseconds
      Denied(limit:, retry_after_seconds: { left + 999 } / 1000)
    }
  }
}
```

The window that holds the time now starts a whole number of windows after the first request. A new window has a new key, so its count starts at 0 with no reset step. `Retry-After` is the time to the end of the window, in whole seconds, rounded up.

The test sends 100 requests of one client at the same time, each in its own process, and counts the requests that got through:

### 100 requests at the same time <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/test/rate_limit_tests.gleam#L52-L66"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    it(
      "allows exactly 10 of 100 requests that arrive at the same time",
      fn(_services: Services) {
        use limiter <- result.try(new_limiter("rate_limit_concurrent"))

        let decisions = count_at_the_same_time(limiter, "192.0.2.50", 100)

        decisions
        |> list.count(is_allowed)
        |> should
        |> be_equal(10)
        |> or_fail_with("exactly 10 requests should get through")
      },
    ),
    it("sweeps the rows of windows that ended", fn(_services: Services) {
```

Exactly 10 get through, on each run.

## Step 6: Answer 429 in route middleware

Dream has no global middleware. You put middleware on the routes that need it, so the welcome page stays free:

### Put the rate limit on the API routes <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/src/router.gleam#L24-L36"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  |> route(
    method: Get,
    path: "/api",
    controller: api_controller.index,
    middleware: [rate_limit_middleware.rate_limit_middleware],
  )
  // Rate-limited status endpoint
  |> route(
    method: Get,
    path: "/api/status",
    controller: api_controller.status,
    middleware: [rate_limit_middleware.rate_limit_middleware],
  )
```

The middleware finds the client, reads the time from the clock in services, and counts the request. It calls the controller only when the rate limit allows the request:

### The rate limit middleware <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/src/middleware/rate_limit_middleware.gleam#L16-L55"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn rate_limit_middleware(
  request: Request,
  context: EmptyContext,
  services: Services,
  next: fn(Request, EmptyContext, Services) -> Response,
) -> Response {
  let client = identify_client(request)
  let now = clock.read_time(services.clock)
  case rate_limiter_service.count_request(services.rate_limiter, client, now) {
    Ok(Allowed(limit:, remaining:)) ->
      next(request, context, services)
      |> add_rate_limit_headers(limit, remaining)
    Ok(Denied(limit:, retry_after_seconds:)) ->
      deny_request(limit, retry_after_seconds)
    Error(StoreFailed(reason:)) ->
      text_response(
        status.service_unavailable,
        "The rate limit store failed: " <> reason,
      )
  }
}

fn deny_request(limit: Int, retry_after_seconds: Int) -> Response {
  let response =
    text_response(
      status.too_many_requests,
      "Rate limit exceeded. Maximum "
        <> int.to_string(limit)
        <> " requests per minute.",
    )
    |> add_rate_limit_headers(limit, 0)
  Response(
    ..response,
    headers: add_header(
      response.headers,
      "Retry-After",
      int.to_string(retry_after_seconds),
    ),
  )
}
```

The test sends 11 requests from one client at second 0, one at second 30, and one at second 60:

### The answers of one client <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/test/outputs/rate_limit.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
after 0 s: 200, remaining 9
after 0 s: 200, remaining 8
after 0 s: 200, remaining 7
after 0 s: 200, remaining 6
after 0 s: 200, remaining 5
after 0 s: 200, remaining 4
after 0 s: 200, remaining 3
after 0 s: 200, remaining 2
after 0 s: 200, remaining 1
after 0 s: 200, remaining 0
after 0 s: 429, remaining 0, retry after 60
after 30 s: 429, remaining 0, retry after 30
after 60 s: 200, remaining 9
```

The eleventh request gets `429` with `Retry-After: 60`. At second 30 the client must wait 30 more seconds. At second 60 the window ended, so a new window starts with 9 requests left.

The middleware takes the client from the first address of `X-Forwarded-For`, or else from the address of the connection. Trust `X-Forwarded-For` only behind your own proxy. A client can send any value in that header, and get a new count for each value.

## Step 7: Delete the rows of ended windows

Each client gets a start row, and each window gets a count row. Without a cleanup, the tables keep rows for each client that ever came. The `sweep` function deletes the counts of the windows that ended, and the start of each client with no request in its current window:

### Delete the rows of ended windows <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/src/services/rate_limiter_service.gleam#L146-L158"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Deletes the counts of the windows that ended before `now`, and the start
/// of each client with no request in its current window. Gives the number
/// of rows that it deleted. Without it, the tables keep rows for each
/// client that ever sent a request.
pub fn sweep(
  limiter: RateLimiter,
  now: Timestamp,
) -> Result(Int, RateLimitError) {
  let now_milliseconds = to_milliseconds(now)
  use counts <- result.try(sweep_counts(limiter, now_milliseconds))
  use starts <- result.map(sweep_starts(limiter, now_milliseconds))
  counts + starts
}
```

The owner process of the tables calls it once in each window, with a timer:

### The owner sweeps once in each window <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/src/services.gleam#L69-L95"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn wait_for_sweep(
  messages: Subject(OwnerMessage),
  limiter: RateLimiter,
  clock: Clock,
  interval_milliseconds: Int,
) -> Nil {
  process.send_after(messages, interval_milliseconds, Sweep)
  case process.receive_forever(messages) {
    Sweep -> sweep(messages, limiter, clock, interval_milliseconds)
    Stop -> Nil
  }
}

fn sweep(
  messages: Subject(OwnerMessage),
  limiter: RateLimiter,
  clock: Clock,
  interval_milliseconds: Int,
) -> Nil {
  case rate_limiter_service.sweep(limiter, clock.read_time(clock)) {
    Ok(_deleted) ->
      wait_for_sweep(messages, limiter, clock, interval_milliseconds)
    // This process owns the tables, so they cannot be gone here
    Error(rate_limiter_service.StoreFailed(reason:)) ->
      io.println_error("The sweep failed: " <> reason)
  }
}
```

The test of the sweep calls `rate_limiter_service.sweep` with a time, so it does not wait for the timer either. A client that comes back after the sweep gets a new first request, and a new window.

## The limits of this design

An ETS table lives in the memory of one BEAM node. This design has two limits that come from that:

- **One node only.** If you run three copies of the app behind a load balancer, each copy has its own cache and its own counts. A client gets 10 requests from each copy, so 30 in all. For a limit across nodes, keep the counts in a store that all nodes share, such as PostgreSQL or Redis.
- **A restart clears it.** When the app stops, its tables go. After a deploy, the cache is empty and the counts start at zero. For a cache, that is normally fine: the first reads are slow, and then the cache fills again. For a limit that must hold across deploys, such as a daily quota, use a store that keeps the data.

In a single-node app, or for limits that only protect the app from bursts, these limits do not matter, and ETS is the fastest place for the state.

## Common pitfalls

**A table that a request makes.** *Symptom:* the first request works, and the next one crashes with `badarg`, or finds an empty cache. *Fix:* the request process owned the table, and the table went away with it. Make the table in the owner process at startup, and put it in services.

**A count that reads and then writes.** *Symptom:* a client gets more requests than the limit under load, but the tests with one request at a time pass. *Fix:* change the count in one ETS step with `helpers.increment` of `dream_ets`, and test with many processes at the same time.

**Removing the entry before the write.** *Symptom:* after a change, the old value sometimes comes back until the entry expires. *Fix:* write the source first, then remove the cache entry.

**Many misses at the same time.** *Symptom:* when a popular entry expires, many requests read the slow source at once. *Fix:* this cache lets each miss read the catalog. If the source cannot take that load, send the misses of one key to one process, so that only one request reads the source.

**A test that sleeps.** *Symptom:* the tests of expiry take a minute, or fail on a slow machine. *Fix:* read the time from a clock in services, and give the test a `FixedClock`.

## Where to go next

- [The BEAM for Dream developers](https://hexdocs.pm/dream/3.0.0/guides/beam.html): processes, owners and the traps that this guide avoids.
- [Grow a JSON API](https://hexdocs.pm/dream/3.0.0/guides/api-patterns.html): services, errors and the other patterns of a JSON API.
- [Test your controllers and your app](https://hexdocs.pm/dream/3.0.0/guides/testing.html): tests through the routes, as the tests of these examples do.
- [Start, stop and troubleshoot the server](https://hexdocs.pm/dream/3.0.0/guides/operating.html): how the app starts and stops, which is when the tables start and stop.
- [`dream_ets`](https://hexdocs.pm/dream_ets/3.0.0/): the full API of the typed ETS tables.
