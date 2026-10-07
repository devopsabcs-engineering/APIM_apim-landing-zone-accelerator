---
title: "Atelier 6 : Retour arrière, retour en avant et tests d'échec"
description: Redéployez un candidat propre antérieur par son étiquette, revenez à main, et prouvez que les étiquettes non fiables et les barrières en échec arrêtent le pipeline avant la prod.
---

# Atelier 6 : Retour arrière, retour en avant et tests d'échec

<span class="chip phase-test"><span aria-hidden="true">⏪</span> Retour arrière</span> <span class="chip phase-idea">35 min</span> <span class="chip phase-plan">Avancé</span>

## Aperçu

<div class="lab-meta" markdown>

| Élément | Détails |
|------|---------|
| **Durée** | 35 minutes |
| **Niveau** | Avancé |
| **Prérequis** | [Atelier 5](lab-05-extraction-gitops.md) terminé, au moins deux candidats propres dans l'historique |
| **Point de contrôle** | Les deux environnements de retour sur le candidat de `main` après un retour arrière et un retour en avant |
| **Atelier suivant** | [Atelier 7 : Infrastructure IA](lab-07-ai-infrastructure.md) |

</div>

Le retour arrière est une version normale d'un candidat plus ancien : mêmes tests, même approbation. Seuls les candidats enregistrés comme `clean` dans l'historique du dev ou de la prod sont fiables; une ressource de version seule ne suffit jamais.

## Objectifs d'apprentissage

À la fin de cet atelier, vous saurez :

* Ramener les deux environnements à une étiquette de candidat précédente.
* Revenir en avant en publiant de nouveau `main`.
* Montrer qu'une étiquette inconnue ou non fiable et une barrière dev en échec n'atteignent jamais la prod.

## Étapes

### Étape 1 : Revenir au candidat de référence

```powershell
gh workflow run release-apiops-007.yml --repo $Repo -f rollback_candidate_tag=apim007-candidate-6-51da660
```

Les travaux de construction, de poussée et de gel sont sautés. `Deploy dev-007` vérifie que l'étiquette et son SHA256 figurent dans un historique d'état de version, puis déploie. Approuvez la prod comme d'habitude. Les deux passerelles renvoient de nouveau `baseline-a`.

### Étape 2 : Revenir en avant

```powershell
gh workflow run release-apiops-007.yml --repo $Repo
```

Une exécution depuis `main` sans paramètre construit un nouveau candidat à partir du paquet actuel. Approuvez la prod; les deux passerelles renvoient `candidate-b`.

### Étape 3 : Essayer une étiquette non fiable

```powershell
gh workflow run release-apiops-007.yml --repo $Repo -f rollback_candidate_tag=apim007-candidate-999-0000000
```

!!! success "Résultat attendu"
    `Deploy dev-007` échoue à l'étape du condensé de confiance, **avant** de marquer quoi que ce soit comme en déploiement. Les travaux de prod sont sautés.

### Étape 4 : Simuler une barrière dev en échec

```powershell
gh workflow run release-apiops-007.yml --repo $Repo -f simulate_dev_gate_failure=true
```

Le test de passerelle dev attend une valeur de version que le candidat ne définit pas; le dev échoue donc après la publication : l'état du dev devient `dirty`, et `Plan prod-007` et `Deploy prod-007` sont sautés. Rétablissez avec une version normale depuis `main`.

### Étape 5 : Revoir les preuves

```powershell
foreach ($id in 37618926825, 37619952350, 37620134897, 37621756882, 37621889176, 37622061716) {
    gh run view $id --repo $Repo --json workflowName,displayTitle,conclusion,event --jq '[.workflowName, .event, .conclusion, .displayTitle] | @tsv'
}
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell listant six exécutions : retour arrière réussi, refus d'extraction en échec, retour en avant réussi, deux échecs d'étiquette non fiable et l'échec de barrière simulé](../../assets/img/lab-06/06-01-rollback-runs.png)
<figcaption>Vert là où ça doit passer, rouge là où ça doit s'arrêter.</figcaption>
</figure>

```powershell
gh run view 37621889176 --repo $Repo --log-failed | Select-String "Release gate blocked|is not in a release-state"
```

<figure class="screenshot-frame" markdown>
![Fenêtre PowerShell montrant l'erreur indiquant que l'étiquette du candidat n'est dans l'historique de confiance ni du dev ni de la prod](../../assets/img/lab-06/06-02-untrusted-tag.png)
<figcaption>Une étiquette bien formée absente des deux historiques est refusée avant toute écriture.</figcaption>
</figure>

!!! loop "Le retour arrière n'est pas une restauration atomique"
    Le retour arrière republie un ancien paquet avec tous les tests. Il ne supprime pas les ressources qu'un candidat plus récent a ajoutées (par exemple une API supplémentaire). Retirez-les par une demande de tirage.

!!! checkpoint "Point de contrôle"
    Les deux environnements `clean` sur le candidat de `main`, et les exécutions d'échec en rouge là où prévu.
