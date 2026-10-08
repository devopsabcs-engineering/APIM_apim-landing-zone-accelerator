---
title: "Atelier 0 : Prérequis et configuration initiale"
description: Installez les outils, copiez le dépôt et exécutez le script de configuration qui crée les groupes de ressources, le budget, les identités fédérées, les rôles minimaux et les environnements GitHub.
---

# Atelier 0 : Prérequis et configuration initiale

<span class="chip phase-prod"><span aria-hidden="true">🧰</span> Configuration</span> <span class="chip phase-idea">45 min</span> <span class="chip phase-plan">Intermédiaire</span>

## Aperçu

<div class="lab-meta" markdown>

| Élément | Détails |
|------|---------|
| **Durée** | 45 minutes |
| **Niveau** | Intermédiaire |
| **Plateforme** | Windows 10 ou 11, PowerShell 7, VS Code facultatif |
| **Prérequis** | Propriétaire d'un abonnement Azure, administrateur d'un dépôt GitHub, GitHub Actions activé |
| **Point de contrôle** | Cinq groupes de ressources étiquetés, neuf identités affectées par l'utilisateur, neuf environnements GitHub, `APIM007_ENABLED=true` |
| **Atelier suivant** | [Atelier 1 : Provisionner dev et prod](lab-01-infrastructure.md) |

</div>

Aucun workflow ne peut créer ses propres identités ni ses permissions. Un Propriétaire exécute un script de configuration une seule fois; ensuite, tout changement passe par Git et GitHub Actions, avec des identités fédérées étroites et sans secret.

!!! tip "Recommencer"
    Si vous avez déjà fait les ateliers, remettez d'abord Azure à zéro avec l'[atelier 10, étape 4](lab-10-teardown.md#etape-4-remettre-azure-a-zero) et vérifiez qu'il ne reste aucun nom 007. Suivez ensuite cet atelier tel quel.

## Objectifs d'apprentissage

À la fin de cet atelier, vous saurez :

* Installer et vérifier Azure CLI, GitHub CLI, Node.js 22 et PowerShell 7.
* Installer l'APIops CLI à partir d'un fichier de verrouillage vérifié.
* Expliquer pourquoi chaque environnement GitHub a sa propre identité Azure.
* Exécuter le script de configuration en mode `-WhatIf`, revoir le plan, puis l'appliquer.

## Étapes

### Étape 1 : Installer et vérifier les outils

```powershell
winget install --id Microsoft.AzureCLI -e
winget install --id GitHub.cli -e
winget install --id OpenJS.NodeJS.22 -e
winget install --id Microsoft.PowerShell -e
```

Ouvrez un nouveau terminal PowerShell 7 pour charger le nouveau `PATH`.

!!! warning "Utilisez Node.js 22"
    Les workflows s'exécutent sur Node.js 22, et `tools/apiops-cli` n'accepte que la version 22. `OpenJS.NodeJS.LTS` installe maintenant une version plus récente. Si `node --version` ne commence pas par `v22`, `npm ci` affiche l'avertissement `EBADENGINE`. Trouvez l'autre Node.js avec `winget list --name Node.js`, supprimez-le avec `winget uninstall --id <id>` (ou changez de version avec un gestionnaire de versions), puis ouvrez un nouveau terminal et vérifiez de nouveau.

### Étape 2 : Copier le dépôt et définir vos variables de session

Faites une bifurcation (fork) ou importez le dépôt dans votre organisation, puis clonez-le :

```powershell
$Org  = '<your-github-org>'
$Repo = "$Org/APIM_apim-landing-zone-accelerator"
gh repo fork devopsabcs-engineering/APIM_apim-landing-zone-accelerator --org $Org --clone
Set-Location APIM_apim-landing-zone-accelerator
```

Définissez ces variables dans chaque nouveau terminal (remplacez les valeurs entre chevrons) :

```powershell
$Org            = '<your-github-org>'
$Repo           = "$Org/APIM_apim-landing-zone-accelerator"
$SubscriptionId = '<subscription-id>'
$TenantId       = '<tenant-id>'
$Location       = 'canadacentral'
$Reviewer       = '<github-login-of-the-prod-approver>'
```

### Étape 3 : Se connecter et installer l'APIops CLI

```powershell
az login --tenant $TenantId
az account set --subscription $SubscriptionId
gh auth login
Push-Location tools/apiops-cli
npm ci --ignore-scripts --no-audit --no-fund
Pop-Location
```

La CLI est épinglée à `@azure-tools/apiops-cli` **1.0.4** avec un fichier de verrouillage versionné. Les workflows ne la téléchargent jamais à la volée. Vérifiez les versions :

```powershell
az version --query '"azure-cli"' -o tsv; gh --version | Select-Object -First 1; node --version
$PSVersionTable.PSVersion.ToString(); & ./tools/apiops-cli/node_modules/.bin/apiops.cmd --version
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell affichant les numéros de version d'Azure CLI, GitHub CLI, Node.js, PowerShell et APIops CLI](../../assets/img/lab-00/00-01-tool-versions.png)
<figcaption>Versions des outils dans l'exécution enregistrée. Des versions plus récentes conviennent; l'APIops CLI doit être en 1.0.4.</figcaption>
</figure>

!!! success "Résultat attendu"
    Cinq lignes de version, `v22` pour Node.js et `1.0.4` pour l'APIops CLI. `npm ci` n'affiche aucun avertissement `EBADENGINE`.

### Étape 4 : Prévisualiser la configuration avec -WhatIf

Le script de configuration est idempotent et ne supprime jamais rien. Prévisualisez toujours d'abord :

```powershell
./scripts/apim-007-setup/Initialize-Apim007Environment.ps1 -Stage Initial `
    -SubscriptionId $SubscriptionId -TenantId $TenantId -Location $Location `
    -GitHubRepository $Repo -BudgetAmount 150 -BudgetAlertEmail '<you@example.com>' `
    -ExpiresOn (Get-Date).AddDays(30).ToString('yyyy-MM-dd') -ProdReviewers $Reviewer -WhatIf
```

Revoyez le tableau des coûts, le budget, les attributions de rôles et leurs conditions ABAC, ainsi que les protections des environnements GitHub.

!!! cost "Ce que ça coûte"
    Deux services API Management Basic v2 constituent le coût principal. Les plans App Service B1, un registre de conteneurs Basic, l'ingestion Log Analytics et (à partir de l'atelier 7) Azure OpenAI et Content Safety facturés à l'usage ajoutent peu. Le budget vous alerte au montant choisi; démantelez avec l'[atelier 10](lab-10-teardown.md) une fois terminé.

