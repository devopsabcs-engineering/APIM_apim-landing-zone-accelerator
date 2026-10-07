---
title: Plan des ateliers
description: Les onze ateliers APIOps 007, dans l'ordre, avec ce que chacun construit et les preuves qu'il produit.
---

# Plan des ateliers

Les ateliers s'enchaînent. Faites-les dans l'ordre la première fois. Chaque atelier se termine par un **point de contrôle** à vérifier avant de continuer.

<div class="path-grid" markdown>

| Atelier | Vous construisez | Vous prouvez |
|-----|-----------|-----------|
| [0 Configuration](lab-00-setup.md) | Outils, identités, environnements GitHub, budget | Des identités fédérées aux rôles minimaux |
| [1 Infrastructure](lab-01-infrastructure.md) | Registre, deux services APIM Basic v2, backends | Un manifeste cible dérivé de déploiements fixes |
| [2 Paquet](lab-02-bundle.md) | `artifacts.007/`, filtre de propriété, inventaire | Un seul paquet, deux fichiers de substitution |
| [3 Première version](lab-03-baseline-release.md) | Un candidat figé déployé en dev, puis en prod | Barrière d'approbation, état de version, reçus |
| [4 A vers B](lab-04-promotion-a-to-b.md) | Un changement de stratégie visible | Le dev change d'abord, la prod seulement après approbation |
| [5 Extraction](lab-05-extraction-gitops.md) | Une modification du portail ramenée dans Git | Détection de dérive et une branche limitée aux stratégies |
| [6 Retour arrière](lab-06-rollback.md) | Retour arrière, retour en avant, refus | Seuls les candidats de confiance sont redéployés |
| [7 Infrastructure IA](lab-07-ai-infrastructure.md) | Azure OpenAI et Content Safety par environnement | Accès sans clé avec identité managée |
| [8 Publication IA](lab-08-ai-release.md) | API IA, produits d'équipe, limites de jetons | 401 / 200 / 429 / 403 et métriques de jetons |
| [9 Promotion IA](lab-09-ai-promotion-showback.md) | Promotion `ai-b` et changement de quota en prod | Refacturation par équipe |
| [10 Démantèlement](lab-10-teardown.md) | Suppression d'un environnement par ID exact | Rien hors de l'atelier n'est touché |

</div>

## Structure de chaque atelier

* **Aperçu** : durée, niveau, prérequis et point de contrôle.
* **Étapes** : du PowerShell à copier-coller, puis un encadré *Résultat attendu*.
* **Preuves** : le vrai résultat ou la vraie capture de l'exécution enregistrée.

!!! tip "Définissez vos variables de session une fois"
    Tous les ateliers utilisent les mêmes variables PowerShell. L'atelier 0 montre comment les définir. Si vous ouvrez un nouveau terminal, collez de nouveau ce bloc.

## Deux façons de suivre

* **Pratique** : vous exécutez tout dans votre propre abonnement et votre copie du dépôt. Prévoyez environ 6 heures et quelques dollars US par jour tant que les environnements existent (deux instances API Management Basic v2 dominent le coût).
* **Lecture** : vous suivez l'exécution enregistrée à travers les preuves. Chaque atelier montre les vrais résultats, pour apprendre le modèle sans rien déployer.
