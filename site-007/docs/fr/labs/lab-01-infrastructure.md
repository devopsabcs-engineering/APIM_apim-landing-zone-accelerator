---
title: "Atelier 1 : Provisionner dev et prod avec Bicep"
description: Déployez le registre partagé, puis les services API Management et les backends de dev et de prod avec le workflow d'infrastructure, et dérivez le manifeste cible utilisé par chaque version.
---

# Atelier 1 : Provisionner dev et prod avec Bicep

<span class="chip phase-build"><span aria-hidden="true">🏗️</span> Infrastructure</span> <span class="chip phase-idea">40 min</span> <span class="chip phase-plan">Intermédiaire</span>

## Aperçu

<div class="lab-meta" markdown>

| Élément | Détails |
|------|---------|
| **Durée** | 40 minutes (API Management Basic v2 en prend la plus grande partie) |
| **Niveau** | Intermédiaire |
| **Prérequis** | [Atelier 0](lab-00-setup.md) terminé |
| **Point de contrôle** | `apim007-apim-<env>` et `apim007-backends-<env>` réussis dans les deux environnements; un manifeste cible pour la prod |
| **Atelier suivant** | [Atelier 2 : Le paquet](lab-02-bundle.md) |

</div>

L'infrastructure et la configuration ont des propriétaires distincts. `infra-apim-007.yml` provisionne **l'hébergement seulement** : il ne publie jamais d'API et ne change jamais l'image d'une application existante. Les versions possèdent la configuration et les images.

## Objectifs d'apprentissage

À la fin de cet atelier, vous saurez :

* Exécuter le workflow d'infrastructure pour les cibles shared, dev et prod.
* Expliquer pourquoi les nouvelles applications démarrent sur une image d'amorçage approuvée et épinglée par condensé.
* Dériver un manifeste cible de noms de déploiement fixes au lieu de deviner les noms de ressources.

## Étapes

### Étape 1 : Approuver l'image d'amorçage

Les nouvelles applications App Service démarrent sur une image d'exemple épinglée par condensé jusqu'à la première version. `infra/apim-demo-007/bootstrap-image.json` doit indiquer qui l'a approuvée :

```json
{
    "image": "mcr.microsoft.com/dotnet/samples@sha256:4682284c8c2f87d426ff2ee27319705af02620e36e486b450ab080d9c83cbad9",
    "tag": "aspnetapp-8.0",
    "port": 8080,
    "approvedBy": "<your-github-login>",
    "approvedOn": "<yyyy-mm-dd>"
}
```

Validez-le par une demande de tirage. Le workflow de validation et le workflow d'infrastructure refusent tous deux les valeurs `PENDING`.

### Étape 2 : Déployer le registre partagé, puis terminer la configuration

```powershell
gh workflow run infra-apim-007.yml --repo $Repo -f target=shared
gh run watch --repo $Repo (gh run list --repo $Repo --workflow infra-apim-007.yml --limit 1 --json databaseId --jq '.[0].databaseId')
```

Le résumé de l'exécution affiche le nom du registre. Accordez le rôle AcrPull seulement et publiez les variables du registre :

```powershell
./scripts/apim-007-setup/Initialize-Apim007Environment.ps1 -Stage PostRegistry `
    -SubscriptionId $SubscriptionId -TenantId $TenantId -GitHubRepository $Repo -RegistryName '<registryName>'
```

### Étape 3 : Provisionner le dev, puis la prod

```powershell
gh workflow run infra-apim-007.yml --repo $Repo -f target=dev
gh workflow run infra-apim-007.yml --repo $Repo -f target=prod
gh run list --repo $Repo --workflow infra-apim-007.yml --limit 8
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell listant les exécutions récentes d'infra-apim-007 pour les cibles shared, dev et prod, toutes réussies](../../assets/img/lab-01/01-01-infra-runs.png)
<figcaption>Exécutions d'infrastructure de l'environnement enregistré (les plus récentes déploient aussi les services IA de l'atelier 7).</figcaption>
</figure>

Chaque exécution vérifie le locataire et l'abonnement, contrôle les étiquettes des groupes de ressources, lance un what-if Bicep, déploie et affiche un manifeste cible :

<figure class="screenshot-frame" markdown>
![Page d'exécution GitHub Actions d'Infra APIM 007 pour la prod avec les travaux Bicep build et Provision prod réussis et le résumé du manifeste cible](../../assets/img/lab-01/01-04-gh-infra-run.png)
<figcaption>Exécution <code>37652742332</code> : provisionnement de prod-007.</figcaption>
</figure>

!!! warning "Basic v2 prend du temps"
    Un nouveau service API Management Basic v2 prend en général de 15 à 40 minutes. Le workflow attend; ne l'annulez pas.

### Étape 4 : Vérifier les déploiements fixes

Chaque version trouve ses cibles par des **noms de déploiement fixes**, pas par des recherches :

```powershell
az deployment group list -g rg-apim-demo-007-prod-apim --query "[?starts_with(name, 'apim007')].{name:name, state:properties.provisioningState, timestamp:properties.timestamp}" -o table
az deployment group list -g rg-apim-demo-007-prod-backends --query "[?starts_with(name, 'apim007')].{name:name, state:properties.provisioningState}" -o table
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell montrant les déploiements apim007-apim-prod, apim007-ai-prod et apim007-backends-prod à l'état Succeeded](../../assets/img/lab-01/01-02-deployments.png)
<figcaption>Les déploiements <code>apim007-apim-prod</code>, <code>apim007-backends-prod</code> (et, à partir de l'atelier 7, <code>apim007-ai-prod</code>).</figcaption>
</figure>

### Étape 5 : Construire le manifeste cible

Le manifeste est le contrat entre l'infrastructure et les versions : ID de ressources exacts, URL de la passerelle et URL des backends, validés par rapport aux étiquettes et aux groupes de ressources.

```powershell
$env:EXPECTED_TENANT_ID = $TenantId; $env:EXPECTED_SUBSCRIPTION_ID = $SubscriptionId
$m = ./scripts/apim-007/Get-Apim007TargetManifest.ps1 -Environment prod -OutputPath $env:TEMP\manifest-prod.json
(Get-Content $env:TEMP\manifest-prod.json | ConvertFrom-Json).apim | Select-Object name, location, gatewayUrl
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell montrant le SHA256 du manifeste, le nom, la région et l'URL de passerelle de l'APIM de prod, et les deux URL des backends de prod](../../assets/img/lab-01/01-03-target-manifest.png)
<figcaption>Le manifeste cible de prod. Son SHA256 est consigné dans le plan de prod et revérifié avant le déploiement en prod.</figcaption>
</figure>

!!! checkpoint "Point de contrôle"
    Les deux environnements affichent des déploiements `Succeeded`, les deux passerelles répondent sur `https://<apim-name>.azure-api.net` et le script de manifeste s'exécute sans erreur pour `dev` et `prod`.
