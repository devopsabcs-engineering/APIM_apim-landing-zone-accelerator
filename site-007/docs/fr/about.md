---
title: À propos de ces ateliers
description: Qui a construit les ateliers APIOps 007, comment les preuves ont été capturées et comment construire le site localement.
---

# À propos de ces ateliers

APIOps 007 est un atelier construit sur l'[accélérateur de zone d'atterrissage APIM](https://github.com/devopsabcs-engineering/APIM_apim-landing-zone-accelerator) par l'équipe devopsabcs-engineering. Il montre l'approche [Azure APIOps](https://github.com/Azure/apiops) avec l'APIops CLI du groupe de produit, appliquée à une promotion du dev vers la prod avec approbations, retour arrière, GitOps par extraction et passerelle IA.

## Comment les preuves ont été capturées

* **Captures de terminal** : elles exécutent de vraies commandes en lecture seule et rendent la sortie avec Microsoft Edge sans interface. Les identifiants sont masqués et les clés n'apparaissent jamais.
* **Captures GitHub** : elles proviennent des vraies exécutions de workflow, versions et demandes de tirage.
* **Animations** : du SVG écrit à la main avec animation CSS, en anglais et en français, qui respecte le paramètre *mouvement réduit*.

Les scripts de capture se trouvent dans `site-007/scripts/`.

## Construire le site localement

```powershell
Set-Location site-007
python -m pip install -r requirements.txt
mkdocs serve
```

Ouvrez `http://127.0.0.1:8000/`. `mkdocs build --strict` doit réussir avant une demande de tirage, avec `python scripts/check_parity.py` et `python scripts/check_images.py`.

## Licence

Contenu sous la licence MIT du dépôt. Azure, GitHub et Microsoft Edge sont des marques de commerce de Microsoft.
