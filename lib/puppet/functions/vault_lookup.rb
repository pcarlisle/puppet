Puppet::Functions.create_function(:vault_lookup) do
  require 'vault'

  dispatch :vault_lookup do
    param 'String', :path
  end

  def vault_lookup(path)
    Puppet.err("HELLO")
    secret = Vault.logical.read(path)
    Puppet::Pops::Types::PSensitiveType::Sensitive.new(secret.data)
  end
end
