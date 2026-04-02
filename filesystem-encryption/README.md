# FORTANIX DSM FILESYSTEM ENCRYPTION PLUGIN

## Introduction

Fortanix Data Security Manager (DSM) delivers a secure, efficient Filesystem Encryption (FSE) solution. It ensures seamless application performance while centrally managing keys, policies, quorum security, and audit logging for strong data protection. 

## Use cases

The plugin can be used to retrieve the break-glass key for accessing filesystems.

## Input/Output JSON object format

### Recover Breakglass operation

This operation retrieves the break-glass value using the encrypted master key ID(s) and an optional Key Encryption Key (KEK) ID available in the Fortanix DSM config file (fortanix-dsm.conf) in the encrypted directory.

* `operation`: The operation to perform. A valid value is `recover_breakglass`.
* `platform`: The operating system where FSE is running. Valid values are `linux` or `windows`.
* `encrypted_master_key_id`: Encrypted Master Key ID (used in config version 3).
* `encrypted_master_key_ids`: List of Encrypted Master Key IDs (used in config version 4).
* `kek_id`: Key Encryption Key (KEK) ID (used only in config version 3).

#### Example

### Config Version 3
Input JSON
```
{
  "operation" : "recover_breakglass",
  "platform" : "linux/windows"
  "kek_id" : "00000000-0000-0000-0000-000000000002",
  "encrypted_master_key_id": "00000000-0000-0000-0000-000000000001"
}
```

Output JSON
```
{
  "master_key": "<hex value of 32-byte master key>"
}
```

### Config Version 4
Input JSON
```
{
  "operation" : "recover_breakglass",
  "platform" : "linux/windows"
  "encrypted_master_key_ids": ["00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000002"]
}
```

Output JSON
```
{
  "BreakGlassKeys": {
    "EncryptedMasterKeys": [
      {
        "KeyId": "00000000-0000-0000-0000-000000000001",
        "Value": "<hex value of 32-byte master key>"
      }
      {
        "KeyId": "00000000-0000-0000-0000-000000000002",
        "Value": "<hex value of 32-byte master key>"
      }
    ]
  }
}
```

## References
* [Filesystem Encryption for Linux Using Fortanix Data Security Manager](https://support.fortanix.com/docs/filesystem-encryption-for-linux)
* [Filesystem Encryption for Windows as a Service Using Fortanix Data Security Manager](https://support.fortanix.com/docs/filesystem-encryption-for-windows-using-fortanix-data-security-manager-setup-and-usage)

## Release Notes
 - Initial release