### Étape 5 : Appliquer la configuration

Exécutez la même commande sans `-WhatIf`. Si vous présentez seul et devez approuver vos propres versions en prod, ajoutez `-PreventSelfReview $false` et dites-le lors de la présentation : c'est un contrôle réduit.

```powershell
./scripts/apim-007-setup/Initialize-Apim007Environment.ps1 -Stage Initial `
    -SubscriptionId $SubscriptionId -TenantId $TenantId -Location $Location `
    -GitHubRepository $Repo -BudgetAmount 150 -BudgetAlertEmail '<you@example.com>' `
    -ExpiresOn (Get-Date).AddDays(30).ToString('yyyy-MM-dd') -ProdReviewers $Reviewer
```

### Étape 6 : Vérifier les groupes de ressources, les identités et les environnements

```powershell
az group list --tag apimDemo=007 --query "[].{name:name, location:location, environment:tags.environment, expiresOn:tags.expiresOn}" -o table
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell listant cinq groupes de ressources étiquetés apimDemo=007 : shared, dev-apim, dev-backends, prod-apim, prod-backends](../../assets/img/lab-00/00-02-resource-groups.png)
<figcaption>Cinq groupes de ressources étiquetés. Chaque workflow refuse de toucher un groupe sans l'étiquette <code>apimDemo=007</code>.</figcaption>
</figure>

```powershell
az identity list -g rg-apim-demo-007-shared --query "[].name" -o tsv | Sort-Object
gh api "repos/$Repo/environments?per_page=100" --jq '.environments[] | select(.name | test("007")) | [.name, ([.protection_rules[].type] | join("+"))] | @tsv'
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell listant neuf identités id-apim007 et les neuf environnements GitHub 007 avec leurs règles de protection](../../assets/img/lab-00/00-03-identities.png)
<figcaption>Une identité par environnement GitHub. <code>prod-007</code> et <code>prod-007-teardown</code> exigent un réviseur.</figcaption>
</figure>

| Identité | Peut faire |
|----------|--------|
| `id-apim007-build` | Pousser des images dans le registre seulement |
| `id-apim007-<env>-infra` | Déployer les groupes de l'environnement; accorder seulement les rôles de publication et les rôles de données IA |
| `id-apim007-<env>-release` | Publier sur son propre APIM et déployer ses propres applications |
| `id-apim007-prod-plan` | Lire la prod et le dev (plan seulement) |
| `id-apim007-<env>-teardown` | Supprimer les ressources de son propre environnement |

!!! checkpoint "Point de contrôle"
    Cinq groupes de ressources, neuf identités, neuf environnements et la variable de dépôt `APIM007_ENABLED` à `true` (`gh variable list --repo $Repo`).
