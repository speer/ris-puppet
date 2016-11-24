# Ris::Puppetfile handles the r10k Puppetfile
#
# Authors:
#  Stefan Peer
#  Thomas Gelf

class Ris::Puppetfile

  attr_reader :filename

  def initialize(filename)
    raise "No Puppetfile found at #{filename}" unless File.file? filename
    @filename = filename
    parse
  end

  def set_module(name, ref = nil)
    @modules[name] = {}
    unless ref.nil?
       @modules[name][':ref'] = ref
    end
    self
  end

  def set_ext_module(author, name, ref = nil)
    set_module build_name(author, name), ref
    self
  end

  def unset_module(name)
    @modules.delete(name) 
  end

  def unset_ext_module(author, name)
    @modules.delete build_name(author, name) 
  end

  def render
    out = header

    out << title('RIS roles')
    out << stringify_mods('ris_int', @modules.reject { |name, opts|
      name.match(/^risrole_/).nil?
    })

    out << title('RIS profiles')
    out << stringify_mods('ris_int', @modules.reject { |name, opts|
      name.match(/^risprof_/).nil?
    })

    out << title('External modules')
    out << stringify_mods('ris_ext', @modules.reject { |name, opts|
      name.index('/').nil?
    })

    out << title('RIS modules')
    out << stringify_mods('ris_int', @modules.reject { |name, opts|
      ! name.match(/^risrole_/).nil? || ! name.match(/^risprof_/).nil? || ! name.index('/').nil?
    })

    out << "\n"
  end

  def store
    File.open(@filename, 'w') do |file|
      file.write render
    end
  end

  protected

  def title(title)
    "\n\n# #{title}\n# #{'=' * title.length}\n"
  end

  def build_name(author, name)
    "#{author}/#{name}"
  end

  def stringify_mods(prefix, mods)
    mods.keys.sort.collect { |key|
      name = "#{prefix} '" + key.split('/', 2).join("', '") + "'"
      mods[key].collect {|k, v|
        k + " => " + v
      }.unshift(name).join ', '
    }.join "\n"
  end

  def parse
    @modules = {}

    File.readlines(@filename).each do |line|
      next unless m = line.match(/^ris_(int|ext)\s+'([a-zA-Z0-9_]+)'(?:,\s*'([a-zA-Z0-9_]+)')?(.*)$/)
      type = $1
      name1 = $2
      name2 = $3
      options = {}

      $4.gsub(/^\s*,\s*/, '').split(/\s*,\s*/).each do |opt|
        (key, val) = opt.split(/\s*=>\s*/, 2)
        options[key] = val
      end
      name = name1
      name << '/' << name2 if name2
      @modules[name] = options
    end
  end

  def header
    "require File.join(File.dirname(__FILE__), 'ris_shortcuts')\n"
  end
end
