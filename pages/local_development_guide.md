# Local Development Guide

You should be able to run most tests out of the box:

```
mix deps.get
mix test
```

However, to actually be able to query LLMs, you'll need to put your own personal API keys into a `config/config.exs`, which is ignored by git. Start by copying `config/config.example.exs`:

```
cp config/config.example.exs config/config.exs
```

Depending on what secrets you have, you'll be able to run integration tests for different adapters. All integration tests can be found in `test/integration_test.exs`. Here's how to run OpenAI suite:

```
mix test test/integration_test.exs:9
```