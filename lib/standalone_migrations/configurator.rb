require 'active_support/all'
require 'yaml'

module StandaloneMigrations

  class InternalConfigurationsProxy

    attr_reader :configurations
    def initialize(configurations)
      @configurations = configurations
    end

    def on(config_key)
      if @configurations[config_key] && block_given?
        @configurations[config_key] = yield(@configurations[config_key]) || @configurations[config_key]
      end
      @configurations[config_key]
    end

  end

  class Configurator
    def self.load_configurations
      @env_config ||= Rails.application.config.database_configuration
      ActiveRecord::Base.configurations = @env_config
      @env_config
    end

    def self.environments_config
      proxy = InternalConfigurationsProxy.new(load_configurations)
      yield(proxy) if block_given?
    end

    def initialize(options = {})
      default_schema = ENV['SCHEMA'] || ActiveRecord::Tasks::DatabaseTasks.schema_file(ActiveRecord::Base.schema_format)
      defaults = {
        :config       => "db/config.yml",
        :migrate_dir  => "db/migrate",
        :root         => Pathname.pwd,
        :seeds        => "db/seeds.rb",
        :schema       => default_schema,
        :models_path  => "app/models",
        :models_module  => "App::Models",
        :models_baseclass  => "ApplicationRecord",
      }
      @options = load_from_file(defaults.dup) || defaults.merge(options)

      ENV['SCHEMA'] = schema
      Rails.application.config.root = root
      Rails.application.config.paths["config/database"] = config
      Rails.application.config.paths["db/migrate"] = migrate_dir
      Rails.application.config.paths["db/seeds.rb"] = seeds
      Rails.application.config.model_generation_path = models_path #Rails.configuration.model_generation_path
      Rails.application.config.models_generation_module = models_module #Rails.configuration.models_generation_module
      Rails.application.config.models_inheritance_baseclass = models_baseclass  #Rails.configuration.models_inheritance_baseclass
      
    end

    def config
      @options[:config]
    end

    def migrate_dir
      @options[:migrate_dir]
    end

    def root
      @options[:root]
    end

    def seeds
      @options[:seeds]
    end

    def schema
      @options[:schema]
    end

    def models_path
      @options[:models_path]
    end
    
    def models_module
      @options[:models_module]
    end
    
    def models_baseclass
      @options[:models_baseclass]
    end
      
    
    def config_for_all
      Configurator.load_configurations.dup
    end

    def config_for(environment)
      config_for_all[environment.to_s]
    end

    private

    def configuration_file
      if !ENV['DATABASE']
        ".standalone_migrations"
      else
        ".#{ENV['DATABASE']}.standalone_migrations"
      end
    end

    def load_from_file(defaults)
      return nil unless File.exist? configuration_file
      config = YAML.load( ERB.new(IO.read(configuration_file)).result )
      {
        :config       => config["config"] ? config["config"]["database"] : defaults[:config],
        :migrate_dir  => (config["db"] || {})["migrate"] || defaults[:migrate_dir],
        :root         => config["root"] || defaults[:root],
        :seeds        => (config["db"] || {})["seeds"] || defaults[:seeds],
        :schema       => (config["db"] || {})["schema"] || defaults[:schema],
        :models_path  => (config["paths"] || {})["models"] || defaults[:models_path],
        :models_module  => (config["modules"] || {})["models"] || defaults[:models_module],
        :models_baseclass  => (config["models"] || {})["baseclass"] || defaults[:models_baseclass],
      }
    end

  end
end
