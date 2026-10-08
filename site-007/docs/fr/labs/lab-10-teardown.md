---
title: "Atelier 10 : Démantèlement et nettoyage"
description: Supprimez un ou deux environnements par ID de ressource exact, gérez les ressources supprimées de façon réversible, remettez Azure à zéro et recommencez les ateliers depuis l'atelier 0.
---

# Atelier 10 : Démantèlement et nettoyage

<span class="chip phase-human"><span aria-hidden="true">🧹</span> Démantèlement</span> <span class="chip phase-idea">20 min</span> <span class="chip phase-plan">Intermédiaire</span>

## Aperçu

<div class="lab-meta" markdown>

| Élément | Détails |
|------|---------|
| **Durée** | 20 minutes |
| **Niveau** | Intermédiaire |
| **Prérequis** | N'importe quel atelier précédent |
| **Point de contrôle** | L'étape *Verify removal* réussit; l'autre environnement est intact |
| **Suite** | [Index des preuves](../evidence.md) |

</div>

Le démantèlement ne supprime jamais de groupe de ressources et n'utilise jamais de caractères génériques. Il dérive les ID de ressources exacts des déploiements fixes, vérifie chaque étiquette, puis supprime seulement ces ID.

## Objectifs d'apprentissage

À la fin de cet atelier, vous saurez :

* Démanteler un environnement avec une confirmation explicite.
* Lire l'inventaire supprimé et la liste de suivi pour le Propriétaire.
* Récupérer après la suppression réversible d'API Management et des comptes IA.
* Remettre l'abonnement et le dépôt à zéro, puis recommencer depuis l'atelier 0.

## Étapes

### Étape 1 : Démanteler le dev

```powershell
gh workflow run teardown-apim-007.yml --repo $Repo -f environment=dev -f confirm=delete-apim-007-dev
```

Le démantèlement de la prod exige `confirm=delete-apim-007-prod` et l'approbation d'un réviseur sur `prod-007-teardown`.

Pour supprimer les deux environnements en une seule exécution, choisissez `all`. L'exécution lance un travail par environnement; le travail de prod attend toujours son réviseur :

```powershell
gh workflow run teardown-apim-007.yml --repo $Repo -f environment=all -f confirm=delete-apim-007-all
```

### Étape 2 : Lire l'inventaire et le résultat

