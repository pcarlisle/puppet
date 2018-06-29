# Decrypts given crypto string (as produced by encrypt()) for the local host.
#
# @example Encrypt and decrypt
#   $encrypted = encrypt("Area 51 - the aliens are alive and well")
#   $clear = decrypt($encrypted)
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

    deserialize(data)
  end

  def deserialize(data)
    io = StringIO.new(data)
    reader = Puppet::Pops::Serialization::JSON::Reader.new(io)
    loader = closure_scope.compiler.loaders.find_loader(nil)
    deserializer = Puppet::Pops::Serialization::Deserializer.new(reader, loader)
    deserializer.read()
  end

end
