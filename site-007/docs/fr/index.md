---
title: Promouvez Azure API Management du développement à la production avec APIOps
description: Ateliers pratiques qui construisent un pipeline de promotion Azure API Management sur deux environnements avec l'APIops CLI, le GitOps par extraction, le retour arrière et une passerelle IA, avec des preuves réelles à chaque étape.
hide:
  - toc
---

<div class="hero" markdown>

<p class="eyebrow">Ateliers pratiques · EN / FR · Windows + PowerShell + GitHub Actions</p>

# Un seul candidat figé, du développement à la production, sous contrôle humain

<p class="lead">
Vous construirez <strong>APIM 007</strong> : deux services Azure API Management (dev et prod), un dépôt Git qui possède leur configuration, et des workflows GitHub Actions qui promeuvent le <em>même</em> candidat figé du dev vers la prod derrière une approbation, puis l'étendent avec une <strong>passerelle IA</strong> pour Azure OpenAI.
</p>

[Commencer par l'atelier 0](labs/lab-00-setup.md){ .md-button .md-button--primary }
[Voir le plan des ateliers](labs/index.md){ .md-button }

</div>

## L'idée principale

Git est la source de vérité. Un paquet neutre (`artifacts.007/`) décrit les API, les backends, les produits, les stratégies et les valeurs nommées. L'[APIops CLI](https://github.com/Azure/apiops) le publie en dev, le teste, attend une approbation humaine et publie le paquet **identique** en prod. Seuls de petits fichiers de substitution, générés, diffèrent selon l'environnement.

<figure class="anim-frame" markdown>
![Diagramme animé : une demande de tirage est fusionnée dans main, le workflow de publication fige un candidat, le publie sur dev-007, le teste, attend l'approbation et publie le même candidat sur prod-007; une boucle d'extraction ramène les modifications du portail dev dans une demande de tirage](../assets/anim/apiops-flow.fr.svg)
<figcaption>APIOps 007 en une image : construire une fois, promouvoir le même candidat, ramener les changements dans Git.</figcaption>
</figure>

## Le chemin de promotion en un coup d'œil

<ol class="flow-strip" aria-label="Chemin de promotion APIOps 007 : demande de tirage, candidat, dev, plan, approbation, prod, extraction">
  <li class="phase-card phase-idea">
    <span class="ico" aria-hidden="true">🔀</span>
    <span class="tag">Git</span>
    <strong>Demande de tirage</strong>
    <span class="gate">paquet · Pester · lint</span>
  </li>
  <li class="phase-card phase-plan">
    <span class="ico" aria-hidden="true">🧊</span>
    <span class="tag">Gel</span>
    <strong>Candidat</strong>
    <span class="gate">version immuable · SHA256</span>
  </li>
  <li class="phase-card phase-build">
    <span class="ico" aria-hidden="true">🧪</span>
    <span class="tag">Dev</span>
    <strong>dev-007</strong>
    <span class="gate">publication · extraction · tests passerelle</span>
  </li>
  <li class="phase-card phase-test">
    <span class="ico" aria-hidden="true">📋</span>
    <span class="tag">Plan</span>
    <strong>Plan prod</strong>
    <span class="gate">résumé en lecture seule</span>
  </li>
  <li class="phase-card phase-sign">
    <span class="ico" aria-hidden="true">🔐</span>
    <span class="tag">Approbation</span>
    <strong>Réviseur</strong>
    <span class="gate">environnement prod-007</span>
  </li>
  <li class="phase-card phase-deploy">
    <span class="ico" aria-hidden="true">🚀</span>
    <span class="tag">Prod</span>
    <strong>prod-007</strong>
    <span class="gate">même candidat · mêmes tests</span>
  </li>
  <li class="phase-card phase-prod">
    <span class="ico" aria-hidden="true">🔁</span>
    <span class="tag">GitOps</span>
    <strong>Extraction</strong>
    <span class="gate">modif. portail → demande de tirage</span>
  </li>
</ol>

!!! loop "Deux boucles que vous rencontrerez"
    **Retour arrière :** tout candidat antérieur *propre* peut être redéployé par son étiquette, avec les mêmes tests et la même approbation.
    **Extraction :** une modification faite dans le portail dev est extraite, comparée et projetée dans une demande de tirage, pour que Git reste la source de vérité.

## Ensuite : une passerelle IA

Le même pipeline promeut une API de clavardage Azure OpenAI. APIM s'authentifie au modèle avec son identité managée, applique des limites de jetons par équipe, filtre les invites avec Azure AI Content Safety et émet des métriques de jetons pour la refacturation.

<figure class="anim-frame" markdown>
![Diagramme animé : un client appelle la passerelle IA d'APIM avec une clé d'abonnement d'équipe; APIM retire la clé, vérifie la limite de jetons de l'équipe, filtre l'invite avec Content Safety, appelle Azure OpenAI avec son identité managée et émet des métriques de jetons vers Application Insights](../assets/anim/ai-gateway-flow.fr.svg)
<figcaption>La passerelle IA : les clés restent en périphérie, des limites par équipe, la sécurité avant le modèle, les métriques après.</figcaption>
</figure>

## Les ateliers

| Atelier | Titre | Durée | Niveau |
|-----|-------|----------|-------|
| [0](labs/lab-00-setup.md) | Prérequis et configuration initiale | 45 min | Intermédiaire |
| [1](labs/lab-01-infrastructure.md) | Provisionner dev et prod avec Bicep | 40 min | Intermédiaire |
| [2](labs/lab-02-bundle.md) | Le paquet neutre | 30 min | Intermédiaire |
| [3](labs/lab-03-baseline-release.md) | Première version : candidat, dev, approbation, prod | 45 min | Intermédiaire |
| [4](labs/lab-04-promotion-a-to-b.md) | Promotion A vers B | 25 min | Intermédiaire |
| [5](labs/lab-05-extraction-gitops.md) | GitOps par extraction : du portail à la demande de tirage | 30 min | Avancé |
| [6](labs/lab-06-rollback.md) | Retour arrière, retour en avant et tests d'échec | 35 min | Avancé |
| [7](labs/lab-07-ai-infrastructure.md) | Infrastructure de la passerelle IA | 30 min | Avancé |
| [8](labs/lab-08-ai-release.md) | Publication et tests de la passerelle IA | 35 min | Avancé |
| [9](labs/lab-09-ai-promotion-showback.md) | Promotion IA et refacturation des jetons | 25 min | Avancé |
| [10](labs/lab-10-teardown.md) | Démantèlement et nettoyage | 20 min | Intermédiaire |

!!! evidence "Tout ce qui est ici a vraiment été exécuté"
    Chaque capture d'écran, numéro d'exécution et résultat de ce site provient de l'exécution enregistrée les 6 et 7 octobre 2026 sur `dev-007` et `prod-007`. Voir l'[index des preuves](evidence.md).

## À qui s'adressent ces ateliers

* Aux équipes plateforme et API qui exploitent Azure API Management dans plus d'un environnement.
* Aux ingénieurs DevOps qui veulent que la prod reçoive exactement ce que le dev a testé.
* Aux architectes qui évaluent un modèle de passerelle IA pour Azure OpenAI avec refacturation.

Il vous faut une bonne aisance avec PowerShell, Git et GitHub Actions, et le rôle Propriétaire sur un abonnement Azure utilisable pour un atelier.
