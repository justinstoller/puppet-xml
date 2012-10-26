Puppet::Type.newtype :xml do
  desc 'A helper for editing XML values'
  # Puppet is inconsistent as shit. I'm going to make it prettier and more
  # consistent until these become patches in core.
  def self.new_parameter(*args, &block)
    newparam *args, &block
  end
  def self.new_property(*args, &block)
    newproperty *args, &block
  end

  class ::Puppet::Parameter
    class << self
      alias_method :default_to,  :defaultto
      alias_method :require!,    :isrequired
      alias_method :new_values,  :newvalues
      alias_method :alias_value, :aliasvalue
    end
  end

  ensurable

  new_parameter :name, :namevar => true do
    desc "This is the name, it's the namevar. It's the namevar because there "+
         "is no gauranteed unique parameter among the xpath, file, value and "+
         "attributes. Only all of them in combination, and come one, do you " +
         "really want me to make you write that all on one line?"
  end # :name

  new_parameter :element do
    desc "This is any valid xpath that will match the element you wish " +
         "to modify. If you wish to modify multiple elements at once set " +
         "the **match** parameter to `all`."

    require!
  end # :element

  new_parameter :target do
    desc "This parameter allows you to supply any valid xml `transport` " +
         "It may be either a resource who's content attribute yields an " +
         "object that implements an IO interface (a File descriptor or " +
         "StringIO, for example) or a String representing a local path to " +
         "a file to open."

    require!
  end # :target

  new_property :value do
    desc "This is the value that the matching **element**(s) receive"
    munge {|input| input.to_s }
  end # :value

  new_property :attributes do
    desc "The attributes that the matching **element** should have. " +
         "These can be either in a hash or as a string with key=value pairs " +
         "deliminated by space and the keys vs values are deliminated by an " +
         "equals sign."

    default_to Hash.new

    validate do |input|
      raise Puppet::Error, 'Attributes must be either a String or a Hash, ' +
        "not a(n) #{input.class}" unless input.is_a? String or input.is_a? Hash
    end

    munge do |input|
      if input.is_a? String
        attrs = Hash.new
        pairs = input.split(' ')
        pairs.each do |pair|
          key, value = pair.split('=').map {|element| element && element.chomp }
          attrs[key] = value
        end
        attrs
      else
        input
      end
    end

  end # :attributes

  new_parameter :match do
    desc "Matching strategy when selecting **element**(s).\n" +
         "`first` selects the first element matching **element**'s xpath.\n" +
         "`last` selects the last element matching **element**'s xpath\n" +
         "`all` operates on all matching elements\n" +
         "`strict` raises an error if multiple matching elements exist\n" +
         "(default: strict)"
    
    # one or more Strings, Symbols or Regexes that are valid values
    new_values :first, :last, :all, :strict

    default_to :strict
  end # :match
end
