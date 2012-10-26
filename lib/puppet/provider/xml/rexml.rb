# Lifecycle
# This will have the class method ::prefetch called.
# That class method will in turn initialize all providers
# and each instance will fetch its content
Puppet::Type.type(:xml).provide(:rexml) do

  def create; end
  def destroy; end
  def exists?; true; end

  mk_resource_methods

  attr_reader :fetched_content
  def instantiate resource, fetched_content
    super( resource )
    @fetched_content = fetched_content
  end

  def flush
    self.class.register :synced, self, resource[:target]
  end

  # So this works, it just causes a horrendous amount of warnings because
  # class variables are BAD. I believe this can be pulled out into a Singleton
  # object later.
  @@targets = {}

  class << self
    def prefetch resources
      resources.each do |name, type|
        if type[:target].is_a? Puppet::Resource then
          target = referenced_type(type, :target)
        else
          target = type[:target]
        end

        if cached? target then
          fetched_content = cached( target, :content )
        else
          fetched_content = prefetch_content( target )
        end

        # does this feel dirty to anyone else?
        new_provider = new( type, fetched_content )
        type.provider = new_provider

        unless cached? target
          initialize_cache_for target, new_provider, fetched_content
        end

        register :instantiated, new_provider, target
      end
    end

    def cached? target
      !! @@targets[target.to_s]
    end

    def cached target, attribute
      @@targets[target.to_s][attribute]
    end

    def initialize_cache_for target, provider, content
      target_name = target.to_s
      @@targets[target_name] = Hash.new
      @@targets[target_name][:content] = content
      @@targets[target_name][:count] = 0
      @@targets[target_name][:target] = target
    end

    # is the target a file resource, a path, or a transport enabled resource?
    # we need to know the difference and if a path do Ruby's IO,
    # if a File resource we need to see if the content is being managed,
    #   if so we need to bail with an error message
    #   if not we need to do IO on its path
    # if a transport enabled resource is used we need to see if it as valid content
    #   if not call #load (?),
    # we queue our changes with the Class for each target
    # we flush our changes after all provider instances have queued their changes
    # we call #commit on a transport enabled resource, otherwise we close the IO
    #
    # for us to do this we need to assume that we've gotten access to the content during
    # an Instance#fetch
    # This is because we want to check the file locally if it is a bare file path
    def prefetch_target target
      if target.is_a? String then
        return File.open(target).read
      elsif target.is_a? Puppet::Type then
        if target.provider.respond_to?(:commit) and
          target.provider.respond_to?(:fetch) then
          return target.fetch
        end
        ensure_ownership_of_content! target
        return File.open( target.to_hash[:path] ).read
      end
    end

    def ensure_ownership_of_content! target
      raise Puppet::Error,
        "Will not overwrite content supplied by #{target}" if
        target.to_hash[:content] or target.to_hash[:source]
    end

    # each provider registers itself here with the parent here during prefetch
    # the provider is set up and afterwards the during the flush call each
    # provider registers that it is finished
    # once all of the providers have registered they are finished with the
    # target is finally_flushed
    def register stage, provider, target
      target_name = target.to_s

      if stage == :instantiated then

        @@targets[target_name][:count] += 1
        Puppet.debug "Registered #{provider} to modify #{target_name}"

      elsif stage == :synced then
        @@targets[target_name][:count] -= 1
        Puppet.debug "Queued #{provider}'s changes to #{target_name}"

        if @@targets[target_name][:count] == 0 then
          finally_flush @@targets[target_name][:target]
        end

      else
        raise Puppet::Error, "Unknown stage, #{stage}, registered by #{provider}"
      end
    end

    # finally_flush batch edits the entire state of the registered providers
    def finally_flush target
      target.commit
    end

    def referenced_type(resource, ref)
      resource.catalog.resource(resource[ref].to_s)
    end
  end
end
