---
title: "Atelier 7 : Infrastructure de la passerelle IA"
description: Ajoutez Azure OpenAI et Azure AI Content Safety à chaque environnement avec Bicep, un accès sans clé par identités managées et une liste de blocage Content Safety déterministe.
---

# Atelier 7 : Infrastructure de la passerelle IA

<span class="chip phase-build"><span aria-hidden="true">🤖</span> Infrastructure IA</span> <span class="chip phase-idea">30 min</span> <span class="chip phase-plan">Avancé</span>

## Aperçu

<div class="lab-meta" markdown>

| Élément | Détails |
|------|---------|
| **Durée** | 30 minutes |
| **Niveau** | Avancé |
| **Prérequis** | [Atelier 6](lab-06-rollback.md) terminé; quota pour `gpt-4o` Standard dans `canadaeast` (ou changez la région et le modèle dans les fichiers de paramètres) |
| **Point de contrôle** | `apim007-ai-<env>` réussi dans les deux environnements; la liste de blocage existe |
| **Atelier suivant** | [Atelier 8 : Publication IA](lab-08-ai-release.md) |

</div>

La passerelle IA place API Management devant Azure OpenAI. Les clients ne voient jamais de clé de modèle : APIM appelle le modèle avec son **identité managée**, et l'authentification locale (par clé) est désactivée sur les deux comptes IA.

<figure class="anim-frame" markdown>
![Diagramme animé du chemin d'une requête de la passerelle IA : client avec une clé d'équipe, APIM retire la clé, applique la limite de jetons de l'équipe, filtre l'invite avec Content Safety, appelle Azure OpenAI avec son identité managée et émet des métriques de jetons](../../assets/anim/ai-gateway-flow.fr.svg)
<figcaption>Le chemin de requête que vous construirez dans les ateliers 7 à 9.</figcaption>
</figure>

## Objectifs d'apprentissage

À la fin de cet atelier, vous saurez :

* Déployer les comptes IA par environnement à côté du service APIM.
* Expliquer quelle identité reçoit quel rôle de données, et pourquoi l'identité d'infrastructure ne peut accorder que ces rôles.
* Créer la liste de blocage Content Safety utilisée par les tests.

## Étapes

### Étape 1 : Autoriser l'identité d'infrastructure à accorder les rôles de données IA

Le workflow d'infrastructure actuel a déjà déployé les comptes IA dans l'atelier 1, et le script de configuration actuel inclut déjà les rôles de données IA. Cette relance est idempotente : elle vérifie les conditions existantes et met à jour les anciennes configurations au besoin. Le Bicep IA accorde deux rôles de données à l'identité managée d'APIM, que la condition RBAC Administrator de l'identité d'infrastructure doit autoriser.

```powershell
./scripts/apim-007-setup/Initialize-Apim007Environment.ps1 -Stage Initial `
    -SubscriptionId $SubscriptionId -TenantId $TenantId -Location $Location `
    -GitHubRepository $Repo -BudgetAmount 150 -BudgetAlertEmail $AlertEmail `
    -ExpiresOn (Get-Date).AddDays(30).ToString('yyyy-MM-dd') -ProdReviewers $Reviewer `
    -PreventSelfReview $PreventSelfReview -WhatIf
```

Revoyez les conditions des attributions de rôles, puis relancez sans `-WhatIf`. Avec la configuration actuelle, les conditions peuvent déjà être correctes; une ligne de mise à jour n'est pas obligatoire. Réutilisez la valeur `$PreventSelfReview` de l'atelier 0 pour ne pas bloquer de nouveau vos approbations en solo.

### Étape 2 : Revoir le Bicep IA

| Fichier | Définit |
|------|---------|
| `infra/apim-demo-007/ai.bicep` | Compte AIServices et déploiement `chat`, compte ContentSafety, attributions de rôles |
| `ai.parameters.dev.json`, `ai.parameters.prod.json` | Modèle `gpt-4o` `2024-11-20`, Standard, capacité 10 |
| `configuration.007.ai-settings.json` | Nom de la liste de blocage et terme de test, limites par équipe, seuil de sécurité |

| Principal | Rôle | Sur |
|-----------|------|----|
| Identité système d'APIM | Cognitive Services OpenAI User | Compte AIServices |
| Identité système d'APIM | Cognitive Services User | Compte ContentSafety |
| Identité d'infrastructure | Cognitive Services User | Compte ContentSafety (écriture de la liste de blocage) |

### Étape 3 : Exécuter le workflow d'infrastructure

```powershell
gh workflow run infra-apim-007.yml --repo $Repo -f target=dev
gh workflow run infra-apim-007.yml --repo $Repo -f target=prod
```

Le travail de provisionnement déploie maintenant `apim007-ai-<env>` après APIM et écrit la liste de blocage :

```powershell
gh run view <run-id> --repo $Repo --json jobs --jq '.jobs[] | select(.name|test("Provision")) | .steps[] | [.name, .conclusion] | @tsv'
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell listant les étapes de Provision prod, dont Deploy AI services et Content safety blocklist, toutes réussies](../../assets/img/lab-07/07-03-blocklist.png)
<figcaption>Exécution <code>37652742332</code> : services IA et liste de blocage déployés par l'identité d'infrastructure de prod.</figcaption>
</figure>

### Étape 4 : Vérifier les comptes, le modèle et les rôles

```powershell
az cognitiveservices account list -g rg-apim-demo-007-prod-apim --query "[].{name:name, kind:kind, sku:sku.name, location:location, localAuthDisabled:properties.disableLocalAuth}" -o table
az cognitiveservices account deployment list -g rg-apim-demo-007-prod-apim -n <ais-account-name> --query "[].{name:name, model:properties.model.name, version:properties.model.version, sku:sku.name, capacity:sku.capacity}" -o table
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell montrant un compte AIServices et un compte ContentSafety avec l'authentification locale désactivée, et le déploiement chat de gpt-4o 2024-11-20 Standard de capacité 10](../../assets/img/lab-07/07-01-ai-accounts.png)
<figcaption>Les deux comptes ont <code>disableLocalAuth</code> : les clés sont inutilisables.</figcaption>
</figure>

```powershell
foreach ($a in '<ais-account-name>', '<cs-account-name>') {
    $id = az cognitiveservices account show -g rg-apim-demo-007-prod-apim -n $a --query id -o tsv
    az role assignment list --scope $id --query "[].{account:'$a', role:roleDefinitionName, principalType:principalType}" -o table
}
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell listant les attributions de rôles : OpenAI User sur le compte AIServices et Cognitive Services User sur le compte ContentSafety pour des principaux de service](../../assets/img/lab-07/07-02-ai-roles.png)
<figcaption>Seuls des principaux de service détiennent des rôles de données; aucun utilisateur n'a d'accès permanent.</figcaption>
</figure>

!!! checkpoint "Point de contrôle"
    Les deux environnements ont deux comptes IA avec l'authentification locale désactivée, un déploiement `chat`, et l'exécution d'infrastructure montre `Content safety blocklist` réussi.
