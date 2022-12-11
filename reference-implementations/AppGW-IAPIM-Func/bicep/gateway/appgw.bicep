/*
 * Input parameters
*/
@description('The name of the Application Gateawy to be created.')
param appGatewayName string

@description('The FQDN of the Application Gateawy.Must match the TLS Certificate.')
param appGatewayFQDN string = 'api.example.com'

@description('The location of the Application Gateawy to be created')
param location string = resourceGroup().location

@description('The subnet resource id to use for Application Gateway.')
param appGatewaySubnetId string

@description('Set to selfsigned if self signed certificates should be used for the Application Gateway. Set to custom and copy the pfx file to deployment/bicep/gateway/certs/appgw.pfx if custom certificates are to be used')
param appGatewayCertType string

@description('The backend URL of the APIM.')
param primaryBackendEndFQDN string = 'api-internal.example.com'

@description('The Url for the Application Gateway Health Probe.')
param probeUrl string = '/status-0123456789abcdef'

param keyVaultName string
param keyVaultResourceGroupName string

@secure()
param certPassword string

@description('The FQDN of the Api.Must match the TLS Certificate.')
param apiFQDN string
@description('Set to selfsigned if self signed certificates should be used for the Api. Set to custom and copy the pfx file to deployment/bicep/gateway/certs/api.pfx if custom certificates are to be used')
param apiCertType string
@secure()
param apiCertPassword string

@description('The FQDN of the Portal.Must match the TLS Certificate.')
param portalFQDN string
@description('Set to selfsigned if self signed certificates should be used for the Portal. Set to custom and copy the pfx file to deployment/bicep/gateway/certs/portal.pfx if custom certificates are to be used')
param portalCertType string
@secure()
param portalCertPassword string

@description('The FQDN of the Management.Must match the TLS Certificate.')
param managementFQDN string
@description('Set to selfsigned if self signed certificates should be used for the Management. Set to custom and copy the pfx file to deployment/bicep/gateway/certs/management.pfx if custom certificates are to be used')
param managementCertType string
@secure()
param managementCertPassword string

var appGatewayPrimaryPip = 'pip-${appGatewayName}'
var appGatewayIdentityId = 'identity-${appGatewayName}'

resource appGatewayIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: appGatewayIdentityId
  location: location
}

module certificate './modules/certificate.bicep' = {
  name: 'certificate'
  scope: resourceGroup(keyVaultResourceGroupName)
  params: {
    managedIdentity: appGatewayIdentity
    keyVaultName: keyVaultName
    location: location
    appGatewayFQDN: appGatewayFQDN
    appGatewayCertType: appGatewayCertType
    certPassword: certPassword
  }
}
module certificateApi './modules/certificateApi.bicep' = {
  name: 'certificateApi'
  scope: resourceGroup(keyVaultResourceGroupName)
  params: {
    managedIdentity: appGatewayIdentity
    keyVaultName: keyVaultName
    location: location
    appGatewayFQDN: apiFQDN
    appGatewayCertType: apiCertType
    certPassword: apiCertPassword
  }
}
module certificatePortal './modules/certificatePortal.bicep' = {
  name: 'certificatePortal'
  scope: resourceGroup(keyVaultResourceGroupName)
  params: {
    managedIdentity: appGatewayIdentity
    keyVaultName: keyVaultName
    location: location
    appGatewayFQDN: portalFQDN
    appGatewayCertType: portalCertType
    certPassword: portalCertPassword
  }
}
module certificateManagement './modules/certificateManagement.bicep' = {
  name: 'certificateManagement'
  scope: resourceGroup(keyVaultResourceGroupName)
  params: {
    managedIdentity: appGatewayIdentity
    keyVaultName: keyVaultName
    location: location
    appGatewayFQDN: managementFQDN
    appGatewayCertType: managementCertType
    certPassword: managementCertPassword
  }
}

