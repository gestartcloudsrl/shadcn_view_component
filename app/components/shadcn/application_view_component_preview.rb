# frozen_string_literal: true

module Shadcn
  # Base class for the sidecar `preview.rb` files rendered by Lookbook.
  class ApplicationViewComponentPreview < ViewComponentContrib::Preview::Base
    self.abstract_class = true
  end
end
