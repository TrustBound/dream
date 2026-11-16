# Changelog

All notable changes to `dream_config` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Fixed
- `load_dotenv()` and `load_dotenv_from(path)` always returned `Ok(Nil)`,
  although their type is `Result(Nil, String)` and the docs said that a bad
  file is an error. The `dot_env` load functions return `Nil` and only print
  the problem to standard error, so the error was lost. Both functions now
  read and parse the file themselves and return `Error(String)` with the
  path and the reason:
  - the file cannot be read (no permission, a directory, or not UTF-8), for
    example `Cannot load .env file at .env: permission denied`
  - a line is not valid (no `=`, an empty name, a quote that is not closed,
    or text after a closing quote), with its line number, for example
    `Cannot load .env file at .env: line 2: expected NAME=VALUE`
  - `load_dotenv_from(path)` only: the file does not exist, for example
    `Cannot load .env file at /etc/myapp/.env: the file does not exist`

  A missing `.env` file is still `Ok(Nil)` for `load_dotenv()`, because that
  file is optional where the variables are set directly. On an error, no
  variable from the file is set. The file format is the same as before
  (names are changed to upper case).
- `get_bool` accepted only `true`, `True`, `TRUE`, `yes`, `YES` and `1`,
  although the docs said it is case-insensitive. It now accepts `true` and
  `yes` in any mix of upper and lower case (for example `tRUE` and `Yes`),
  and `1`.

### Changed
- Each code example in the `dream_config/loader` doc comments is now a
  tested snippet, and the examples are valid Gleam.

### Upgrading
- If your code called `load_dotenv()` or `load_dotenv_from(path)` and
  ignored the result, a bad file is now an `Error`. Handle it, for example
  with `use _ <- result.try(config.load_dotenv())`.
- If you call `load_dotenv_from(path)` with a path that may not exist, check
  for the file first or treat the `Error` as "no file".
- A `.env` line with no `=` used to be joined with the next line into one
  name, or, as the last line, stopped the whole file from loading with no
  error. It is now an error: fix the line or make it a comment with `#`.
- Text after a closing quote on the same line (other than a `#` comment)
  is now an error.
- `get_bool` now returns `True` for values such as `tRUE` or `Yes` that it
  returned `False` for before.

## 1.0.2 - 2025-11-21

### Changed
- Added HexDocs documentation badge to README

## 1.0.1 - 2025-11-22

### Fixed
- Fixed logo display on hex.pm by using full GitHub URL
- Added Dream logo to README

## 1.0.0 - 2025-11-21

### Added
- Initial stable release
- `load_dotenv()` - Load `.env` file from default location
- `load_dotenv_from(path)` - Load `.env` file from specific path
- `get_required(name)` - Get required environment variable
- `get(name)` - Get optional environment variable
- `get_required_int(name)` - Get required integer environment variable
- `get_int(name)` - Get optional integer environment variable
- `get_bool(name)` - Get boolean environment variable

