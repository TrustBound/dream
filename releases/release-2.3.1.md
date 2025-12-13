# Dream 2.3.1 Release Notes

**Release Date:** December 13, 2025

This is not “just a patch release”.

This is the moment web development looks back on and quietly says: _“…yeah, that changed everything.”_

Historians will argue where the modern era began.
Some will cite the printing press.
Some will cite the internet.

They will be wrong.

The modern era began when we stopped writing `418` like we were chiseling responses into stone tablets, and started writing the only thing that was ever true:
`teapot`.

## Key Highlights

- **A new era of human-readable computing**: `teapot` exists, and your codebase can finally stop pretending it enjoys numerals
- **RFC 2324 alignment**: Dream now stands on the shoulders of giants (and the shoulders are holding coffee)
- **Massively improved signal-to-number ratio**: one less “magic number”, one more semantic truth
- **Societal impact**: code review comments reduced by up to 418% (this statistic is obviously real because it contains a number)

## The Feature That Will Be Remembered

We added the single most important public constant in the history of constants:

`teapot = 418`

Yes, it’s “just” an Int.
So is gravity.

### Before (the dark ages)

```gleam
text_response(418, "No.")
```

### After (enlightenment)

```gleam
import dream/http/response.{text_response}
import dream/http/status.{teapot}

pub fn brew_coffee(_request, _context, _services) {
  text_response(teapot, "Server refuses to brew coffee because it is, in fact, a teapot.")
}
```

Your future self will weep with gratitude.
Your teammates will weep with gratitude.
Somewhere, an editor linter will briefly consider smiling.

### Compatibility

This is fully backwards-compatible.
You can keep using `418` if you absolutely insist on living dangerously.

## Upgrading

Update your dependencies:

```toml
[dependencies]
dream = ">= 2.3.1 and < 3.0.0"
```

Then run:

```bash
gleam deps download
```

## Documentation

- [dream](https://hexdocs.pm/dream) - v2.3.1

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream/blob/main/CHANGELOG.md)
