param keyVaultName string
param secretName   string

resource keyVaultCertificate 'Microsoft.KeyVault/vaults/secrets@2022-07-01' existing = {
  name: '${keyVaultName}/${secretName}'
}

output secretUri string = keyVaultCertificate.properties.secretUriWithVersion
