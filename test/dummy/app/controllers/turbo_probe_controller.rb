# frozen_string_literal: true

# Two linked pages, so the system specs can exercise the components under Turbo
# Drive: page caching, restoration, and morph refreshes.
class TurboProbeController < ApplicationController
  def one; end
  def two; end
end
