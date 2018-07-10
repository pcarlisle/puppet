# Encrypts given data for the node requesting a catalog and returns a String that can be decrypted with decrypt()
#
# Encryption uses the X509 certificate for the requesting (recipient) node.
#
# It encrypts the given data into a result consisting of:
# * The cipher name (currently always 'AES-256-CBC')
# * A random cipher key - encrypted with the recipient's public key
# * The data encrypted using a cipher random key and a random initialization vector IV
# * The fingerprint of the certificate encrypted with the random key and same random IV (included to enable detection of
#   stale/wrong certificate when decrypting).
#
# All of the above is Base64 encoded and joined via `|` to form a single string
# that can be given to the `decrypt` function for decryption.
#
# The functions `encrypt()` and `decrypt()` can be used in both master and apply mode. When in master mode
# encryption is always for the node requesting a catalog and decryption is always for the local host (the master).
# Thus, `notice(decrypt(encrypt("the moon is made of cheeze")).unwrap)` will work in apply mode, but will error on the master.
#
# @example Encrypting a String
#   encrypt("Area 51 - the aliens are alive")
#
# @example Encrypting a Hash
#   encrypt('pin_code' => 1234, 'account' => 'IBAN XEB 0123456789')
#
# @example Encrypting a Sensitive value
#   encrypt(Sensitive("my password is secret"))
#
# Typically the result of encryption is for a node and the target resource where the encrypted value is used as the
# value of an attribute is not prepared to handle the decryption. To be able to send the encrypted value and
# to give the resource a Sensitive decrypted value a `Deferred` value is used.
#
# @example Using a Deferred value to decrypt on node
#   class mymodule::myclass(Sensitive $password) {
#     mymodule::myresource { 'example':
#       password => Deferred('decrypt', encrypt($password))
#     }
#   }
#
# See `decrypt()` for details about decryption.
#
# @Since 5.5.x - TBD
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
