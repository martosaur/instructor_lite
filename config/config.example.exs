# `config/config.exs` is used ONLY for integration tests and is included into gitignore. Copy this file to `config/config.exs` to be able to run integration tests locally.

import Config

config :instructor,
  openai_key: "api_key"
