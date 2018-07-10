# Decrypts given crypto string (as produced by encrypt()) for the local host and returns a `Sensitive` value with the decrypted value
#
# @example Encrypt and decrypt in apply mode
#   $encrypted = encrypt("Area 51 - the aliens are alive and well")
#   $clear = decrypt($encrypted).unwrap
#
# Typically the result of encryption is for a node and the target resource where the encrypted value is used as the
# value of an attribute is not prepared to handle the decryption. To be able to send the encrypted value and
# to give the resource a Sensitive decrypted value a `Deferred` value is used.
#
# @example Using a Deferred value to decrypt on node - with Sensitive input
#   class mymodule::myclass(Sensitive $password) {
#     mymodule::myresource { 'example':
#       password => Deferred('decrypt', encrypt($password))
#     }
#   }
#
#
# @example Using a Deferred value to decrypt on node - with input being clear text
#   class mymodule::myclass(String $password) {
#     mymodule::myresource { 'example':
#       password => Deferred('decrypt', encrypt($password))
#     }
#   }
#
# In both of the example above, the resulting value assigned to the `password` is marked as `Sensitive`
#
# See `encrypt()` for details about encryption.
#
# @Since 5.5.x - TBD
#
Puppet::Functions.create_function(:decrypt) do
  require 'openssl'

  dispatch :decrypt do
    param 'String', :string_data
  end

  def decrypt(string_data)
    localhost = Puppet::SSL::Host.localhost
    key = localhost.key.content

    cipher, encrypted_key, crypt, encrypted_fingerprint = string_data.split("|").map{|a| Base64.decode64(a) }
    aes_key = key.private_decrypt(encrypted_key)

    aes_decrypt = OpenSSL::Cipher.new(cipher).decrypt
    aes_decrypt.key = aes_key
    data = aes_decrypt.update(crypt) << aes_decrypt.final
    data = data[16..-1]

    aes_decrypt.reset
    fingerprint = aes_decrypt.update(encrypted_fingerprint) << aes_decrypt.final
    fingerprint = fingerprint[16..-1]

    unless fingerprint == localhost.certificate.fingerprint
      raise ArgumentError.new(_("Decryption failed, not encrypted for current certificate of this node"))
    end

    clear = deserialize(data)
    sensitive = Puppet::Pops::Types::PSensitiveType::Sensitive
    clear.is_a?(sensitive) ? clear : sensitive.new(clear)
  end

  def deserialize(data)
    io = StringIO.new(data)
    reader = Puppet::Pops::Serialization::JSON::Reader.new(io)
    loader = closure_scope.compiler.loaders.find_loader(nil)
    deserializer = Puppet::Pops::Serialization::Deserializer.new(reader, loader)
    deserializer.read()
  end

end
