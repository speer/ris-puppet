require 'ris'
require 'ris/base-application'
require 'optparse'
require 'yaml'

# Ris::App Application launcher, command line parser and config file parser
#
# Authors:
#  Stefan Peer
#  Thomas Gelf

class Ris::App

  attr_reader :application_module,
              :application_name,
              :action_name,
              :option_parser,
              :global_settings

  def initialize(application_module, application_dir, config_filepath, args = nil)
    @application_module = application_module
    @application_dir = application_dir
    @global_settings = parse_config_file(config_filepath)
    args = ARGV.clone if args.nil?
    @params = args

    if has_standalone_arg args
      @application_name = args.shift
      @action_name = args.shift if has_standalone_arg args
    end

    prepare_option_parser
  end

  def run
    fail_with_help "Application is required" unless got_application?
    fail_with_help "Got invalid application #{application_name}" unless has_application? application_name
    begin
      prepare_application
      parse_options @params
      action = action_name

      if got_action?
        if application_class.has_action? action
          application.run_action_by_name action
        else
          fail_with_help "Got invalid action #{action}"
        end
      else
        if application_class.has_action? 'default'
          application.run_action_by_name 'default'
        else
          fail_with_help "Got no action, no default action available"
        end
      end

      exit 0
    rescue => e
      if ARGV.include? '--trace'
        puts "ERROR: Application #{application_name} failed to run:\n"
        raise e
      else
        puts "ERROR: Application #{application_name} failed to run: #{e} (Use --trace to show full stack)"
        exit 1
      end
    end
  end

  # Lazy-loaded Class object of a (not initialized) Ris::BaseApplication
  def application_class
    @application_class ||= prepare_application_class
  end

  # Lazy-loaded application instance
  def application
    @application ||= prepare_application
  end

  def got_application?
    ! application_name.nil?
  end

  def got_action?
    ! action_name.nil?
  end

  # Retrieve the command name
  def command_name
    @command_name ||= File.basename($0)
  end

  def fail_with_help(message = nil)
    puts option_parser

    if @params.include?('--help')
      exit(0)
    else
      puts "\nERROR: #{message}" unless message.nil?
      exit(1)
    end
  end

  def has_application?(name)
    list_applications.include? name
  end
  
  def list_applications
    Dir["#{application_dir}/*_application.rb"].collect do |file|
      File.basename file.sub(/_application\.rb$/, '')
    end
  end

  def debug(message)
    puts message if @options[:debug]
  end

  def self.run(module_class, application_dir, args = nil)
    self.new(module_class, application_dir, args).run
  end

  protected

  def application_dir
    @application_dir || File.dirname(__FILE__) + '/application'
  end

  # Whether there is a standalone argument (no '-' prefix) in front
  # of the given argument list
  def has_standalone_arg(args)
    args.length > 0 && args[0].index('-') != 0
  end

  # Instantiates the application
  def prepare_application
    unless application_class.ancestors.include? Ris::BaseApplication
      raise "Application #{application_name} is a #{application_class} and not an instance of Ris::BaseApplication"
    end

    app = application_class.new
    app.app = self
    app.options = @options
    app.option_parser = option_parser
    app.global_settings = global_settings
    app.init if app.respond_to? 'init'
    app
  end

  # Loades and returns the (still static) application class object
  def prepare_application_class
    app = application_name
    begin
      Kernel.load "#{application_dir}/#{app}_application.rb"
      @application_class = application_module.const_get(app.capitalize)
    rescue LoadError => e
      fail_with_help "No such application: #{app}: #{e}"
    end
  end

  def prepare_option_parser
    @options = {}

    @option_parser = OptionParser.new do |opts|
      if got_application?
        appname = application_name
        has_app = has_application? appname
      else
        appname = '<application>'
        has_app = false
      end

      opts.banner = "USAGE: #{command_name} #{appname} [<action>] [options]"
      opts.separator ""

      if has_app
        opts.separator "Available actions"
        opts.separator "-----------------"

        application_class.list_actions.each do |name|
          opts.separator "* #{name}" if name != 'default'
        end

      else
        opts.separator "Available applications"
        opts.separator "----------------------"

        list_applications.each do |name|
          opts.separator "* #{name}"
        end

      end
      opts.separator ""
      opts.separator "Generic options"
      opts.separator "---------------"

      opts.on "--help", "Show Help" do
        puts opts
        exit (0)
      end

      opts.on "--debug", "Enable debug mode" do
        @options[:debug] = true
      end

      opts.on "--trace", "Show stack trace on exceptions" do
        @options[:trace] = true
      end
    end
  end

  def parse_options(args)
    option_parser.parse! args
    self
  end

  def parse_config_file(config_file)
    begin
      return YAML.load_file(config_file)
    rescue
      puts "Could not parse config file '#{config_file}'"
      exit 1
    end
  end

end
