# Cache Example

A shop with a read-through product cache in an ETS table, made with [`dream_ets`](https://hexdocs.pm/dream_ets/3.0.0/). The guide [Add a cache and a rate limit](https://hexdocs.pm/dream/3.0.0/guides/caching-and-rate-limiting.html) explains each part.

## What This Demonstrates

- **A table owner** - one process makes the tables at startup and lives as long as the app
- **Read-through cache** - a miss reads the slow catalog, a hit reads the table
- **Expiry** - each entry stays for 60 seconds
- **Removal after a write** - a price change removes the entry of the product
- **Tests that control time** - the tests give the app a fixed clock, and never sleep

## Endpoints

- `GET /products/:id` - the product, with an `x-cache` header that says `hit` or `miss`
- `PUT /products/:id` - a new price in cents as the body

## Tests

### The test target <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/cache/Makefile#L6-L7"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```makefile
test:
	@gleam test
```

`make test` runs `gleam test`. The tests send requests through the routes, and compare the answers with the files in `test/outputs/`:

### A miss, a hit, and a miss after expiry <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/cache/test/outputs/cache_read_through.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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
