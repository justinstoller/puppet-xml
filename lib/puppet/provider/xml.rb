class Puppet::Provider::XML < Puppet::Provider
  @@targets = []

  # each provider registers itself here with the parent here during prefetch
  # the provider is set up and afterwards the during the flush call each
  # provider registers that it is finished
  # once all of the providers have registered they are finished with the
  # target is finally_flushed
  def register(stage, resource, target)
    if stage == :instantiated then
      @@targets[target] ||= {}
      @@targets[target][:resources] ||= []
      @@targets[target][:resources] << resource
      @@targets[target][:count] += 1
    elsif stage == :synced
      @@targets[target][:count] -= 1
      if @@targets[target][:count] == 0
        finally_flush @@targets[target][:resources]
      end
    end
  end

  # finally_flush causes batch edits the entire state of the registered providers
  def finally_flush
  end
end
