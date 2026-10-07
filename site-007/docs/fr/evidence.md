---
title: Index des preuves
description: Chaque exécution de workflow, candidat, demande de tirage et mesure de l'exécution enregistrée d'APIOps 007, avec un lien vers l'atelier qui l'explique.
---

# Index des preuves

Tous les résultats de ce site proviennent d'une exécution enregistrée sur `dev-007` et `prod-007` les 6 et 7 octobre 2026. Les numéros d'exécution sont des ID d'exécution GitHub Actions dans [devopsabcs-engineering/APIM_apim-landing-zone-accelerator](https://github.com/devopsabcs-engineering/APIM_apim-landing-zone-accelerator/actions).

## Pipeline de promotion

| Preuve | Valeur | Atelier |
|----------|-------|-----|
| Capture des contrats | Exécution `37554025334` | [2](labs/lab-02-bundle.md) |
| Version de référence A | Exécution `37610973282`, candidat `apim007-candidate-6-51da660`, `baseline-a` dans les deux | [3](labs/lab-03-baseline-release.md) |
| Promotion A vers B | Exécution `37616892784` : le dev affichait `candidate-b` pendant que la prod affichait encore `baseline-a` | [4](labs/lab-04-promotion-a-to-b.md) |
| Extraction vers une branche | Exécution `37618679494` : une modification du portail dev projetée dans `apis/weather/policy.xml` | [5](labs/lab-05-extraction-gitops.md) |
| Retour arrière par étiquette | Exécution `37618926825` vers `apim007-candidate-6-51da660` | [6](labs/lab-06-rollback.md) |
| Refus d'extraction | Exécution `37619952350` : « dev is not running main » | [5](labs/lab-05-extraction-gitops.md) |
| Retour en avant | Exécution `37620134897` depuis `main` | [6](labs/lab-06-rollback.md) |
| Étiquettes non fiables | Exécutions `37621756882` (aucune version) et `37621889176` (absente de l'historique) | [6](labs/lab-06-rollback.md) |
| Échec simulé de la barrière dev | Exécution `37622061716`; rétablie par `37622712361` | [6](labs/lab-06-rollback.md) |
| Répétition du démantèlement dev | Exécution `37624727789`; restaurée par l'exécution d'infrastructure `37626106546` | [10](labs/lab-10-teardown.md) |

## Passerelle IA

| Preuve | Valeur | Atelier |
|----------|-------|-----|
| Provisionnement IA | Exécutions d'infrastructure `37652034002` (dev) et `37652742332` (prod) | [7](labs/lab-07-ai-infrastructure.md) |
| Déploiement prod rejeté | Exécution `37658029033` : scripts IA sans le paquet IA; garde ajoutée dans la PR n° 29 | [3](labs/lab-03-baseline-release.md), [8](labs/lab-08-ai-release.md) |
| Version IA de référence | Exécution `37660072964`, candidat 18 : T1-T5 réussis en dev et en prod | [8](labs/lab-08-ai-release.md) |
| IA A vers B | Exécution `37663312626`, candidat 19 : dev `ai-b` pendant que la prod était `baseline-ai`, puis prod `ai-b` | [9](labs/lab-09-ai-promotion-showback.md) |
| Extraction sans dérive | Exécution `37665255654` avec les stratégies de produits possédées | [5](labs/lab-05-extraction-gitops.md) |
| Projection d'une stratégie de produit | Exécution `37665497460`, branche `apim007/extract-37665497460` | [5](labs/lab-05-extraction-gitops.md) |
| Refacturation (`Total Tokens`, 1 jour) | dev : team-finance 2072, team-retail 206; prod : team-finance 1097, team-retail 86 (incluant les appels de capture des preuves) | [9](labs/lab-09-ai-promotion-showback.md) |

## Demandes de tirage et éléments de travail

| Demandes de tirage | Portée |
|---------------|-------|
| N° 14 à 24 | Pipeline de promotion, correctifs trouvés à l'exécution, guide d'exploitation (fonctionnalité 4802) |
| N° 25 | Infrastructure IA (récit 4809) |
| N° 26 | Scripts et tests de publication IA (récit 4811) |
| N° 27, 28, 29 | Intégration des workflows IA et garde de l'étape IA (récit 4812) |
| N° 30 | Paquet IA (récit 4810) |
| N° 31, 32 | Promotion `ai-b`, guide d'exploitation et preuves (récit 4813) |

## Problèmes trouvés et corrigés à l'exécution

* Un code de sortie natif résiduel après une recherche `az` « not found » tolérée a fait échouer la première version dev (PR n° 16).
* `approvalRequired` est refusé sur un produit sans abonnement; des valeurs par défaut du serveur (`isAgent`, type `http` omis, groupe intégré `administrators`) ont dû être normalisées dans la comparaison d'extraction.
* `peter-evans/create-pull-request` ne figure pas dans la liste des actions autorisées de l'organisation; l'extraction pousse maintenant une branche avec `git`.
* L'extracteur masque les valeurs littérales de `set-query-parameter`; la stratégie IA ne définit donc pas `api-version`.
* Une limite finance de prod de 2000 jetons par minute ne pouvait pas atteindre `429` en 10 appels; la finance de prod est à 500.
* L'étape de publication IA s'exécutait au départ dès que les scripts existaient; elle exige maintenant `aiSettings` dans l'inventaire du candidat.
