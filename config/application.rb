require_relative "boot"

# Require Rails manually to avoid unused rails components
# active_storage/engine
# action_cable/engine
# action_mailbox/engine
# action_text/engine
# rails/test_unit/railtie
require "rails"
%w[
  active_record/railtie
  action_controller/railtie
  action_view/railtie
  action_mailer/railtie
  active_job/railtie
].each do |railtie|
  require railtie
rescue LoadError
end

require "rack/contrib"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Manyfold
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    config.after_initialize do
      # Create default admin user if there aren't any users yet
      if ActiveRecord::Base.connection.table_exists?("users") && User.count == 0
        User.create(
          username: "admin",
          email: "nobody@example.com",
          admin: true
        )
      end
    end
    config.middleware.use Rack::Locale
    config.i18n.fallbacks = true
  end
end
