---
title: Glossaire
description: Les termes APIOps 007 utilisés dans les ateliers, du paquet et du candidat à l'état de version, aux substitutions et aux limites de jetons.
---

# Glossaire

## Termes de promotion

| Terme | Signification |
|------|---------|
| **APIops CLI** | `@azure-tools/apiops-cli`, l'outil en ligne de commande du groupe de produit qui extrait et publie la configuration d'API Management sous forme de fichiers. Épinglé à 1.0.4. |
| **Paquet** | `artifacts.007/` : la configuration API Management neutre, dans la structure de dossiers native de la CLI. |
| **Filtre de propriété** | `configuration.007.ownership.yaml` : les seules ressources que le pipeline peut publier ou extraire. |
| **Inventaire attendu** | `configuration.007.expected-inventory.json` : une liste indépendante de fichiers, d'opérations et de cibles de substitution utilisée par chaque vérification. |
| **Substitutions** | Un fichier JSON généré qui fixe les valeurs par environnement (URL de service, URL de backend, limites IA) à la publication. |
| **Manifeste cible** | Les ID de ressources et URL exacts d'un environnement, dérivés des déploiements fixes `apim007-*-<env>`. |
| **Candidat** | Une préversion GitHub figée et immuable (`apim007-candidate-<run>-<sha>`) contenant le paquet, l'outillage, les scripts et les condensés d'images. |
| **État de version** | La valeur nommée `apim007-release-state` de chaque service APIM : candidat actuel, condensé, statut et historique. |
| **Clean / dirty / deploying** | Statuts de l'état de version : vérifié, inconnu après un échec, ou en cours d'écriture. |
| **Reçu** | Un enregistrement JSON de ce qu'un travail de déploiement a déployé (candidat, condensés, images, preuves IA). |
| **GitOps par extraction** | Extraire le dev, comparer avec le paquet, projeter les modifications de stratégie autorisées dans une branche. |

## Termes de la passerelle IA

| Terme | Signification |
|------|---------|
| **Passerelle IA** | APIM devant Azure OpenAI : clés en périphérie, identité managée vers le modèle, limites, sécurité et métriques. |
| **Produit d'équipe** | `team-retail` ou `team-finance` : un produit APIM avec un abonnement et ses propres limites de jetons. |
| **`llm-token-limit`** | Stratégie APIM qui limite les jetons par minute et par période pour une clé de compteur (ici l'abonnement). |
| **`llm-content-safety`** | Stratégie APIM qui envoie l'invite à Azure AI Content Safety avant le modèle. |
| **`llm-emit-token-metric`** | Stratégie APIM qui émet des métriques de jetons d'invite, de complétion et totaux avec des dimensions personnalisées. |
| **Liste de blocage** | Une liste Content Safety avec un terme de test que les tests utilisent pour déclencher un blocage déterministe. |
| **Refacturation (showback)** | Rapporter la consommation de jetons par équipe à partir des métriques émises. |
