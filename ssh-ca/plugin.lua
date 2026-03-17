
function getCaKeyType()
   --- FIXME type of signature key is hardcoded
   return "ssh-rsa"
end

--- utility function uuid ---
--- it will return an uuid ---
local function uuid()
   local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
   return string.gsub(template, '[xy]', function (c)
                         local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
                         return string.format('%x', v)
   end)
end

function parse_ssh_pubkey(pkey_b64)
   local data = Blob.from_base64(pkey_b64):bytes()

   local pos = 1
   key_type, pos = string.unpack(">s4", data, pos)

   if key_type == "ssh-rsa"
   then
      exp, pos = string.unpack(">s4", data, pos)
      modulus, pos = string.unpack(">s4", data, pos)
      if pos ~= (#data) + 1
      then
         return nil, "invalid ssh-rsa key"
      end
      return key_type, modulus, exp
   else
      return nil, "unknown key type"
   end
end


--- key type ---
--- TODO need to support DSA, ECDSA, Ed25519
function getCertKeyType(key_type)
   if key_type == "ssh-rsa" then
      return 'ssh-rsa-cert-v01@openssh.com'
   end
   error('Only RSA keys are currently supported, no support for ' .. key_type)
end

---certificate type ---
--- 1. user ---
--- 2. host ---
function getCertType(req)
   if req.cert_type == 'user' then
      return 1
   end
   if req.cert_type == 'host' then
      return 2
   end
end

--- valid-principals ---
--- user-name for user ---
--- host-name for host ---
function getValidPrincipal(req)
   return string.pack(">s4", req.valid_principals)
end

--- format an integer in ssh format ---
function formatMPI(n)
   local n_bytes = n:to_bytes_be()
   local first_byte = n_bytes:slice(0,1):bytes()
   if (string.byte(first_byte) & 0x80) ~= 0
   then
      zp = Blob.from_hex("00") .. n_bytes
      return string.pack(">s4", zp:bytes())
   end
   return string.pack(">s4", n_bytes:bytes())
end

--- ca public key ---
function getSignaturePublicKey(ca_key)
   local ca_key = assert(Sobject { name = ca_key })
   local key_info = ca_key:rsa_public_info()
   return string.pack(">s4", "ssh-rsa") .. formatMPI(key_info.public_exponent) .. formatMPI(key_info.public_modulus)
end

function formatExtensions(extensions)
   local s = ''

   -- Extensions must be sorted by key
   local tkeys = {}
   for k in pairs(extensions) do
      table.insert(tkeys, k)
   end
   table.sort(tkeys)
   for _, k in ipairs(tkeys) do
      s = s .. string.pack('>s4', k)
      local value = extensions[k]
      if value == '' then
         s = s .. string.pack('>s4', '')
      else
         s = s .. string.pack('>s4', string.pack('>s4', value))
      end
   end
   return s
end

--- serialized req and ca components ---
function createCertData(req)
   key_type, modulus, exp = parse_ssh_pubkey(req.pubkey)

   local now = Time.now_insecure()

   local ca_pubkey = getSignaturePublicKey(req.ca_key)

   local cert_type = getCertKeyType(key_type)
   local nonce = Blob.random(12):base64()
   local created = now:unix_epoch_seconds()
   local expires = created + req.cert_lifetime
   local random_key_id = uuid()
   local critical_options = formatExtensions(req.critical_extensions)
   local extensions = formatExtensions(req.extensions)
   local reserved = ''
   local serial = now:unix_epoch_nanoseconds()

   rsa_cert_serialization = string.pack(">s4>s4>s4>s4>I8>I4>s4>s4>I8>I8>s4>s4>s4>s4",
                                        cert_type, nonce, exp, modulus,
                                        serial, getCertType(req), random_key_id, getValidPrincipal(req),
                                        created, expires,
                                        critical_options, extensions, reserved, ca_pubkey)
   return cert_type, rsa_cert_serialization
end

--- sign the give key ---
function signCertificate(ca_key, serialized_input)
   local ca_key = assert(Sobject { name = ca_key })
   local blob = Blob.from_bytes(serialized_input)
   local res, err = ca_key:sign {
      hash_alg = 'SHA1',
      data = blob,
   }
   assert(res, "Error performing signing : " .. tostring(err))
   return res
end

--- validate the input components ---
function check(req)
   if type(req) ~= 'table' then
      return nil, 'invalid req'
   end
   if not req.pubkey then
      return nil, 'must provide public key'
   end
   if not req.valid_principals then
      return nil, 'valid principals must be specified'
   end
   if req.cert_type ~= 'user' and req.cert_type ~= 'host' then
      return nil, 'invalid cert type'
   end
   if type(req.ca_key) ~= 'string' then
      return nil, 'must specify name of CA key'
   end
end

function run(req)
   cert_type, cert_data = createCertData(req)
   signature = signCertificate(req.ca_key, cert_data).signature
   signature_hdr = string.pack(">s4>I4", getCaKeyType(req), #signature:bytes())
   signature_w_hdr = Blob.from_bytes(string.pack(">I4", #signature_hdr + #signature:bytes())) .. Blob.from_bytes(signature_hdr) .. signature
   cert = Blob.from_bytes(cert_data) .. signature_w_hdr
   return cert_type .. " " .. cert:base64() .. " " .. req.valid_principals
end
