/*
 * Input parameters
*/
@description('The name of the Application Gateawy to be created.')
param appGatewayName string

@description('The location of the Application Gateawy to be created')
param location string = resourceGroup().location

@description('The subnet resource id to use for Application Gateway.')
param appGatewaySubnetId string

// @description('The backend URL of the APIM.')
// param primaryBackendEndFQDN string = 'api-internal.example.com'

// @description('The Url for the Application Gateway Health Probe.')
// param probeUrl string = '/status-0123456789abcdef'

param appGatewayUserIdentityId string

param certificateApiSecretUri string
param certificatePortalSecretUri string
param certificateManagementSecretUri string

param apiFQDN string
param portalFQDN string
param managementFQDN string

param trustedRootCertificateCertificateData string = 'MIIFqzCCA5OgAwIBAgIUWaQKwQxaZMhV1K8+x0UPyOYj3RAwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UEBhMCQ0ExDzANBgNVBAgMBlF1ZWJlYzERMA8GA1UEBwwITW9udHJlYWwxEDAOBgNVBAoMB0NvbnRvc28xIDAeBgNVBAMMF3Jvb3RjYS5NbmdFbnYwMTk3MDIuY29tMB4XDTIzMDIyMjIyNTY0NloXDTMzMDIxOTIyNTY0NlowZTELMAkGA1UEBhMCQ0ExDzANBgNVBAgMBlF1ZWJlYzERMA8GA1UEBwwITW9udHJlYWwxEDAOBgNVBAoMB0NvbnRvc28xIDAeBgNVBAMMF3Jvb3RjYS5NbmdFbnYwMTk3MDIuY29tMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAnY85F7m19LHCI/2ufG/EKo7Plb32mOQnz9hK3vlJOpCvjszKYnunBNPuV0y43aO9IbCUojjiXRL8GcSGuanXXQqcDP1jg/iI00CNJHs5lwadIXAMysFyCARl6+N1Khv8dTBR8BW0z2RpLzOZjd+xkR6CwUKJsSdBYIdI4nKHyPAARsvZ2sn2wgkFqRPhFC/cKxGBpQjZ4Ai4szDPUfE7rB9JnZ/p0PjtpE+uR1cyjsP46EZZERamWskI8OFFYE1MbpwHp9P4p1CaWdwsOldPm70+wDhNAZtuVfeOIoC3aFZZZTG9z/JmbAGktepT+QIcMxfiLapwTd3Ye1J335PXKzmCu5S42Q3tiH7BzOw/O4oGDxurDhjMZtxbfOm6U2sZcei6U7iHKmneN6v0eMc2vTPmDEprUfdcWCq0cyLd6bbmKSPd1+WWW+iLzSR1Vp8irCc9bQocvbwpePa9wWcK+ITuH55YQCXRHSauPBtI3fJjOcV1dEcoA2UEMwN753RXJTzxnLlrwn0WWjB7z/mNWBP+7/dcBowwzjg+cLabFZxEDMAWnfUnZuyTE94DfNyiLrxhNRKX1g3ufV22HM6lRPjQ27FVvbaf9s8nqkzcy4mDWXiMopDuyE2Rc50bZPpuQ23Y0L+eumJdfcCKTvFNMsleZFcKrtqBKrPFzpXSS4MCAwEAAaNTMFEwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUr/d8G+dGkUHvoJB6HAoqIJnyafYwHwYDVR0jBBgwFoAUr/d8G+dGkUHvoJB6HAoqIJnyafYwDQYJKoZIhvcNAQELBQADggIBAEsJsiekIW6e7noWrnCh+SPRFECj34h/E8zKHysS6NgJmMj6qNiThTFnzde2f+ym7/gogqBJmaVXrxkDYIYd9M5Z5mFjqt086zMSDLIRM+iBEL5w5kwihp2vtg0h8RMkObguaXNzfGYVbM+/Gg1WyfbAwQCa/ixeOS/zAEzeXvo1Dg4Ys5Z0wqIHK6TKtZOmcN5oP8ZNFWvKv0t396zvtmptr0Qg5ZNDNZP6TzUqv/e1texBi6KjXePRwsDTEoqhByPcszKVK8DdNZWWEO6hbreYa0w2ubPeWBECtk/7zVVEFkZBa37li3XsSwvrsjBw6+SWp9z1x463ijOIot4iG5T9r9/MX73E2WQ+nOiP6S3HH9AJ1AR0zSDAjoMRAhvB8L0OuGZV4rrF5d1FwaW8kGz7fc+iOG8rD3bRLNuO2AF5NmOOZLwX8kLnGYfj3ENN87pyySK1YmH3gvgdmDFkGzcfe8QlX59sTpeQ4L69L1KPTmlIanqOt9R8H2+dqfXUp5re0puo66zBX+obaYba30ujTFnkFHIL1z+9cQNIOORz49C11uKuVI+6Co3StOZam2K9fSZsXxRtNEzcJlI38p4UYzhJNkiQfyU4Mp8LgCkgdXWHHSIHXCacEADsNGCPlKi8omNHB9dgBBVdyo/iBcfTGxDUKB+9gF8gq2je8R2f'

