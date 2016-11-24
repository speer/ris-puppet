require 'ris'

# Ris::BaseApplication - wrapper to OptionParser, base class for application classes
#
# Authors:
#  Stefan Peer
#  Thomas Gelf

class Ris::BaseApplication

  attr_accessor :option_parser, :options, :app, :global_settings

  def self.list_actions
    (self.instance_methods - Class.public_methods).collect { |method|
      $1 if method.match /^(.+)_action$/
    }.compact.sort
  end

  def self.has_action?(action_name)
    self.list_actions.include? action_name
  end

  def run_action_by_name(action_name)
    self.send(action_name + '_action')
  end

  def on_option(*args, &block)
    require_custom_header
    option_parser.send 'on', *args, &block
  end

  def require_custom_header
    opts = option_parser
    return if @custom_header_set

    opts.separator ""
    opts.separator "Specific options"
    opts.separator "----------------"

    @custom_header_set = true
  end

  def add_option(key, *args)
    self.send 'on_option', *args do |value|
      set_option key, value
    end
  end

  def set_option(key, val)
    options[key] = val
    self
  end

  def get_option(key, default = nil)
    if has_option? key
      options[key]
    else
      default
    end
  end

  def has_option?(key)
    options.has_key? key
  end

  def get_required_option(key)
    raise "#{key} is required" unless has_option? key
    options[key]
  end

  def has_setting?(key)
    global_settings.has_key? key
  end

  def get_setting(key, default = nil)
    if has_setting? key
      global_settings[key]
    else
      default
    end
  end

  def get_required_setting(key)
    raise "#{key} is required in config file" unless has_setting? key
    global_settings[key]
  end

end
