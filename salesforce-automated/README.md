# Automated BYOK for Salesforce Cloud

## Use cases

The plugin can be used to

- Upload a key from Fortanix Data Security Manager (DSM) to Salesforce Shield Platform Encryption
- Search tenant secrets (Salesforce encryption keys) using Salesforce Sobject Query Language (SSQL)
- Check current status of any key or key version
- Destroy the archived keys in Salesforce
- Restore a previously destroyed key
- Rotate a previously uploaded key

## Initial setup and configuration

### Fortanix DSM Setup

1. Log in to Fortanix DSM (https://smartkey.io)
2. Create an account in Fortanix DSM
3. Create a group in Fortanix DSM
4. Create a plugin in Fortanix DSM

### Configure Salesforce

1. Create a New Profile under Setup >> Profiles
    Note: Select “Manage Encryption Keys” under “Administrative Permissions"
2. Create a New User under Setup >> Users with these inputs –
    Name: arbitrarily input
    Profiles: choose the KMS role created in previous step
3. Create an External Client App under “Apps >> External Client Apps >> External Client App Manager” with the following inputs –
    Label: arbitrarily input
    Check the “Enable OAuth Settings”
    Check the “Enable Device Flow” for automated access
    Callback URL is the Salesforce Tenant, e.g. https://my_tenant.my.salesforce.com/
    Set OAuth Scope “Manage user data via APIs (api)” for BYOK access
    Check the “Enable Client Credentials Flow” for automated login
4. Update created External Client App
    Check the “Enable Client Credentials Flow” for automated login
    Set Run As to the user created in step 2.
    Whitelist the Fortanix DSM application IP range (CIDR)
    Note the credentials to securely import into DSM secret
5. Create a Certificate under “Setup >> Certificate and Key Management” –
    Label: arbitrarily input, but note it for later use
    Uncheck the “Exportable Private Key”
    Check the option to "Use Platform Encryption"
6. Verify the Salesforce credentials
    Client/Consumer Key  (Created in step 3)
    Client/Consumer Secret (Created in step 3)
    Tenant URI
    API version (Fortanix Plugin tested against version 50.0)

## Input/Output JSON object format

### Configure operation

This operation configures Salesforce credentials in Fortanix DSM and returns a UUID. You need to pass this UUID for other operations. This is a one time process.

### parameters

* `operation`: The operation which you want to perform. A valid value is `configure`
* `consumer_key`: Consumer Key of the connected app
* `consumer_secret`: Consumer Secret of the connected app
* `tenant`: Salesforce tenant URI
* `version`: API version (Fortanix Plugin tested against version 50.0)
* `name`: Name of the sobject. This sobject will be created in Fortanix DSM and will have Salesforce credential information

#### Example

Input JSON
```
{
  "operation": "configure",
  "consumer_key": "CBK...................D",
  "consumer_secret": "DMV................D",
  "tenant"   : "<Salesforce tenant URI>",
  "version"  : "v50.0",
  "name"    : "Salesforce NamedCred Dev"
}
```
Output
```
"3968218b-72c3-4ada-922a-8a917323f27d"
```


### Check operation

This operation is to test whether plugin can import wrapping certificate from Salesforce into Fortanix DSM. (This certificate is required by plugin to authenticate itself to Salesforce)

### parameters

* `operation`: The operation which you want to perform. A valid value is `check`
* `secret_id`: The response of `configuration` operation
* `wrapper`: Name of the wrapping certificate in Salesforce

#### Example

Input JSON
```
{
  "operation": "check",
  "secret_id": "3968218b-72c3-4ada-922a-8a917323f27d",
  "wrapper"  : "SFBYOK_FTX_Wrapper"
}
```
Output JSON
```
{
  "group_id": "ff2............................c",
  "public_only": true,
  "key_ops": [
    "VERIFY",
    "ENCRYPT",
    "WRAPKEY",
    "EXPORT"
  ],
  "enabled": true,
  "rsa": {
    "signature_policy": [
      {
        "padding": null
      }
    ],
    "encryption_policy": [
      {
        "padding": {
          "OAEP": {
            "mgf": null
          }
        }
      }
    ],
    "key_size": 4096
  },
  "state": "Active",
  "created_at": "20201229T183553Z",
  "key_size": 4096,
  "kid": "6de........................4",
  "origin": "External",
  "lastused_at": "19700101T000000Z",
  "obj_type": "CERTIFICATE",
  "name": "SFBYOK_FTX_Wrapper",
  "acct_id": "ec9.......................7",
  "compliant_with_policies": true,
  "creator": {
    "plugin": "654.......................1"
  },
  "value": "MII........................9",
  "activation_date": "20201229T183553Z",
  "pub_key": "MII......................8",
  "never_exportable": false
}
```


### Query operation

This operation allows you to search tenant secrets (Salesforce encryption keys) using Salesforce Sobject Query Language (SSQL)

### parameters

* `operation`: The operation which you want to perform. A valid value is `query` or `search`
* `secret_id`: The response of `configuration` operation
* `query`: SSQL query
* `tooling`:

#### Example

Input JSON
```
{
  "operation": "search",
  "secret_id": "3968218b-72c3-4ada-922a-8a917323f27d",
  "query"   : "select Id, Status, Version from TenantSecret where Type = `Data`",
  "tooling"  : false
}
```
Output JSON
```
{
  "done": true,
  "totalSize": 5,
  "records": [
    {
      "attributes": {
        "type": "TenantSecret",
        "url": "/services/data/v50.0/sobjects/TenantSecret/02G..........O"
      },
      "Status": "ARCHIVED",
      "Id": "02G.............D",
      "Version": 3
    },
    {
      "Version": 1,
      "attributes": {
        "url": "/services/data/v50.0/sobjects/TenantSecret/02G...........W",
        "type": "TenantSecret"
      },
      "Id": "02G...........W",
      "Status": "ARCHIVED"
    },
    {
      "Version": 2,
      "Id": "02G..........O",
      "attributes": {
        "type": "TenantSecret",
        "url": "/services/data/v50.0/sobjects/TenantSecret/02G............O"
      },
      "Status": "ARCHIVED"
    },
    {
      "Id": "02G...........4",
      "attributes": {
        "url": "/services/data/v50.0/sobjects/TenantSecret/02G...........4",
        "type": "TenantSecret"
      },
      "Version": 4,
      "Status": "DESTROYED"
    },
    {
      "attributes": {
        "type": "TenantSecret",
        "url": "/services/data/v50.0/sobjects/TenantSecret/02G............O"
      },
      "Id": "02G..........O",
      "Version": 5,
      "Status": "ACTIVE"
    }
  ]
}
```

### Upload operation

This operation allows you to create a key material in Fortanix DSM and upload to Salesforce

### parameters

* `operation`: The operation which you want to perform. A valid value is `upload`
* `secret_id`: The response of `configuration` operation
* `wrapper`: Name of the wrapping certificate in Salesforce
* `type`: A valid values are `Data|EventBus|SearchIndex|DeterministicData`
* `mode`: Key derivation mode. It can be blank which defaults to “PBKDF2” or can also be "NONE" to disable key derivation in Salesforce
* `name`: Prefix of the name

Note: CRM Analytics type tenant secret has not been tested. It may require additional licensing and configuration in Salesforce
beyond Shield Platform Encryption.

#### Example

Input JSON
```
{
  "operation": "upload",
  "secret_id": "3968218b-72c3-4ada-922a-8a917323f27d",
  "wrapper"  : "SFBYOK_FTX_Wrapper",
  "type"     : "Data",
  "mode"     :  "",
  "name"     : "Salesforce Data Key"
}

```
Output JSON
```
{
  "obj_type": "AES",
  "custom_metadata": {
    "SF_HASH": "ESP.......................=",
    "SF_UPLOAD": "EDF.....................=",
    "SF_WRAPPER": "SFBYOK_FTX_Wrapper",
    "SF_MODE": "",
    "SF_KID": "02G...........O",
    "SF_TYPE": "Data"
  },
  "acct_id": "ec9...................7",
  "creator": {
    "plugin": "654....................1"
  },
  "public_only": false,
  "origin": "Transient",
  "kid": "bb7................3",
  "lastused_at": "19700101T000000Z",
  "activation_date": "20201229T185549Z",
  "key_size": 256,
  "kcv": "b5...9",
  "name": "Salesforce Data Key",
  "state": "Active",
  "enabled": true,
  "key_ops": [
    "EXPORT"
  ],
  "compliant_with_policies": true,
  "created_at": "20201229T185549Z",
  "aes": {
    "tag_length": null,
    "key_sizes": null,
    "random_iv": null,
    "fpe": null,
    "iv_length": null,
    "cipher_mode": null
  },
  "never_exportable": false,
  "group_id": "ff2..............b"
}
```

### Status operation

This operation allows you to obtain current status of a Salesforce key

### parameters

* `operation`: The operation which you want to perform. A valid value is `status`
* `secret_id`: The response of `configuration` operation
* `wrapper`: Name of the wrapping certificate in Salesforce
* `name`: "name of corresponding sobject in Fortanix DSM"

#### Example

Input JSON
```
{
      "operation" : "status",
      "secret_id": "3968218b-72c3-4ada-922a-8a917323f27d",
      "wrapper"   : "SFBYOK_FTX_Wrapper",
      "name"      : "Salesforce Data Key"
}
```
Output JSON
```
{
  "RemoteKeyIdentifier": null,
  "CreatedDate": "2020-12-29T18:55:49.000+0000",
  "SecretValueHash": "ESP........................=",
  "CreatedById": "005..........2",
  "KeyDerivationMode": "PBKDF2",
  "attributes": {
    "url": "/services/data/v50.0/sobjects/TenantSecret/02G..........O",
    "type": "TenantSecret"
  },
  "LastModifiedDate": "2020-12-29T18:55:49.000+0000",
  "IsDeleted": false,
  "SecretValue": "CgM.............................=",
  "SecretValueCertificate": null,
  "Type": "Data",
  "RemoteKeyServiceId": null,
  "Version": 6,
  "Id": "02G..........O",
  "Status": "ACTIVE",
  "SystemModstamp": "2020-12-29T18:55:49.000+0000",
  "RemoteKeyCertificate": null,
  "Source": "UPLOADED",
  "Description": "Salesforce Data Key",
  "LastModifiedById": "005............2"
}
```
### Sync operation

This operation allows you to sync Fortanix DSM key object with Salesforce key.

### parameters

* `operation`: The operation which you want to perform. A valid value is `sync`
* `secret_id`: The response of `configuration` operation
* `wrapper`: Name of the wrapping certificate in Salesforce
* `name`: "name of corresponding sobject in Fortanix DSM"

#### Example

Input JSON
```
{
      "operation" : "sync",
      "secret_id": "3968218b-72c3-4ada-922a-8a917323f27d",
      "wrapper"   : "SFBYOK_FTX_Wrapper",
      "name"      : "Salesforce Data Key"
}
```
Output JSON
```
{
  "RemoteKeyCertificate": null,
  "IsDeleted": false,
  "CreatedById": "005..............2",
  "Status": "ACTIVE",
  "Type": "Data",
  "LastModifiedById": "005............2",
  "CreatedDate": "2020-12-29T18:55:49.000+0000",
  "SystemModstamp": "2020-12-29T18:55:49.000+0000",
  "Source": "UPLOADED",
  "SecretValueHash": "ESP.................c",
  "LastModifiedDate": "2020-12-29T18:55:49.000+0000",
  "Version": 6,
  "RemoteKeyServiceId": null,
  "RemoteKeyIdentifier": null,
  "attributes": {
    "type": "TenantSecret",
    "url": "/services/data/v50.0/sobjects/TenantSecret/02G............O"
  },
  "KeyDerivationMode": "PBKDF2",
  "Id": "02G...........O",
  "SecretValueCertificate": null,
  "Description": "Salesforce Data Key",
  "SecretValue": "CgM........................M"
}
```
### Destroy operation

This operation allows you to destroy an archived Salesforce key.

### parameters

* `operation`: The operation which you want to perform. A valid value is `destroy`
* `secret_id`: The response of `configuration` operation
* `wrapper`: Name of the wrapping certificate in Salesforce
* `name`: "name of corresponding sobject in Fortanix DSM"

#### Example

Input JSON
```
{
      "operation" : "destroy",
      "secret_id": "3968218b-72c3-4ada-922a-8a917323f27d",
      "wrapper"   : "SFBYOK_FTX_Wrapper",
      "name"      : "Salesforce Data Key"
}
```
Output
```
output is empty, with http status indicating success.
```
### Restore operation

This operation allows you to restore a destroyed Salesforce key.

### parameters

* `operation`: The operation which you want to perform. A valid value is `restore`
* `secret_id`: The response of `configuration` operation
* `wrapper`: Name of the wrapping certificate in Salesforce
* `name`: "name of corresponding sobject in Fortanix DSM"

#### Example

Input JSON
```
{
      "operation" : "restore",
      "secret_id": "3968218b-72c3-4ada-922a-8a917323f27d",
      "wrapper"   : "SFBYOK_FTX_Wrapper",
      "name"      : "Salesforce Data Key"
}
```
Output
```
output is empty, with http status indicating success.
```

### Rotate operation

This operation allows you to rotate the key material in Fortanix DSM and upload to Salesforce

### parameters

* `operation`: The operation which you want to perform. A valid value is `rotate`
* `secret_id`: The response of `configuration` operation
* `wrapper`: Name of the wrapping certificate in Salesforce
* `type`: A valid values are `Data|EventBus|SearchIndex`
* `mode`: Key derivation mode. It can be blank which defaults to “PBKDF2” or can also be "NONE" to disable key derivation in Salesforce
* `name`: Name of the DSM key that was previously specified in the `upload` operation

#### Example

Input JSON
```
{
  "operation": "rotate",
  "secret_id": "3968218b-72c3-4ada-922a-8a917323f27d",
  "wrapper"  : "SFBYOK_FTX_Wrapper",
  "type"     : "Data",
  "mode"     :  "",
  "name"     : "Salesforce Data Key"
}

```
Output JSON
```
{
  "obj_type": "AES",
  "custom_metadata": {
    "SF_HASH": "ESP.......................=",
    "SF_UPLOAD": "EDF.....................=",
    "SF_WRAPPER": "SFBYOK_FTX_Wrapper",
    "SF_MODE": "",
    "SF_KID": "02G...........O",
    "SF_TYPE": "Data"
  },
  "acct_id": "ec9...................7",
  "creator": {
    "plugin": "654....................1"
  },
  "public_only": false,
  "origin": "Transient",
  "kid": "bb7................3",
  "lastused_at": "19700101T000000Z",
  "activation_date": "20201229T185549Z",
  "key_size": 256,
  "kcv": "b5...9",
  "name": "Salesforce Data Key",
  "state": "Active",
  "enabled": true,
  "key_ops": [
    "EXPORT"
  ],
  "compliant_with_policies": true,
  "created_at": "20201229T185549Z",
  "aes": {
    "tag_length": null,
    "key_sizes": null,
    "random_iv": null,
    "fpe": null,
    "iv_length": null,
    "cipher_mode": null
  },
  "never_exportable": false,
  "group_id": "ff2..............b"
}
```

## References

- [Salesforce Shield Platform Encryption Concepts](https://help.salesforce.com/s/articleView?id=sf.security_pe_concepts.htm)
- [Salesforce Shield Platform Encryption Overview](https://help.salesforce.com/s/articleView?id=sf.security_pe_overview.htm)
- [Salesforce Shield Platform Encryption for CRM Analytics](https://help.salesforce.com/s/articleView?id=sf.security_pe_analytics_enable.htm)
- [Salesforce Shield Platform Encryption Implemenation Guide](https://resources.docs.salesforce.com/latest/latest/en-us/sfdc/pdf/salesforce_platform_encryption_implementation_guide.pdf)
- [Salesforce REST API guide](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_list.htm)
- [Salesforce REST APIs available](https://help.salesforce.com/s/articleView?id=sf.integrate_what_is_api.htm)

## Release Notes
 Initial release
 Key rotation and documentation update