var appGatewayPrimaryPip = 'pip-${appGatewayName}'

resource appGatewayPublicIPAddress 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: appGatewayPrimaryPip
  location: location
  sku: {
    name: 'Standard'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource appGatewayName_resource 'Microsoft.Network/applicationGateways@2022-07-01' = {
  name: appGatewayName
  location: location
  // dependsOn: [
  //   certificate
  // ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appGatewayUserIdentityId}': {}
    }
  }
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
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
      // {
      //   name: appGatewayFQDN
      //   properties: {
      //     keyVaultSecretId: certificate.outputs.secretUri
      //   }
      // }
      {
        name: 'gatewaycert' // apiFQDN
        properties: {
          keyVaultSecretId: certificateApiSecretUri
        }
      }
      {
        name: 'portalcert' // portalFQDN
        properties: {
          keyVaultSecretId: certificatePortalSecretUri
        }
      }
      {
        name: 'managementcert' // managementFQDN
        properties: {
          keyVaultSecretId: certificateManagementSecretUri
        }
      }
    ]
    sslPolicy: {
      //minProtocolVersion: 'TLSv1_2'
      policyType: 'Predefined'
      policyName: 'AppGwSslPolicy20220101'
      // cipherSuites: [
      //   'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256'
      //   'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384'
      //   'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256'
      //   'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'
      //   'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256'
      //   'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384'
      //   'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256'
      //   'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384'
      // ]
    }
    trustedRootCertificates: [
      {
        //id: 'not needed yet'
        name: 'whitelistcert1'
        properties: {
          data: trustedRootCertificateCertificateData
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
      // {
      //   name: 'port_80'
      //   properties: {
      //     port: 80
      //   }
      // }
      {
        name: 'port_443'
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [
      // {
      //   name: 'apim'
      //   properties: {
      //     backendAddresses: [
      //       {
      //         fqdn: primaryBackendEndFQDN
      //       }
      //     ]
      //   }
      // }
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
      // {
      //   name: 'default'
      //   properties: {
      //     port: 80
      //     protocol: 'Http'
      //     cookieBasedAffinity: 'Disabled'
      //     pickHostNameFromBackendAddress: false
      //     affinityCookieName: 'ApplicationGatewayAffinity'
      //     requestTimeout: 20
      //   }
      // }
      // {
      //   name: 'https'
      //   properties: {
      //     port: 443
      //     protocol: 'Https'
      //     cookieBasedAffinity: 'Disabled'
      //     hostName: primaryBackendEndFQDN
      //     pickHostNameFromBackendAddress: false
      //     requestTimeout: 20
      //     probe: {
      //       id: resourceId('Microsoft.Network/applicationGateways/probes', appGatewayName, 'APIM')
      //     }
      //   }
      // }
      {
        name: 'apimPoolGatewaySetting'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 180
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGatewayName, 'apimgatewayprobe')
          }
          trustedRootCertificates: [
            {
              id: resourceId('Microsoft.Network/applicationGateways/trustedRootCertificates', appGatewayName, 'whitelistcert1')
            }
          ]
        }
      }
      {
        name: 'apimPoolPortalSetting'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 180
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGatewayName, 'apimportalprobe')
          }
          trustedRootCertificates: [
            {
              id: resourceId('Microsoft.Network/applicationGateways/trustedRootCertificates', appGatewayName, 'whitelistcert1')
            }
          ]
        }
      }
      {
        name: 'apimPoolManagementSetting'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 180
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGatewayName, 'apimmanagementprobe')
          }
          trustedRootCertificates: [
            {
              id: resourceId('Microsoft.Network/applicationGateways/trustedRootCertificates', appGatewayName, 'whitelistcert1')
            }
          ]
        }
      }
    ]
    httpListeners: [
      // {
      //   name: 'default'
      //   properties: {
      //     frontendIPConfiguration: {
      //       id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGwPublicFrontendIp')
      //     }
      //     frontendPort: {
      //       id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'port_80')
      //     }
      //     protocol: 'Http'
      //     hostnames: []
      //     requireServerNameIndication: false
      //   }
      // }
      // {
      //   name: 'https'
      //   properties: {
      //     frontendIPConfiguration: {
      //       id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGwPublicFrontendIp')
      //     }
      //     frontendPort: {
      //       id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'port_443')
      //     }
      //     protocol: 'Https'
      //     sslCertificate: {
      //       id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGatewayName, appGatewayFQDN)
      //     }
      //     hostnames: []
      //     requireServerNameIndication: false
      //   }
      // }

      {
        name: 'gatewaylistener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'port_443')
          }
          protocol: 'Https'
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGatewayName, 'gatewaycert')
          }
          hostName: apiFQDN
          hostNames: []
          requireServerNameIndication: true
          customErrorConfigurations: []
        }
      }
      {
        name: 'portallistener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'port_443')
          }
          protocol: 'Https'
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGatewayName, 'portalcert')
          }
          hostName: portalFQDN
          hostNames: []
          requireServerNameIndication: true
          customErrorConfigurations: []
        }
      }
      {
        name: 'managementlistener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'port_443')
          }
          protocol: 'Https'
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGatewayName, 'managementcert')
          }
          hostName: managementFQDN
          hostNames: []
          requireServerNameIndication: true
          customErrorConfigurations: []
        }
      }

    ]
    urlPathMaps: []
    requestRoutingRules: [
      // {
      //   name: 'apim'
      //   properties: {
      //     ruleType: 'Basic'
      //     httpListener: {
      //       id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'https')
      //     }
      //     backendAddressPool: {
      //       id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'apim')
      //     }
      //     backendHttpSettings: {
      //       id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'https')
      //     }
      //   }
      // }

      {
        name: 'gatewayrule'
        properties: {
          ruleType: 'Basic'
          priority: 10009
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'gatewaylistener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'gatewaybackend')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'apimPoolGatewaySetting')
          }
        }
      }
      {
        name: 'portalrule'
        properties: {
          ruleType: 'Basic'
          priority: 10012
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'portallistener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'portalbackend')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'apimPoolPortalSetting')
          }
        }
      }
      {
        name: 'managementrule'
        properties: {
          ruleType: 'Basic'
          priority: 10015
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'managementlistener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'managementbackend')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'apimPoolManagementSetting')
          }
        }
      }
    ]
    probes: [
      // {
      //   name: 'APIM'
      //   properties: {
      //     protocol: 'Https'
      //     host: primaryBackendEndFQDN
      //     path: probeUrl
      //     interval: 30
      //     timeout: 30
      //     unhealthyThreshold: 3
      //     pickHostNameFromBackendHttpSettings: false
      //     minServers: 0
      //     match: {
      //       statusCodes: [
      //         '200-399'
      //       ]
      //     }
      //   }
      // }
      {
        name: 'apimgatewayprobe'
        properties: {
          protocol: 'Https'
          host: apiFQDN
          path: '/status-0123456789abcdef'
          interval: 30
          timeout: 120
          unhealthyThreshold: 8
          pickHostNameFromBackendHttpSettings: false
          minServers: 0
          match: {}
        }
      }
      {
        name: 'apimportalprobe'
        properties: {
          protocol: 'Https'
          host: portalFQDN
          path: '/signin'
          interval: 60
          timeout: 300
          unhealthyThreshold: 8
          pickHostNameFromBackendHttpSettings: false
          minServers: 0
          match: {}
        }
      }
      {
        name: 'apimmanagementprobe'
        properties: {
          protocol: 'Https'
          host: managementFQDN
          path: '/ServiceStatus'
          interval: 60
          timeout: 300
          unhealthyThreshold: 8
          pickHostNameFromBackendHttpSettings: false
          minServers: 0
          match: {}
        }
      }
    ]
    rewriteRuleSets: []
    redirectConfigurations: []
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention' // 'Detection'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.0'
      disabledRuleGroups: []
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    // enableHttp2: true
    // autoscaleConfiguration: {
    //   minCapacity: 2
    //   maxCapacity: 3
    // }
  }
}
