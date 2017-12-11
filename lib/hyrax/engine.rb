module Hyrax
  class Engine < ::Rails::Engine
    isolate_namespace Hyrax

    # These gems must be required outside of an initializer or they don't get loaded.
    require 'awesome_nested_set'
    require 'breadcrumbs_on_rails'
    require 'jquery-ui-rails'
    require 'flot-rails'
    require 'almond-rails'
    require 'jquery-datatables-rails'
    require 'flipflop'
    require 'qa'
    require 'clipboard/rails'
    require 'legato'
    require 'pul_uv_rails'

    # Force these models to be added to Legato's registry in development mode
    config.eager_load_paths += %W[
      #{config.root}/app/models/hyrax/download.rb
      #{config.root}/app/models/hyrax/pageview.rb
    ]

    config.action_dispatch.rescue_responses.merge!(
      "Valkyrie::Persistence::ObjectNotFoundError" => :not_found,
      "Blacklight::Exceptions::RecordNotFound" => :not_found
    )

    config.before_initialize do
      # ActionCable should use Hyrax's connection class instead of app's
      config.action_cable.connection_class = -> { 'Hyrax::ApplicationCable::Connection'.safe_constantize }
    end

    config.after_initialize do
      begin
        Hyrax.config.persist_registered_roles!
        Rails.logger.info("Hyrax::Engine.after_initialize - persisting registered roles!")
      rescue ActiveRecord::StatementInvalid
        message = "Hyrax::Engine.after_initialize - unable to persist registered roles.\n"
        message += "It is expected during the application installation - during integration tests, rails install.\n"
        message += "It is UNEXPECTED if you are booting up a Hyrax powered application via `rails server'"
        Rails.logger.info(message)
      end
    end

    initializer 'requires' do
      require 'hydra/derivatives'
      require 'hyrax/search_state'
      require 'hyrax/errors'
      require 'power_converters'
      require 'dry/struct'
      require 'dry/equalizer'
      require 'dry/validation'
    end

    initializer 'routing' do
      require 'hyrax/rails/routes'
    end

    initializer 'configure' do
      # Allow flipflop to load config/features.rb from the Hyrax gem:
      Flipflop::FeatureLoader.current.append(self)

      Hyrax.config.tap do |c|
        Hydra::Derivatives.ffmpeg_path    = c.ffmpeg_path
        Hydra::Derivatives.temp_file_base = c.temp_file_base
        Hydra::Derivatives.fits_path      = c.fits_path
        Hydra::Derivatives.enable_ffmpeg  = c.enable_ffmpeg
        Hydra::Derivatives.libreoffice_path = c.libreoffice_path

        Noid::Rails.config.template = c.noid_template
        Noid::Rails.config.minter_class = c.noid_minter_class
        Noid::Rails.config.statefile = c.minter_statefile
      end
    end

    initializer 'valkyrie_global_id' do
      GlobalID::Locator.use(GlobalID.app, Hyrax::ValkyrieLocator.new)
    end

    initializer 'hyrax.assets.precompile' do |app|
      app.config.assets.paths << config.root.join('vendor', 'assets', 'fonts')
      app.config.assets.paths << config.root.join('app', 'assets', 'images')
      app.config.assets.paths << config.root.join('app', 'assets', 'images', 'blacklight')
      app.config.assets.paths << config.root.join('app', 'assets', 'images', 'hydra')
      app.config.assets.paths << config.root.join('app', 'assets', 'images', 'site_images')

      app.config.assets.precompile << /fontawesome-webfont\.(?:svg|ttf|woff)$/
      app.config.assets.precompile += %w[*.png *.jpg *.ico *.gif *.svg]

      Sprockets::ES6.configuration = { 'modules' => 'amd', 'moduleIds' => true }
      # When we upgrade to Sprockets 4, we can ditch sprockets-es6 and config AMD
      # in this way:
      # https://github.com/rails/sprockets/issues/73#issuecomment-139113466
    end
  end
end
