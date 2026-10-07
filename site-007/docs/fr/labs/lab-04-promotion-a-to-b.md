---
title: "Atelier 4 : Promotion A vers B"
description: Changez un en-tête de stratégie visible de baseline-a à candidate-b, montrez le dev avec la nouvelle valeur pendant que la prod a encore l'ancienne, puis approuvez et montrez la prod rattraper le dev.
---

# Atelier 4 : Promotion A vers B

<span class="chip phase-sign"><span aria-hidden="true">🔀</span> Promotion</span> <span class="chip phase-idea">25 min</span> <span class="chip phase-plan">Intermédiaire</span>

## Aperçu

<div class="lab-meta" markdown>

| Élément | Détails |
|------|---------|
| **Durée** | 25 minutes |
| **Niveau** | Intermédiaire |
| **Prérequis** | [Atelier 3](lab-03-baseline-release.md) terminé, les deux environnements `clean` |
| **Point de contrôle** | Les deux passerelles renvoient `x-demo-release: candidate-b` |
| **Atelier suivant** | [Atelier 5 : GitOps par extraction](lab-05-extraction-gitops.md) |

</div>

C'est le moment fort de la démo : le même changement est visible en dev alors que la prod sert encore la version précédente, jusqu'à ce qu'un humain approuve.

## Objectifs d'apprentissage

À la fin de cet atelier, vous saurez :

* Faire un changement de configuration observable par une demande de tirage.
* Prouver avec les en-têtes de réponse quelle version sert chaque environnement.
* Montrer à partir de l'historique d'exécution que la prod a attendu le réviseur.

## Étapes

### Étape 1 : Vérifier les en-têtes de version actuels

Chaque stratégie d'API définit trois en-têtes de réponse : `x-demo-environment`, `x-demo-release` et `x-demo-backend-host`.

```powershell
$Gateways = '<dev-apim-name>', '<prod-apim-name>'
foreach ($g in $Gateways) {
    "== $g"
    (Invoke-WebRequest "https://$g.azure-api.net/weather/api/Version" -SkipHttpErrorCheck).Headers.GetEnumerator() |
        Where-Object Key -like 'x-demo-*' | ForEach-Object { "$($_.Key): $($_.Value)" }
}
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell montrant les en-têtes x-demo-environment, x-demo-release et x-demo-backend-host renvoyés par les passerelles dev et prod](../../assets/img/lab-04/04-01-gateway-headers.png)
<figcaption>Chaque environnement indique son propre nom et son propre hôte backend, et la même valeur de version.</figcaption>
</figure>

### Étape 2 : Passer de A à B par une demande de tirage

```powershell
git switch -c feature/<work-item>-candidate-b
foreach ($p in 'artifacts.007/apis/weather/policy.xml', 'artifacts.007/apis/software-version/policy.xml') {
    (Get-Content $p -Raw).Replace('<value>baseline-a</value>', '<value>candidate-b</value>') | Set-Content $p -NoNewline
}
git commit -am "feat(artifacts): promote candidate-b AB#<work-item>"
git push -u origin HEAD
gh pr create --repo $Repo --fill
```

Fusionnez la demande de tirage quand les vérifications réussissent. La publication démarre automatiquement.

### Étape 3 : Montrer le dev en avance sur la prod

Pendant que `Deploy prod-007` attend l'approbation, exécutez de nouveau la boucle de l'étape 1.

!!! success "Résultat attendu"
    Le dev renvoie `x-demo-release: candidate-b`. La prod renvoie encore `baseline-a`.

### Étape 4 : Approuver et montrer la prod rattraper le dev

Approuvez `prod-007` (atelier 3, étape 3), attendez la fin de l'exécution et relancez la boucle : les deux renvoient `candidate-b`.

```powershell
gh run view 37616892784 --repo $Repo --json jobs --jq '.jobs[] | [.name, .conclusion, .startedAt, .completedAt] | @tsv'
gh api repos/$Repo/actions/runs/37616892784/approvals --jq '.[] | [.environments[0].name, .state, .user.login] | @tsv'
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell avec la chronologie des travaux de l'exécution A vers B, montrant Deploy dev-007 terminé bien avant le début de Deploy prod-007, et l'approbation de prod-007](../../assets/img/lab-04/04-02-promotion-timeline.png)
<figcaption>Exécution <code>37616892784</code> : le dev était terminé bien avant le début de la prod, et la prod n'a démarré qu'après l'approbation.</figcaption>
</figure>

!!! checkpoint "Point de contrôle"
    Les deux passerelles renvoient `candidate-b`, et les deux états de version enregistrent le nouveau candidat comme `clean`.
