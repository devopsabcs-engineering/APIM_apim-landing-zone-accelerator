---
title: "Atelier 8 : Publication et tests de la passerelle IA"
description: Ajoutez au paquet l'API IA, les produits d'équipe avec limites de jetons, Content Safety et les métriques de jetons, publiez-le en dev puis en prod et lisez les cinq tests IA automatisés.
---

# Atelier 8 : Publication et tests de la passerelle IA

<span class="chip phase-deploy"><span aria-hidden="true">🧠</span> Publication IA</span> <span class="chip phase-idea">35 min</span> <span class="chip phase-plan">Avancé</span>

## Aperçu

<div class="lab-meta" markdown>

| Élément | Détails |
|------|---------|
| **Durée** | 35 minutes |
| **Niveau** | Avancé |
| **Prérequis** | [Atelier 7](lab-07-ai-infrastructure.md) terminé |
| **Point de contrôle** | Une version où `AI gateway subscriptions and tests` a réussi en dev et en prod |
| **Atelier suivant** | [Atelier 9 : Promotion IA et refacturation](lab-09-ai-promotion-showback.md) |

</div>

La passerelle IA n'est qu'une partie de plus du paquet : une API, deux backends, deux produits et six valeurs nommées. Le workflow de publication ajoute une étape qui crée les abonnements d'équipe et exécute cinq tests.

## Objectifs d'apprentissage

À la fin de cet atelier, vous saurez :

* Lire la stratégie de l'API IA et les stratégies des produits d'équipe.
* Expliquer pourquoi les limites et les seuils sont des valeurs nommées remplies par les substitutions.
* Lire les cinq tests IA et ce que chacun prouve.

## Étapes

### Étape 1 : Lire la stratégie de l'API IA

```powershell
Get-Content artifacts.007/apis/ai-gateway/policy.xml
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell montrant la stratégie de la passerelle IA : suppression de l'en-tête api-key, backend ai-foundry, authentication-managed-identity, llm-content-safety, llm-emit-token-metric et les en-têtes x-demo](../../assets/img/lab-08/08-01-ai-policy.png)
<figcaption>Entrée : retirer la clé du client, router vers le modèle avec l'identité managée, filtrer avec Content Safety, émettre les métriques de jetons.</figcaption>
</figure>

| Stratégie | Rôle |
|--------|------|
| `set-header ... delete` | La clé d'équipe n'atteint jamais le modèle |
| `set-backend-service` + `authentication-managed-identity` | Appel sans clé à Azure OpenAI |
| `llm-content-safety` | Boucliers d'invite, quatre catégories de préjudice à `{{ai-safety-threshold}}`, liste de blocage `{{ai-safety-blocklist}}` |
| `llm-emit-token-metric` | Jetons d'invite, de complétion et totaux avec les dimensions API, abonnement et produit |
| `on-error` | Un blocage Content Safety renvoie `403` avec `x-content-safety-decision: blocked` |

!!! note "Le client envoie api-version"
    La stratégie ne définit pas `api-version` : l'extracteur de l'APIops CLI masque les valeurs littérales de `set-query-parameter`, ce qui casserait la comparaison d'extraction. Les clients le passent dans la chaîne de requête.

### Étape 2 : Lire les produits d'équipe et les paramètres

```powershell
Get-Content artifacts.007/products/team-finance/policy.xml
Get-Content configuration.007.ai-settings.json
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell montrant la stratégie llm-token-limit par abonnement avec des valeurs nommées, et le JSON des paramètres IA avec les limites dev et prod par équipe](../../assets/img/lab-08/08-02-product-policy.png)
<figcaption>Chaque produit d'équipe limite les jetons par minute et par jour, par abonnement. Les nombres viennent du fichier de paramètres, par environnement.</figcaption>
</figure>

### Étape 3 : Le publier

Fusionnez la demande de tirage du paquet. La publication se déroule comme dans l'[atelier 3](lab-03-baseline-release.md), avec une étape de plus dans chaque travail de déploiement :

1. `Set-Apim007TeamSubscriptions.ps1` crée `sub-team-retail` et `sub-team-finance`, limités à leurs produits. Les abonnements ne sont jamais stockés dans le paquet.
2. `Test-Apim007AiGateway.ps1` lit les clés par ARM, les masque et exécute les tests.

!!! gate "L'étape ne s'exécute que pour les candidats IA"
    L'étape vérifie que l'inventaire du candidat déclare `aiSettings`. Un candidat sans le paquet IA (par exemple un retour arrière) la saute. Cette garde a été ajoutée après l'exécution rejetée de l'[atelier 3](lab-03-baseline-release.md#etape-3-approuver-la-prod).

### Étape 4 : Lire les cinq tests

```powershell
./scripts/apim-007/Test-Apim007AiGateway.ps1 -ManifestPath $env:TEMP\manifest-dev.json -SettingsPath configuration.007.ai-settings.json `
    -PolicyPath artifacts.007/apis/ai-gateway/policy.xml -WorkspaceCustomerId <log-analytics-workspace-id>
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell montrant les résultats des tests IA en dev : retail 200 avec consommation de jetons, sans clé 401, rafale finance 429, Content Safety 403 bloqué et lignes de métriques de jetons](../../assets/img/lab-08/08-03-ai-tests.png)
<figcaption>Le même script s'exécute dans le pipeline, en dev puis en prod.</figcaption>
</figure>

| Test | Attend | Prouve |
|------|---------|--------|
| T1 | Sans clé → `401` | L'API exige un abonnement d'équipe |
| T2 | Retail → `200`, consommation de jetons, `remaining-tokens` | L'appel par identité managée fonctionne et la stratégie de limite s'exécute |
| T3 | Rafale finance → `429` avec `Retry-After` | Les limites de jetons par équipe sont appliquées |
| T4 | Terme de la liste de blocage → `403 blocked` | Content Safety filtre les invites avant le modèle |
| T5 | Lignes de métriques de jetons dans `AppMetrics` | Les données de refacturation arrivent (avertissement seulement, l'ingestion peut tarder) |

!!! checkpoint "Point de contrôle"
    L'exécution de publication montre `AI gateway subscriptions and tests` au vert dans `Deploy dev-007` et `Deploy prod-007` (exécution enregistrée `37660072964`).
