--[[

This plugin takes encrypted master key IDs and an optional KEK ID from the Fortanix DSM config file (fortanix-dsm.conf) in the encrypted directory 
and returns the break-glass value.

Example Input 
For config version 3
{
  "operation" : "recover_breakglass",
  "platform" : "linux/windows",
  "kek_id": "00000000-0000-0000-0000-000000000002",
  "encrypted_master_key_id" : "00000000-0000-0000-0000-000000000001"
}
For config version 4
{
  "operation" : "recover_breakglass",
  "platform" : "linux/windows",
  "encrypted_master_key_ids" : ["00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000002"]
}
]]--

function check(input)
  if input.operation == 'recover_breakglass' then 
    if input["encrypted_master_key_id"] and input["encrypted_master_key_ids"] then
      return nil, "Input field `encrypted_master_key_id` and `encrypted_master_key_ids` cannot be passed together."
    end

    if not input["encrypted_master_key_id"] and not input["encrypted_master_key_ids"] then
      return nil, "Missing required fields: one of `encrypted_master_key_id` or `encrypted_master_key_ids` is required."
    end

    if input["encrypted_master_key_id"] then 
      if not input["kek_id"] then
        return nil, "Missing required input field `kek_id` when `encrypted_master_key_id` is provided."
      end
    end

    if input["encrypted_master_key_ids"] then
      if input["kek_id"] then
        return nil, "Invalid input field: `kek_id` must not be set when `encrypted_master_key_ids` is provided."
      end
    end

    if not input['platform'] then 
      return nil, "missing required input field `platform`"
    end
  end
end

function is_valid_op(operation)
  local opr = {'recover_breakglass'}
  for i=1,#opr do
    if opr[i] == operation then
      return true
    end
  end
  return false
end

function is_valid_plat(platform)
  local plat = {'linux', 'windows'}
  for i=1,#plat do
    if plat[i] == platform then
      return true
    end
  end
  return false
end

function to_hex(str)
  return str:gsub('.', function(c)
    return string.format("%02x", c:byte())
  end)
end

function get_master_key(platform, encrypted_master_key_id, kek_id) 
   -- Verify Master Key and KEK exist
    local enc_master_key, err = Sobject { id = encrypted_master_key_id }
    if err ~= nil then
      return nil, Error.new("Specified Encrypted Master Key does not exist")
    end
    if kek_id == nil then
      -- If kek_id is absent, check `fsekekid` in the enc_master_key object's custom metadata.
      if enc_master_key.custom_metadata["fsekekid"] == nil then
        return {master_key = nil, err = "fsekekid metadata does not exist for the given encrypted master key"}
      end
      kek_id = enc_master_key.custom_metadata["fsekekid"]
    end
    local kek, err = Sobject { id = kek_id }
    if err ~= nil then
      return nil, Error.new("Specified Key Encryption Key does not exist")
    end
    -- Get the value of wrapped master key
    local encrypted_blob = Blob.from_base64(enc_master_key.value:base64()):bytes()
    -- Parse wrapped master key to get IV, Tag and Cipher Value in the same order
    local i = string.find(encrypted_blob, "%.")
    local j = string.find(encrypted_blob, "%.", i + 1)
    local iv, tag, cipher
    -- return {result = enc_master_key}
    if platform == "linux" then 
      iv = string.sub(encrypted_blob, 1, i-1)
      tag = string.sub(encrypted_blob, i+1, j-1)
      cipher = string.sub(encrypted_blob, j+1)
    else 
      cipher = Blob.from_base64(string.sub(encrypted_blob, 1, i-1)):bytes()
      iv = Blob.from_base64(string.sub(encrypted_blob, i+1, j-1)):bytes()
      tag = Blob.from_base64(string.sub(encrypted_blob, j+1)):bytes()
    end
    -- Unwrap the master key with KEK
    local master_key_blob = assert(kek:decrypt { cipher = cipher, 
                                iv = iv,
                                tag = tag,
                                mode = "GCM" }).plain
    if platform == "linux" then
      return { master_key = master_key_blob:hex(), master_key_state = enc_master_key.state }
    else 
      return { master_key = to_hex(master_key_blob:base64()), master_key_state = enc_master_key.state}
    end
end

function run(input)  
  if not is_valid_op(input.operation) then
    return {result = nil, error = "Operation is not valid. Operation value should be one of `recover_breakglass`."}
  end
  if not is_valid_plat(input.platform) then
    return {result = nil, error = "Platform is not valid. Operation value should be one of `linux`, `windows`."}
  end

  if input.operation == "recover_breakglass" then
    -- For config version 3
    if input["encrypted_master_key_id"] then  
      return { master_key = get_master_key(input.platform, input["encrypted_master_key_id"], input["kek_id"]).master_key }
    else 
    -- For config version 4
      local encrypted_master_key_ids = input["encrypted_master_key_ids"]
      local break_glass_keys = {}
      local active_master_keys = {}

      for i = 1, #encrypted_master_key_ids do
        local result = get_master_key(input.platform, encrypted_master_key_ids[i], nil)

        if result.master_key == nil then
          return { err = result.err }
        end
        local master_key_entry = {
          KeyId = encrypted_master_key_ids[i],
          Value = result.master_key
        }
        if result.master_key_state == "Active" then
          table.insert(active_master_keys, master_key_entry)
        else
          table.insert(break_glass_keys, master_key_entry)
        end
      end

      for i = 1, #active_master_keys do
        table.insert(break_glass_keys, active_master_keys[i])
      end

      return {
        BreakGlassKeys = {
          EncryptedMasterKeys = break_glass_keys
        }
      }
    end
  else
    return {result = '', error = "Operation is not valid. Operation value should be one of `recover_breakglass`"}
  end
end