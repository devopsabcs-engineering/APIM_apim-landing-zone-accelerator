---
title: Dépannage
description: Solutions aux problèmes rencontrés dans l'exécution enregistrée d'APIOps 007 - workflows, versions, extraction, passerelle IA et outillage local.
---

# Dépannage

## Workflows et versions

| Symptôme | Cause et solution |
|---------|---------------|
| Tous les travaux 007 sont sautés | La variable de dépôt `APIM007_ENABLED` n'est pas `true`. Terminez le script de configuration (atelier 0). |
| `Signed-in tenant or subscription does not match` | Les variables d'environnement `EXPECTED_TENANT_ID` / `EXPECTED_SUBSCRIPTION_ID` diffèrent du contexte de l'identité fédérée. Relancez la configuration. |
| L'infrastructure échoue sur un conflit de nom | Un APIM ou un compte IA supprimé de façon réversible détient le nom. Voir l'[atelier 10, étape 3](labs/lab-10-teardown.md#etape-3-gerer-les-ressources-supprimees-de-facon-reversible). |
| `Plan prod-007` échoue sur la protection | `prod-007` a perdu son réviseur, sa politique de branche limitée à `main`, ou permet le contournement par les administrateurs. Relancez la configuration. |
| `deploying owned by an in-progress run` | Une autre version écrit dans cet environnement. Attendez, ou annulez l'autre exécution. |
| La prod `dirty` bloque une version | Relancez les travaux en échec (même candidat) ou revenez à une entrée de l'historique. Ne modifiez jamais l'état à la main. |
| Le gel échoue avec `HTTP 403 Resource not accessible by integration` | Vu une fois et non reproduit. Relancez tout le workflow; vérifiez que le travail a toujours `contents: write`. |
| Une exécution en file a disparu | GitHub garde un seul travail en attente par groupe de concurrence. Relancez-la; rien n'a été déployé. |

## Extraction

| Symptôme | Cause et solution |
|---------|---------------|
| `dev is not running main; release main first` | Le dev exécute un retour arrière ou un candidat plus ancien. Publiez `main`, puis extrayez. |
| La comparaison échoue sur une opération ou un schéma | Seules les stratégies sont projetées. Changez la forme des API par le paquet et une demande de tirage. |
| Aucune demande de tirage n'a été ouverte | Une politique de l'organisation empêche `GITHUB_TOKEN` de créer des demandes de tirage. Ouvrez-la depuis la branche poussée. |

## Passerelle IA

| Symptôme | Cause et solution |
|---------|---------------|
| `401` avec une clé | La clé appartient à un autre produit, ou l'abonnement est suspendu. Relancez `Set-Apim007TeamSubscriptions.ps1`. |
| `500` à l'appel du modèle | L'identité d'APIM n'a pas *Cognitive Services OpenAI User*, ou le rôle n'est pas encore propagé (attendez quelques minutes). |
| T3 n'obtient jamais `429` | Les jetons par minute de l'équipe sont trop élevés pour une rafale de 10 appels. Baissez-les dans `configuration.007.ai-settings.json`. |
| T5 ne trouve aucune métrique | Délai d'ingestion, ou le diagnostic du service n'a pas `metrics: true`. Interrogez `AppMetrics` dans l'espace de travail après quelques minutes. |
| `403 Public access is disabled` depuis votre poste | Normal quand un compte IA n'autorise que l'accès privé; testez plutôt par APIM. |

## Outillage local

| Symptôme | Cause et solution |
|---------|---------------|
| `apiops` introuvable | Exécutez `npm ci --ignore-scripts` dans `tools/apiops-cli` et utilisez `./tools/apiops-cli/node_modules/.bin/apiops.cmd`. |
| `az` échoue sur des parenthèses sous Windows | `az.cmd` est un script batch; mettez les requêtes JMESPath entre guillemets, ou triez et filtrez en PowerShell. |
| Les accents s'affichent mal | Définissez `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`. |