resource appGatewayPublicIPAddress 'Microsoft.Network/publicIPAddresses@2019-09-01' = {
  name: appGatewayPrimaryPip
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource appGatewayName_resource 'Microsoft.Network/applicationGateways@2019-09-01' = {
  name: appGatewayName
  location: location
  dependsOn: [
    certificate
  ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appGatewayIdentity.id}': {}
    }
  }
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: appGatewaySubnetId
          }
        }
      }
    ]
    sslCertificates: [
      {
        name: appGatewayFQDN
        properties: {
          keyVaultSecretId: certificate.outputs.secretUri
        }
      }
      {
        name: apiFQDN
        properties: {
          keyVaultSecretId: certificateApi.outputs.secretUri
        }
      }
      {
        name: portalFQDN
        properties: {
          keyVaultSecretId: certificatePortal.outputs.secretUri
        }
      }
      {
        name: managementFQDN
        properties: {
          keyVaultSecretId: certificateManagement.outputs.secretUri
        }
      }
    ]
    sslPolicy: {
      minProtocolVersion: 'TLSv1_2'
      policyType: 'Custom'
      cipherSuites: [
        'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256'
        'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384'
        'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256'
        'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'
        'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256'
        'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384'
        'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256'
        'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384'
      ]
    }
    trustedRootCertificates: [
      {
        //id: 'not needed yet'
        name: 'whitelistcert1'
        properties: {
          data: 'MIIFwzCCA6ugAwIBAgIUazgjPfp9lrBDIX6b27tO02r1dzYwDQYJKoZIhvcNAQELBQAwcTELMAkGA1UEBhMCQ0ExDzANBgNVBAgMBlF1ZWJlYzERMA8GA1UEBwwITW9udHJlYWwxEDAOBgNVBAoMB0NvbnRvc28xLDAqBgNVBAMMI3Jvb3RjYS5NbmdFbnYwMTk3MDIub25taWNyb3NvZnQuY29tMB4XDTIyMTIwMTAxMDMzMloXDTMyMTEyODAxMDMzMlowcTELMAkGA1UEBhMCQ0ExDzANBgNVBAgMBlF1ZWJlYzERMA8GA1UEBwwITW9udHJlYWwxEDAOBgNVBAoMB0NvbnRvc28xLDAqBgNVBAMMI3Jvb3RjYS5NbmdFbnYwMTk3MDIub25taWNyb3NvZnQuY29tMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA4f/Y2q5Jou15TOUjHvHV6hNSu3H0pFFhtOcqo7fW/3gO33esGWkJyA4dJn8e8lUgbBZHbNOR5ABwgG+FCRCJw0iBvBH/iepqsxYH0AUo4J+ntCOtwOqNdPl6IdzmQI8h3DWKkMTSuvtuVS+Qd5s27l0ZyYT+oSnNVasHnVyHILM7O2hly9tm4l7hU+GI6jb4AxA70BYhO5h1rxi5Nvzl2cWVwVZh0UpeJTkwXzhiibGzQ+1yRb/5uaPOZ1kBYx7xrJdouVlR0oq7VTCi1jqbkWxuFlccxppe3ENN/rAfWvgcXfQCrdi3LWMit9bzIqC/0nRwFG/EIODYMG+tZngZXAKTXl4ozNoZ2DoLStVXbRVWLXMK+SvRZeEqCRWONY0nfz5EhgaC7SamMxaw+iJGfTrv6dQe0M+Y52F0mMldO7TN4T7vEA4fo3xeMAaAVjmCA/9d3e1jPGlmfXzrn4gW1rFOe6QqwGQ0ETSmmzBR4MO1Y07GqBKPccKcSK6FwuEaZPZ7CN0gruiVCTA6MbY+kW19Byp4YlqpwFW3doz6rOVEsZuP5sm4CrZVeNEG7yDDFWHNYX3h/xJH+FbbtTFvW7oAto61genePISl4tG76s8k61mU11fHD4HdTXqeOJe2jN5Hm0P+cpSUsj9uQZg1aP5UZVvfqsrDQEc7qabLcikCAwEAAaNTMFEwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUruMnYe8k7Qg5J9UoVUnkXwP5wEowHwYDVR0jBBgwFoAUruMnYe8k7Qg5J9UoVUnkXwP5wEowDQYJKoZIhvcNAQELBQADggIBAEWQRTaKVU45+0oBC7mxSFHMWqo/YwXK9o3Oce5FqH5gDN82ovF88cC7XR4HGxgDoRAy30P4EKkmrK84gMaOCPFDdHMqqEhPn1qhwiRMvSF1vcG9gXnXjRLyPqAaSs5Muj1XZdAv/Wg/M62zCA2HZrM/Dld/3NYMz1iHibv1aRZXOBhWIBvo9Em+oKDxvQIvLoKGM7OrJ9l+2/VQ0euTaiUCm8CvxP32QWc4unAJOwlej6LwwuWAEDHc5EZ643E64CsFEfgKK34fog7zFAc5wVwL+sxt1e5YVTObyiA2q5QRpYYHqmMhIMyPhwAeliIQ7MPAnX5tzKa737vfu1uZFW/orsUlc+0ryisY27kZhPQUsqhPd1fE2JGvid6JD9I/kIdQVkhgYBxMcVeC1Rj7aDCZgrvkhA8htYFFN1B94wld0GGbGTbPmakLdscNIf9nGOHvRpCYxtv7hCsRE1XWsztLNlTd+FAewdR8CxpUeWIwSQ8qn9gP8LcaMJJ7AV9qkkBbBD9B//INY9jDpqyH6heM/b1sTb08emL/JuSjbA8HuixdPZwPErisEnzim5M0TjBzo2+5ThO4idRPxSvasFtl6ny+rAySxr8FL/KS6Qj+ZMIvKgmh1ZGCT3ePI5ml8JxqK5zWZlRpMk/M9zIrr7Hwu4/OsodNXBjBZ7Xe3F0h'
          //keyVaultSecretId: not needed yet
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: appGatewayPublicIPAddress.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
      {
        name: 'port_443'
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'apim'
        properties: {
          backendAddresses: [
            {
              fqdn: primaryBackendEndFQDN
            }
          ]
        }
      }
      {
        name: 'gatewaybackend'
        properties: {
          backendAddresses: [
            {
              fqdn: apiFQDN
            }
          ]
        }
      }
      {
        name: 'portalbackend'
        properties: {
          backendAddresses: [
            {
              fqdn: portalFQDN
            }
          ]
        }
      }
      {
        name: 'managementbackend'
        properties: {
          backendAddresses: [
            {
              fqdn: managementFQDN
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'default'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: false
          affinityCookieName: 'ApplicationGatewayAffinity'
          requestTimeout: 20
        }
      }
      {
        name: 'https'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          hostName: primaryBackendEndFQDN
          pickHostNameFromBackendAddress: false
          requestTimeout: 20
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGatewayName, 'APIM')
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'default'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'port_80')
          }
          protocol: 'Http'
          hostnames: []
          requireServerNameIndication: false
        }
      }
      {
        name: 'https'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'port_443')
          }
          protocol: 'Https'
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGatewayName, appGatewayFQDN)
          }
          hostnames: []
          requireServerNameIndication: false
        }
      }
    ]
    urlPathMaps: []
    requestRoutingRules: [
      {
        name: 'apim'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'https')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'apim')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'https')
          }
        }
      }
    ]
    probes: [
      {
        name: 'APIM'
        properties: {
          protocol: 'Https'
          host: primaryBackendEndFQDN
          path: probeUrl
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: false
          minServers: 0
          match: {
            statusCodes: [
              '200-399'
            ]
          }
        }
      }
    ]
    rewriteRuleSets: []
    redirectConfigurations: []
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Detection'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.0'
      disabledRuleGroups: []
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    enableHttp2: true
    autoscaleConfiguration: {
      minCapacity: 2
      maxCapacity: 3
    }
  }
}
