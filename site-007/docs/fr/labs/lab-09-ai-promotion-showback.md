---
title: "Atelier 9 : Promotion IA et refacturation des jetons"
description: Promouvez ai-b et un quota de prod plus bas derrière la barrière d'approbation, prouvez que le dev et la prod divergent jusqu'à l'approbation, et rapportez la consommation de jetons par équipe depuis Log Analytics.
---

# Atelier 9 : Promotion IA et refacturation des jetons

<span class="chip phase-sign"><span aria-hidden="true">📊</span> Promotion IA</span> <span class="chip phase-idea">25 min</span> <span class="chip phase-plan">Avancé</span>

## Aperçu

<div class="lab-meta" markdown>

| Élément | Détails |
|------|---------|
| **Durée** | 25 minutes |
| **Niveau** | Avancé |
| **Prérequis** | [Atelier 8](lab-08-ai-release.md) terminé |
| **Point de contrôle** | Les deux environnements renvoient `x-demo-release: ai-b`; un rapport de jetons par équipe |
| **Atelier suivant** | [Atelier 10 : Démantèlement](lab-10-teardown.md) |

</div>

La configuration IA se promeut comme toute autre configuration. Ici, un changement de stratégie et un changement de quota **propre à la prod** voyagent ensemble : l'approbateur voit la nouvelle limite de prod dans le plan avant d'approuver.

## Objectifs d'apprentissage

À la fin de cet atelier, vous saurez :

* Changer une stratégie IA et une limite par environnement dans une seule demande de tirage.
* Prouver avec un vrai appel au modèle quelle version sert chaque environnement.
* Rapporter la consommation de jetons par équipe pour la refacturation.

## Étapes

### Étape 1 : Changer l'en-tête de version et un quota de prod

```powershell
git switch -c feature/<work-item>-ai-b
$p = 'artifacts.007/apis/ai-gateway/policy.xml'
(Get-Content $p -Raw).Replace('<value>baseline-ai</value>', '<value>ai-b</value>') | Set-Content $p -NoNewline
$s = 'configuration.007.ai-settings.json'
$j = Get-Content $s -Raw | ConvertFrom-Json
$j.environments.prod.teams.'team-retail'.dailyTokenQuota = 40000
$j | ConvertTo-Json -Depth 6 | Set-Content $s
git commit -am "feat(artifacts): promote ai-b and lower the prod retail quota AB#<work-item>"
git push -u origin HEAD
gh pr create --repo $Repo --fill
```

Fusionnez après la validation. Le résumé de `Plan prod-007` liste le modèle, le seuil de sécurité et les limites de prod de chaque équipe, dont le nouveau `40000`.

### Étape 2 : Appeler les deux passerelles pendant que la prod attend

La sonde lit la clé `team-retail` par ARM et ne l'affiche jamais :

```powershell
$targets = @{ dev = @('rg-apim-demo-007-dev-apim', '<dev-apim-name>'); prod = @('rg-apim-demo-007-prod-apim', '<prod-apim-name>') }
foreach ($e in 'dev', 'prod') {
    $rg, $name = $targets[$e]
    $id  = az apim show -g $rg -n $name --query id -o tsv
    $key = (az rest --method post --url "https://management.azure.com$id/subscriptions/sub-team-retail/listSecrets?api-version=2024-06-01-preview" | ConvertFrom-Json).primaryKey
    $r = Invoke-WebRequest -Method Post -Uri "https://$name.azure-api.net/ai/chat/completions?api-version=2024-10-21" `
        -Headers @{ 'api-key' = $key } -ContentType 'application/json' `
        -Body '{"messages":[{"role":"user","content":"Say hi in two words."}],"max_tokens":8}' -SkipHttpErrorCheck
    Remove-Variable key
    "{0,-5} HTTP {1} x-demo-release: {2} remaining-tokens: {3}" -f $e, $r.StatusCode, $r.Headers['x-demo-release'], $r.Headers['remaining-tokens']
}
```

!!! success "Résultat attendu pendant que la prod attend"
    Le dev renvoie `ai-b`; la prod renvoie encore `baseline-ai`. Dans l'exécution enregistrée : `dev: HTTP 200 release=ai-b`, `prod: HTTP 200 release=baseline-ai`.

### Étape 3 : Approuver et vérifier

Approuvez `prod-007`, attendez la fin de l'exécution et appelez de nouveau les deux passerelles :

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell montrant les appels aux passerelles IA dev et prod qui renvoient tous deux HTTP 200 avec x-demo-release ai-b et leur nom d'environnement](../../assets/img/lab-09/09-01-ai-promotion.png)
<figcaption>Après l'approbation, les deux environnements servent <code>ai-b</code>, chacun avec son propre budget de jetons restants.</figcaption>
</figure>

<figure class="screenshot-frame" markdown>
![Page d'exécution GitHub Actions de la version ai-b avec tous les travaux réussis](../../assets/img/lab-09/09-03-gh-ai-b-run.png)
<figcaption>Exécution <code>37663312626</code> : la promotion <code>ai-b</code>.</figcaption>
</figure>

### Étape 4 : Rapporter la consommation de jetons par équipe

```powershell
$ai = az deployment group show -g rg-apim-demo-007-prod-apim -n apim007-apim-prod --query properties.outputs.applicationInsightsId.value -o tsv
$ws = az monitor log-analytics workspace show --ids (az resource show --ids $ai --query properties.WorkspaceResourceId -o tsv) --query customerId -o tsv
az monitor log-analytics query -w $ws -o table --analytics-query "AppMetrics | where TimeGenerated > ago(1d) | where Name == 'Total Tokens' | summarize tokens = sum(Sum), calls = sum(ItemCount) by product = tostring(Properties['Product ID'])"
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell montrant le total des jetons et des appels par produit pour dev-007 et prod-007 : team-finance et team-retail](../../assets/img/lab-09/09-02-showback.png)
<figcaption>Refacturation des jetons par produit d'équipe, directement à partir des métriques émises par APIM.</figcaption>
</figure>

!!! tip "Interroger App Insights par l'espace de travail"
    Application Insights basé sur un espace de travail stocke les métriques dans la table `AppMetrics` de Log Analytics. Interrogez l'espace de travail, pas `az monitor app-insights query`, qui peut ne rien renvoyer pour ces composants.

!!! checkpoint "Point de contrôle"
    Les deux environnements renvoient `ai-b`, le quota quotidien retail de prod est `40000`, et la requête de refacturation renvoie des lignes pour les deux équipes.
