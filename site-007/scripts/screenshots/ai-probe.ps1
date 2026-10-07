param([string[]]$Environments = @('dev', 'prod'))
$ErrorActionPreference = 'Stop'
$targets = @{
    dev  = @{ rg = 'rg-apim-demo-007-dev-apim'; name = 'apim-dev-007-uovzcyp6yypu2' }
    prod = @{ rg = 'rg-apim-demo-007-prod-apim'; name = 'apim-prod-007-p4afmw2tk5j4m' }
}
foreach ($e in $Environments) {
    $t = $targets[$e]
    $id = az apim show -g $t.rg -n $t.name --query id -o tsv
    $key = (az rest --method post --url "https://management.azure.com$id/subscriptions/sub-team-retail/listSecrets?api-version=2024-06-01-preview" | ConvertFrom-Json).primaryKey
    $body = '{"messages":[{"role":"user","content":"Say hi in two words."}],"max_tokens":8}'
    $r = Invoke-WebRequest -Method Post -Uri "https://$($t.name).azure-api.net/ai/chat/completions?api-version=2024-10-21" -Headers @{ 'api-key' = $key } -ContentType 'application/json' -Body $body -SkipHttpErrorCheck
    Remove-Variable key
    [pscustomobject]@{
        Environment     = $e
        Status          = $r.StatusCode
        Release         = [string]$r.Headers['x-demo-release']
        EnvHeader       = [string]$r.Headers['x-demo-environment']
        RemainingTokens = [string]$r.Headers['remaining-tokens']
    }
}
