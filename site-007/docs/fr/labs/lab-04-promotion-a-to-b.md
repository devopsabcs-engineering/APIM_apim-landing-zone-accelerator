---
title: "Atelier 4 : Promotion A vers B"
description: Changez un en-tête de stratégie visible de baseline-a à candidate-b, montrez le dev avec la nouvelle valeur pendant que la prod a encore l'ancienne, puis approuvez et montrez la prod rattraper le dev.
---

# Atelier 4 : Promotion A vers B

<span class="chip phase-sign"><span aria-hidden="true">🔀</span> Promotion</span> <span class="chip phase-idea">25 min</span> <span class="chip phase-plan">Intermédiaire</span>

## Aperçu

<div class="lab-meta" markdown>

| Élément | Détails |
|------|---------|
| **Durée** | 25 minutes |
| **Niveau** | Intermédiaire |
| **Prérequis** | [Atelier 3](lab-03-baseline-release.md) terminé, les deux environnements `clean` |
| **Point de contrôle** | Les deux passerelles renvoient `x-demo-release: candidate-b` |
| **Atelier suivant** | [Atelier 5 : GitOps par extraction](lab-05-extraction-gitops.md) |

</div>

C'est le moment fort de la démo : le même changement est visible en dev alors que la prod sert encore la version précédente, jusqu'à ce qu'un humain approuve.

## Objectifs d'apprentissage

À la fin de cet atelier, vous saurez :

* Faire un changement de configuration observable par une demande de tirage.
* Prouver avec les en-têtes de réponse quelle version sert chaque environnement.
* Montrer à partir de l'historique d'exécution que la prod a attendu le réviseur.

## Étapes

### Étape 1 : Vérifier les en-têtes de version actuels

Chaque stratégie d'API définit trois en-têtes de réponse : `x-demo-environment`, `x-demo-release` et `x-demo-backend-host`.

```powershell
$env:EXPECTED_TENANT_ID = $TenantId
$env:EXPECTED_SUBSCRIPTION_ID = $SubscriptionId
$null = ./scripts/apim-007/Get-Apim007TargetManifest.ps1 -Environment dev -OutputPath $env:TEMP/manifest-dev.json
$Gateways = (Get-Content $env:TEMP/manifest-dev.json | ConvertFrom-Json).apim.name,
    (Get-Content $env:TEMP/manifest-prod.json | ConvertFrom-Json).apim.name
foreach ($g in $Gateways) {
    "== $g"
    (Invoke-WebRequest "https://$g.azure-api.net/weather/api/Version" -SkipHttpErrorCheck).Headers.GetEnumerator() |
        Where-Object Key -like 'x-demo-*' | ForEach-Object { "$($_.Key): $($_.Value)" }
}
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell montrant les en-têtes x-demo-environment, x-demo-release et x-demo-backend-host renvoyés par les passerelles dev et prod](../../assets/img/lab-04/04-01-gateway-headers.png)
<figcaption>Chaque environnement indique son propre nom et son propre hôte backend, et la même valeur de version.</figcaption>
</figure>

### Étape 2 : Passer de A à B par une demande de tirage

Utilisez l'ID numérique de votre véritable User Story ou Bug ADO. Par exemple, l'ID `1234` donne `feature/1234-candidate-b`; ne saisissez pas de valeurs entre chevrons. Commencez sans modifications locales. Arrêtez immédiatement si une commande Git échoue.

```powershell
[int]$WorkItemId = Read-Host 'ADO User Story or Bug ID'
if ($WorkItemId -le 0) { throw 'A real work item ID is required.' }
if (git status --porcelain) { throw 'Commit or preserve your existing changes first.' }
git switch main
if ($LASTEXITCODE) { throw 'Could not switch to main.' }
git pull --ff-only
if ($LASTEXITCODE) { throw 'Could not update main.' }
$Branch = "feature/$WorkItemId-candidate-b"
git switch -c $Branch
if ($LASTEXITCODE) { throw 'Branch creation failed; do not continue on main.' }
foreach ($p in 'artifacts.007/apis/weather/policy.xml', 'artifacts.007/apis/software-version/policy.xml') {
    $policy = Get-Content $p -Raw
    if (-not $policy.Contains('<value>baseline-a</value>')) { throw "No baseline-a in $p; inspect the starting state." }
    $policy.Replace('<value>baseline-a</value>', '<value>candidate-b</value>') | Set-Content $p -NoNewline
}
git add -- artifacts.007/apis/weather/policy.xml artifacts.007/apis/software-version/policy.xml
git commit -m "feat: promote candidate-b AB#$WorkItemId"
if ($LASTEXITCODE) { throw 'Commit failed.' }
git push -u origin $Branch
if ($LASTEXITCODE) { throw 'Push failed.' }
gh pr create --repo $Repo --base main --head $Branch --fill
```

Fusionnez la demande de tirage quand les vérifications réussissent. La publication démarre automatiquement.

### Étape 3 : Montrer le dev en avance sur la prod

Pendant que `Deploy prod-007` attend l'approbation, exécutez de nouveau la boucle de l'étape 1.

!!! success "Résultat attendu"
    Le dev renvoie `x-demo-release: candidate-b`. La prod renvoie encore `baseline-a`.

### Étape 4 : Approuver et montrer la prod rattraper le dev

Approuvez `prod-007` (atelier 3, étape 3), attendez la fin de l'exécution et relancez la boucle : les deux renvoient `candidate-b`.

```powershell
gh run view 37616892784 --repo $Repo --json jobs --jq '.jobs[] | [.name, .conclusion, .startedAt, .completedAt] | @tsv'
gh api repos/$Repo/actions/runs/37616892784/approvals --jq '.[] | [.environments[0].name, .state, .user.login] | @tsv'
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell avec la chronologie des travaux de l'exécution A vers B, montrant Deploy dev-007 terminé bien avant le début de Deploy prod-007, et l'approbation de prod-007](../../assets/img/lab-04/04-02-promotion-timeline.png)
<figcaption>Exécution <code>37616892784</code> : le dev était terminé bien avant le début de la prod, et la prod n'a démarré qu'après l'approbation.</figcaption>
</figure>

!!! checkpoint "Point de contrôle"
    Les deux passerelles renvoient `candidate-b`, et les deux états de version enregistrent le nouveau candidat comme `clean`.
