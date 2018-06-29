# Encrypts given data for the node requesting a catalog and returns a String that can be decrypted with decrypt()
#
# Encryption uses
# * the X509 certificate for the requesting node.
# * A random AES256-CBC key - encrypted for the node
# * The data encrypted using the AES random key
# * The fingerprint of the cert
#
Puppet::Functions.create_function(:encrypt) do
  require 'openssl'

  dispatch :encrypt do
    param 'RichData', :data
  end

  def encrypt(data)
    # Get the certificate for the request
    trusted = Puppet.lookup(:trusted_information) { nil }
    if trusted.nil?
      certificate = Puppet::SSL::Host.localhost.certificate
    else
      certificate = trusted.certificate
    end

    if certificate.nil?
      # TRANSLATORS - "trusted_information" is an internal key, do not translate
      raise ArgumentError, _("encrypt() Cannot find required trusted_information with certificate for target node.")
    end

    key = certificate.content.public_key
    fingerprint = certificate.fingerprint

    # encrypt with it and get encrypted random key back and the data encrypted
    encrypt_using_key(key, fingerprint, serialize(data))
  end

  def encrypt_using_key(key, fingerprint, data)
    aes_encrypt = OpenSSL::Cipher.new('AES-256-CBC').encrypt

    # Use a random key
    aes_encrypt.key = aes_key = aes_encrypt.random_key

    # Use a random initialization vector (safer) - these 16 bytes are prepended to the clear text
    # and dropped after decryption.
    #
    iv = aes_encrypt.random_iv

    # Encrypt the data with this key
    crypt = aes_encrypt.update(iv + data) << aes_encrypt.final
    # Encrypt the random key with the public key
    encrypted_key = rsa_key(key).public_encrypt(aes_key)

    # Encrypt the fingerprint with public key
    # encrypted_fingerprint = rsa_key(key).public_encrypt(fingerprint)
    aes_encrypt.reset
    encrypted_fingerprint = aes_encrypt.update(iv + fingerprint) << aes_encrypt.final

    # Concatenate into base 64 string where encrypted key and encrypted data is separate by base 64 safe key '|'
    [Base64.encode64('AES-256-CBC'), Base64.encode64(encrypted_key), Base64.encode64(crypt), Base64.encode64(encrypted_fingerprint)].join("|")
  end

  def rsa_key(key)
    OpenSSL::PKey::RSA.new(key)
  end

  def serialize(data)
    io = StringIO.new
    writer = Puppet::Pops::Serialization::JSON::Writer.new(io)
    serializer = Puppet::Pops::Serialization::Serializer.new(writer)
    serializer.write(data)
    serializer.finish
    io.string
  end
end