```powershell
gh run view <run-id> --repo $Repo --json jobs --jq '.jobs[].steps[] | [.name, .conclusion] | @tsv'
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell listant les étapes du démantèlement : vérifier la confirmation, construire l'inventaire exact, supprimer les ressources par ID, vérifier la suppression, résumé de suivi pour le Propriétaire](../../assets/img/lab-10/10-01-teardown-run.png)
<figcaption>Exécution <code>37624727789</code> : la répétition du démantèlement du dev.</figcaption>
</figure>

<figure class="screenshot-frame" markdown>
![Page d'exécution GitHub Actions de Teardown APIM 007 pour le dev avec l'inventaire des ID de ressources supprimés dans le résumé](../../assets/img/lab-10/10-02-gh-teardown-run.png)
<figcaption>Le résumé liste chaque ID supprimé et les actions de suivi pour le Propriétaire.</figcaption>
</figure>

### Étape 3 : Gérer les ressources supprimées de façon réversible

API Management et les comptes IA restent en suppression réversible pendant 48 heures, et leurs noms dérivent du groupe de ressources : reprovisionner le même environnement échoue tant que ces enregistrements existent. Aucun workflow ne les purge; le Propriétaire le fait volontairement :

```powershell
az apim deletedservice purge --service-name <apim-name> --location $Location
az cognitiveservices account purge --location canadaeast --resource-group rg-apim-demo-007-dev-apim --name <account-name>
```

Restaurez ensuite l'environnement avec `infra-apim-007.yml` (`target=dev`) et une version depuis `main`.

### Étape 4 : Remettre Azure à zéro

Faites-le à la fin, ou avant de recommencer les ateliers depuis le début. Seul le Propriétaire peut exécuter ces commandes; aucun workflow n'en a les droits, par conception. Respectez l'ordre : les enregistrements supprimés de façon réversible doivent être retirés pendant que leurs groupes de ressources existent encore.

1. Démantelez les deux environnements et approuvez le travail de prod sur `prod-007-teardown` :

    ```powershell
    gh workflow run teardown-apim-007.yml --repo $Repo -f environment=all -f confirm=delete-apim-007-all
    ```

2. Purgez les services API Management et les comptes IA supprimés de façon réversible :

    ```powershell
    az apim deletedservice list -o json | ConvertFrom-Json | Where-Object name -like 'apim-*-007-*' |
        ForEach-Object { az apim deletedservice purge --service-name $_.name --location $Location -o none }
    az cognitiveservices account list-deleted -o json | ConvertFrom-Json | Where-Object name -like '*-apim007-*' |
        ForEach-Object { az cognitiveservices account purge --name $_.name --location $_.location --resource-group ($_.id -split '/')[8] -o none }
    ```

3. Supprimez définitivement les espaces de travail Log Analytics. Le démantèlement les laisse en suppression réversible pendant 14 jours, et un nouvel espace du même nom ramènerait les anciennes données. Récupérez chacun, puis supprimez-le avec `--force` :

    ```powershell
    az monitor log-analytics workspace list-deleted-workspaces -o json | ConvertFrom-Json | Where-Object name -like 'log-apim-*-007-*' |
        ForEach-Object {
            $rg = ($_.id -split '/')[4]
            az monitor log-analytics workspace recover -g $rg -n $_.name -o none
            az monitor log-analytics workspace delete -g $rg -n $_.name --force true -y -o none
        }
    ```

4. Supprimez les cinq groupes de ressources et le budget. La suppression des groupes retire aussi les identités, leurs informations d'identification fédérées, le registre et les attributions de rôles limitées à ces groupes. Comptez de 10 à 30 minutes :

    ```powershell
    az group list --tag apimDemo=007 --query "[].name" -o tsv | ForEach-Object { az group delete -n $_ --yes --no-wait }
    az consumption budget delete --budget-name budget-apim-demo-007
    ```

5. Supprimez les neuf environnements GitHub et les deux variables du dépôt :

    ```powershell
    'apim-007-build', 'apim-007-shared-infra', 'dev-007', 'dev-007-infra', 'dev-007-teardown',
    'prod-007', 'prod-007-infra', 'prod-007-plan', 'prod-007-teardown' |
        ForEach-Object { gh api -X DELETE "repos/$Repo/environments/$_" }
    gh variable delete APIM007_ENABLED --repo $Repo
    gh variable delete APIM007_PREVENT_SELF_REVIEW --repo $Repo
    ```

6. Vérifiez qu'il ne reste rien. Une fois les suppressions de groupes terminées, aucune commande ne renvoie de nom 007 :

    ```powershell
    az group list --tag apimDemo=007 --query "[].name" -o tsv
    az apim deletedservice list --query "[].name" -o tsv
    az cognitiveservices account list-deleted --query "[].name" -o tsv
    az monitor log-analytics workspace list-deleted-workspaces --query "[].name" -o tsv
    gh api "repos/$Repo/environments?per_page=100" --jq '.environments[].name | select(test("007"))'
    ```

La remise à zéro conserve le site GitHub Pages, les versions GitHub et les branches d'extraction. L'historique des versions résidait dans API Management : les anciennes versions ne peuvent donc pas servir à un retour arrière sur les nouveaux services.

### Étape 5 : Recommencer depuis l'atelier 0

Les noms des ressources dérivent des groupes de ressources : la nouvelle exécution réutilise donc les mêmes noms. C'est pourquoi l'étape 4 purge d'abord les enregistrements supprimés de façon réversible.

1. [Atelier 0](lab-00-setup.md), étapes 4 à 6 : exécutez `-Stage Initial` avec `-WhatIf`, puis appliquez-le avec une nouvelle date `-ExpiresOn`. Il recrée les groupes de ressources, les identités, les rôles, le budget, les environnements GitHub et les variables.
2. [Atelier 1](lab-01-infrastructure.md), étape 2 : exécutez le workflow d'infrastructure avec `target=shared`, puis `-Stage PostRegistry` avec le nom du registre indiqué dans le résumé de l'exécution.
3. [Atelier 1](lab-01-infrastructure.md), étape 3 : provisionnez le dev, puis la prod.
4. Poursuivez avec l'[atelier 2](lab-02-bundle.md) et les suivants.

!!! checkpoint "Point de contrôle"
    *Verify removal* a réussi, et la passerelle de l'autre environnement répond toujours. Après une remise à zéro complète, les vérifications de l'étape 4 ne renvoient aucun nom 007.
