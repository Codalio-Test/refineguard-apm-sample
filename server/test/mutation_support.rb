# frozen_string_literal: true

# Loaded by `.mutant.yml` before the test files, and only then.
#
# `mutant-minitest` runs a test only for the mutations its class claims to cover
# via `cover '<expression>'`. The expression is matched against the mutation's
# subject, so a blanket `"*"` selects nothing: every test class that is expected
# to kill mutations must name the mutated constant itself. The declarations
# therefore live next to the assertions that justify them, in the test class
# bodies.
#
# This file is not a test file (`test_*.rb` / `*_test.rb`), so it is never loaded
# by `bin/rails test`, and `bundle exec mutant` loads it from `.mutant.yml`.
require "mutant/minitest/coverage"
