require_relative "boot"

require "rails"
require "active_model/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require "shadcn_view_component"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f

    config.action_controller.include_all_helpers = false
    config.autoload_lib(ignore: %w[assets tasks])

    # Previews render inside layouts/application.html.erb, which loads the
    # compiled Tailwind bundle and the Stimulus controllers, so components look
    # and behave the way they do on ui.shadcn.com.

    config.lookbook.project_name = "shadcn ViewComponent"
    config.lookbook.ui_theme = "zinc"
  end
end
