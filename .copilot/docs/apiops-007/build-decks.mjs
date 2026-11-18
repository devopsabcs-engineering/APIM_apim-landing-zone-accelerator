import fs from 'node:fs/promises';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(path.join(process.env.TEMP, 'apiops-slide-tools', 'package.json'));
const PptxGenJS = require('pptxgenjs');
const unzipper = require('unzipper');
const { parseStringPromise } = require('xml2js');
const output = path.dirname(fileURLToPath(import.meta.url));
const repo = 'https://github.com/devopsabcs-engineering/APIM_apim-landing-zone-accelerator';
const official = 'https://github.com/Azure/apiops-cli';
const colors = {
  ink: '16242D', muted: '50616C', paper: 'F5F8F9', white: 'FFFFFF',
  blue: '0078D4', teal: '007F79', lime: 'D6F28C', gold: 'F3B742',
  line: 'D6E0E4', pale: 'E6F3F4', red: 'AB3346', code: '112D38',
};
const sources = {
  cli: official,
  support: `${official}/blob/main/SUPPORT.md`,
  runbook: `${repo}/blob/main/docs/apim-007-apiops-cli.md`,
  extract: `${repo}/blob/main/.github/workflows/extract-apiops-007.yml`,
  release: `${repo}/blob/main/.github/workflows/release-apiops-007.yml`,
  validate: `${repo}/blob/main/.github/workflows/validate-apim-007.yml`,
  infra: `${repo}/blob/main/.github/workflows/infra-apim-007.yml`,
};
const translations = {
  en: {
    lang: 'en-US', file: 'APIOps-007-English.pptx', label: 'ENGLISH',
    cover: ['APIOps', 'From API configuration\nto a reviewed release.'],
    coverSub: 'Azure API Management CLI | dev-007 to prod-007',
    agenda: '8 core slides + live demo | 15-20 minutes',
    promise: 'Extract. Review. Publish. Promote.',
    whyTitle: 'APIOps makes API changes repeatable',
    whySub: 'Treat API configuration as a versioned product, not a series of portal clicks.',
    why: [
      ['CAPTURE', 'Specifications + configuration', 'APIs, policies, products, backends and named values become reviewable files.'],
      ['CONTROL', 'Git + pull requests', 'A diff explains what changed. Validation and approval decide what ships.'],
      ['REPEAT', 'The same candidate, twice', 'Test in dev. Promote to prod with environment-specific values.'],
    ],
    whyBottom: 'APIOps manages APIM configuration. Bicep provisions infrastructure. This lab also packages backend images.',
    cliTitle: 'One CLI. Two directions.',
    cliSub: 'Microsoft APIM product-group CLI | npm: @azure-tools/apiops-cli',
    extract: 'EXTRACT', publish: 'PUBLISH', azure: 'APIM service', files: 'Artifact files',
    extractBody: 'Read configuration from APIM\nWrite reviewable local artifacts',
    publishBody: 'Read artifacts + target overrides\nApply configuration to APIM',
    cliBottom: '007 pins CLI 1.0.4 + Node 22. Official latest checked: 1.0.5. No upgrade is needed for this demo.',
    cliNotes: 'The official repository is Azure/apiops-cli. The local runbook identifies it as the Microsoft product-group CLI. Be precise about support: SUPPORT.md says MIT open source and community support via GitHub Issues; response time is not guaranteed. Do not promise an Azure support SLA for this tool. apiops init can scaffold GitHub Actions or Azure DevOps pipelines; 007 is a custom hardened workflow, not an unmodified generated pipeline.',
    loopTitle: 'Two authoring paths. One review boundary.',
    loopSub: 'Git is the release source of truth. Extraction is a controlled feedback loop.',
    loopNodes: ['Dev APIM', 'Extract', 'Pull request', 'main', 'Publish'],
    loopTop: 'Portal-first: approved policy edits only in the 007 extraction workflow',
    loopBottom: 'Code-first: add the Weather API description in artifacts.007, then open a PR.',
    loopGuard: '007 does NOT project description edits from the portal. Raw extracts are evidence, not release input.',
    workflowsTitle: '007 workflows: each has one job',
    workflowsSub: 'Provision the platform separately. Release one immutable candidate through the gates.',
    workflowRows: [
      ['Infra APIM 007', 'Manual: shared / dev / prod', 'Provision APIM, registry, backends and AI dependencies.'],
      ['Validate APIM 007', 'Pull request / manual', 'Credential-free checks: Bicep, Pester, bundle and guardrails.'],
      ['Extract APIops 007', 'Manual, dev-007 only', 'Read dev; project allowed API/product policy edits to a PR.'],
      ['Release APIops 007', 'main path changes / manual', 'Build, freeze, deploy dev, plan prod, approve, deploy prod.'],
    ],
    workflowBottom: 'Teardown APIM 007 is a separate, destructive workflow. It is not part of this presentation demo.',
    promoteTitle: 'Promote the candidate, not the environment',
    promoteSub: 'Same bundle + tooling + scripts + image digests. Only generated target values differ.',
    candidate: 'FROZEN\nCANDIDATE', dev: 'DEV-007', prod: 'PROD-007',
    devTests: 'Publish + re-extract\nCompare + gateway tests', prodTests: 'Recheck hashes\nPublish + verify',
    plan: 'READ-ONLY\nPROD PLAN', approve: 'HUMAN\nAPPROVAL',
    overrideTitle: 'Target overrides', overrideBody: 'Backend URLs, named values and AI settings are resolved per environment.',
    promoteBottom: 'No direct dev-to-prod copy. No rebuild after approval. No delete-unmatched in the 007 publish path.',
    demoTitle: 'Live demo: one description, two environments',
    demoSub: 'A metadata-only change. No API contract or gateway behavior change.',
    demoSteps: [
      ['01', 'Show baseline', 'Weather description is identical in dev and prod.'],
      ['02', 'Open a small PR', 'Add properties.description to the Weather API artifact; validate and merge.'],
      ['03', 'Stop at approval', 'Dev shows the new text. Prod still shows the previous text.'],
      ['04', 'Approve prod', 'The same candidate reaches prod; verify the description and receipts.'],
    ],
    descriptionLabel: 'artifacts.007/apis/weather/apiInformation.json',
    demoBottom: 'Verify metadata in the Azure portal or ARM GET. curl against the gateway cannot prove a description change.',
    takeTitle: 'What to watch while the workflow runs',
    takeSub: 'The approval pause is the demonstration: a deliberate difference between environments.',
    takeRows: [
      ['BEFORE MERGE', 'Original description', 'Original description'],
      ['DEV PASSED / PROD WAITING', 'New description', 'Original description'],
      ['PROD APPROVED / VERIFIED', 'New description', 'New description'],
    ],
    takeBottom: 'Prepare and warm the baseline before the talk. Rehearsed release timing exceeds a 15-20 minute session.',
    appendix: 'APPENDIX',
    prepTitle: 'Presenter checklist + recovery',
    prepRows: [
      ['Before the session', 'Provision shared, dev and prod; release main; approve the baseline; verify both release states are clean.'],
      ['Stage the demo', 'Use a tracked User Story and feature branch. Prepare the description-only PR and the before/after checks.'],
      ['Keep the pace', 'Start the candidate before speaking. Show completed evidence if the release is still running.'],
      ['If a gate fails', 'Do not bypass it. Read the failed step and reconcile dev before retrying.'],
      ['Recovery', 'Redeploy a known clean candidate with rollback_candidate_tag. This is a new gated release, not an instant undo.'],
    ],
    prepBottom: 'Solo presenter approval is reduced control: the same person can author, merge and approve.',
    refTitle: 'Commands and references',
    refSub: 'Use the locked CLI through the reviewed 007 workflows for the actual demo.',
    support: 'Support: MIT open source; GitHub Issues, no guaranteed response time. APIM service support is separate.',
    notes: [
      '0:00-0:45. Open with the result: a description change is reviewed once, tested in dev, and promoted to prod after approval. Session budget: 7-8 minutes of explanation, 7-10 minutes of live workflow/evidence, 1-2 minutes of questions. Do not spend the session provisioning infrastructure.',
      '0:45-1:45. APIOps applies DevOps practices to API Management configuration. Configuration-as-code is not the same as infrastructure-as-code. Explain the three layers: Bicep creates services, APIops publishes APIs and policies, and this lab additionally releases backend containers.',
      '',
      '3:00-4:00. Explain both paths without conflating them. The generic CLI extracts API descriptions, but the custom 007 projector only accepts API and product policy.xml edits. Use a code-first description change for this demo. Optionally show an existing successful extract run as evidence. Never claim that a portal description change will produce a 007 PR.',
      '4:00-5:00. Open Actions and identify Infra, Validate, Extract and Release. Explain that all credentialed 007 jobs require APIM007_ENABLED=true and branch-scoped OIDC identities. The lab has additional AI dependencies; provisioning just the two APIM services is not sufficient for the unchanged main release.',
      '5:00-6:30. Read left to right. Build backend images and normalize contracts; freeze the candidate as a GitHub prerelease with hashes. Dev publishes, re-extracts, compares, tests gateways and checks a second publish. Prod planning is read-only. The prod approval applies to the frozen candidate and target manifest/override hashes. Environment overrides change values, not the reviewed candidate. This is workflow orchestration, not a separate apiops promote command.',
      '6:30-12:00. Open the prepared description-only PR. The current Weather artifact has no description, so adding it is the simplest change. Do not edit the normalized OpenAPI specification: the release checks it against the backend contract. The exact proposed text is APIOps 007 - reviewed promotion demo. Merge only after validation and required review. No commit or merge has been pre-authorized by generating this deck.',
      '12:00-17:00. Show dev metadata changed while prod is waiting, then approve prod in GitHub and recheck metadata. Compare candidate tags and archive hashes in receipts. Published API metadata is visible through ARM or the Azure portal, not the gateway response. A gateway 200 is a useful health check but not proof of the description. Historical runtime notes put a release around 25 minutes through dev/plan and another 10 minutes for prod; do not promise completion within the talk. Pre-stage and retain a completed rehearsal as fallback.',
      'Appendix only. Provisioning can take substantially longer than the talk. The runbook documents the Basic v2 and AI lab dependencies, named resource groups, cost controls and expiry. This is an anonymous demo lab, not a production security reference. Do not purge deleted APIM services or remove resources without explicit owner approval. For rollback, select a known clean candidate that is present in release history and use rollback_candidate_tag, then repeat approval and verification.',
      'Appendix only. Commands are conceptual examples using the real CLI flag names. The actual 007 release adds its ownership filter, generated overrides, candidate integrity gates, service-state checks and evidence. The official main README can describe newer features than the locally pinned version. Verify flags with the pinned CLI help before introducing new ones.',
    ],
  },
  fr: {
    lang: 'fr-FR', file: 'APIOps-007-Francais.pptx', label: 'FRAN\u00c7AIS',
    cover: ['APIOps', 'De la configuration API\n\u00e0 une livraison approuv\u00e9e.'],
    coverSub: 'CLI Azure API Management | de dev-007 vers prod-007',
    agenda: '8 diapositives + d\u00e9mo | 15 \u00e0 20 minutes',
    promise: 'Extraire. R\u00e9viser. Publier. Promouvoir.',
    whyTitle: 'APIOps rend les changements API reproductibles',
    whySub: 'G\u00e9rer la configuration comme un produit versionn\u00e9, pas comme une suite de clics.',
    why: [
      ['CAPTURER', 'Contrats + configuration', 'API, politiques, produits, backends et valeurs nomm\u00e9es deviennent des fichiers r\u00e9visables.'],
      ['CONTR\u00d4LER', 'Git + pull requests', 'Le diff explique le changement. Validation et approbation d\u00e9terminent la livraison.'],
      ['REPRODUIRE', 'Un candidat, deux cibles', 'Tester en dev. Promouvoir en prod avec les valeurs propres \u00e0 chaque environnement.'],
    ],
    whyBottom: 'APIOps g\u00e8re la configuration APIM. Bicep provisionne les ressources. Ce labo inclut aussi les images backend.',
    cliTitle: 'Un CLI. Deux directions.',
    cliSub: 'CLI du groupe produit Microsoft APIM | npm : @azure-tools/apiops-cli',
    extract: 'EXTRAIRE', publish: 'PUBLIER', azure: 'Service APIM', files: 'Fichiers artefacts',
    extractBody: 'Lire la configuration APIM\n\u00c9crire des artefacts locaux r\u00e9visables',
    publishBody: 'Lire artefacts + substitutions cibles\nAppliquer la configuration \u00e0 APIM',
    cliBottom: '007 fixe le CLI \u00e0 1.0.4 + Node 22. Derni\u00e8re version officielle v\u00e9rifi\u00e9e : 1.0.5. Aucune mise \u00e0 jour requise.',
    cliNotes: 'Le d\u00e9p\u00f4t officiel est Azure/apiops-cli. Le runbook local indique que ce CLI provient du groupe produit Microsoft. Pr\u00e9ciser la politique de support : SUPPORT.md annonce un outil open source MIT, un support communautaire via GitHub Issues et aucun d\u00e9lai de r\u00e9ponse garanti. Ne pas promettre un SLA de support Azure pour cet outil. apiops init peut g\u00e9n\u00e9rer des pipelines GitHub Actions ou Azure DevOps. 007 est un workflow personnalis\u00e9 et renforc\u00e9.',
    loopTitle: 'Deux voies de cr\u00e9ation. Une m\u00eame r\u00e9vision.',
    loopSub: 'Git reste la source de v\u00e9rit\u00e9. L\u2019extraction est une boucle de retour contr\u00f4l\u00e9e.',
    loopNodes: ['APIM dev', 'Extraction', 'Pull request', 'main', 'Publication'],
    loopTop: 'Depuis le portail : uniquement les changements de politiques autoris\u00e9s par 007',
    loopBottom: 'Depuis Git : ajouter la description de Weather dans artifacts.007, puis ouvrir une PR.',
    loopGuard: '007 ne projette PAS les descriptions modifi\u00e9es dans le portail. Les extractions brutes servent de preuves.',
    workflowsTitle: 'Workflows 007 : un r\u00f4le pour chacun',
    workflowsSub: 'Provisionner la plateforme s\u00e9par\u00e9ment. Livrer un candidat immuable via les contr\u00f4les.',
    workflowRows: [
      ['Infra APIM 007', 'Manuel : shared / dev / prod', 'Provisionner APIM, registre, backends et d\u00e9pendances IA.'],
      ['Validate APIM 007', 'Pull request / manuel', 'Contr\u00f4les sans identifiants : Bicep, Pester, artefacts et garde-fous.'],
      ['Extract APIops 007', 'Manuel, dev-007 seulement', 'Lire dev ; projeter les politiques API/produits autoris\u00e9es vers une PR.'],
      ['Release APIops 007', 'Changements main / manuel', 'Construire, figer, d\u00e9ployer en dev, planifier, approuver, d\u00e9ployer en prod.'],
    ],
    workflowBottom: 'Teardown APIM 007 est un workflow destructif distinct. Il ne fait pas partie de cette d\u00e9monstration.',
    promoteTitle: 'Promouvoir le candidat, pas l\u2019environnement',
    promoteSub: 'M\u00eames artefacts, outils, scripts et empreintes d\u2019images. Seules les valeurs cibles diff\u00e8rent.',
    candidate: 'CANDIDAT\nFIG\u00c9', dev: 'DEV-007', prod: 'PROD-007',
    devTests: 'Publier + r\u00e9extraire\nComparer + tester la passerelle', prodTests: 'Rev\u00e9rifier les empreintes\nPublier + v\u00e9rifier',
    plan: 'PLAN PROD\nLECTURE SEULE', approve: 'APPROBATION\nHUMAINE',
    overrideTitle: 'Substitutions par cible', overrideBody: 'URL backend, valeurs nomm\u00e9es et param\u00e8tres IA sont r\u00e9solus par environnement.',
    promoteBottom: 'Pas de copie directe dev-prod. Pas de reconstruction apr\u00e8s approbation. Pas de delete-unmatched dans 007.',
    demoTitle: 'D\u00e9mo : une description, deux environnements',
    demoSub: 'Un changement de m\u00e9tadonn\u00e9e. Aucun effet sur le contrat API ou le comportement de la passerelle.',
    demoSteps: [
      ['01', 'Montrer la r\u00e9f\u00e9rence', 'La description de Weather est identique en dev et en prod.'],
      ['02', 'Ouvrir une petite PR', 'Ajouter properties.description dans l\u2019artefact Weather ; valider et fusionner.'],
      ['03', 'Observer la pause', 'Dev affiche le nouveau texte. Prod conserve encore le texte pr\u00e9c\u00e9dent.'],
      ['04', 'Approuver la prod', 'Le m\u00eame candidat arrive en prod ; v\u00e9rifier la description et les preuves.'],
    ],
    descriptionLabel: 'artifacts.007/apis/weather/apiInformation.json',
    demoBottom: 'V\u00e9rifier via le portail Azure ou un GET ARM. Un appel curl \u00e0 la passerelle ne prouve pas cette modification.',
    takeTitle: 'Que montrer pendant l\u2019ex\u00e9cution du workflow ?',
    takeSub: 'La pause d\u2019approbation d\u00e9montre une diff\u00e9rence volontaire entre les environnements.',
    takeRows: [
      ['AVANT LA FUSION', 'Description initiale', 'Description initiale'],
      ['DEV VALID\u00c9 / PROD EN ATTENTE', 'Nouvelle description', 'Description initiale'],
      ['PROD APPROUV\u00c9E ET V\u00c9RIFI\u00c9E', 'Nouvelle description', 'Nouvelle description'],
    ],
    takeBottom: 'Pr\u00e9parer la r\u00e9f\u00e9rence avant la session. Le temps de livraison mesur\u00e9 d\u00e9passe 15 \u00e0 20 minutes.',
    appendix: 'ANNEXE',
    prepTitle: 'Checklist de pr\u00e9sentation et reprise',
    prepRows: [
      ['Avant la session', 'Provisionner shared, dev et prod ; livrer main ; approuver la r\u00e9f\u00e9rence ; v\u00e9rifier les deux \u00e9tats clean.'],
      ['Pr\u00e9parer la d\u00e9mo', 'Utiliser une User Story et une branche feature. Pr\u00e9parer la PR de description et les contr\u00f4les avant/apr\u00e8s.'],
      ['Garder le rythme', 'Lancer le candidat avant de parler. Pr\u00e9voir les preuves d\u2019une r\u00e9p\u00e9tition termin\u00e9e.'],
      ['Si un contr\u00f4le \u00e9choue', 'Ne pas le contourner. Lire l\u2019\u00e9tape en \u00e9chec et r\u00e9concilier dev avant de r\u00e9essayer.'],
      ['Reprise', 'Red\u00e9ployer un candidat clean connu avec rollback_candidate_tag, puis approuver et v\u00e9rifier.'],
    ],
    prepBottom: 'Approbation solo : contr\u00f4le r\u00e9duit, car une m\u00eame personne peut cr\u00e9er, fusionner et approuver.',
    refTitle: 'Commandes et r\u00e9f\u00e9rences',
    refSub: 'Pour la d\u00e9mo r\u00e9elle, utiliser le CLI verrouill\u00e9 via les workflows 007 r\u00e9vis\u00e9s.',
    support: 'Support : open source MIT ; GitHub Issues, sans d\u00e9lai garanti. Le support du service APIM est distinct.',
    notes: [
      '0:00-0:45. Pr\u00e9senter le r\u00e9sultat : une description r\u00e9vis\u00e9e une fois, test\u00e9e en dev, puis promue en prod apr\u00e8s approbation. Pr\u00e9voir 7-8 minutes d\u2019explication, 7-10 minutes de d\u00e9mo et de preuves, puis 1-2 minutes de questions. Ne pas provisionner en direct.',
      '0:45-1:45. APIOps applique les pratiques DevOps \u00e0 la configuration API Management. Distinguer les trois couches : Bicep cr\u00e9e les services, APIops publie les API et les politiques, et ce labo livre aussi les conteneurs backend.',
      '',
      '3:00-4:00. Le CLI g\u00e9n\u00e9rique extrait les descriptions, mais le projecteur personnalis\u00e9 007 accepte seulement les modifications policy.xml des API et des produits. Faire la modification de description dans Git. Montrer \u00e9ventuellement une extraction r\u00e9ussie comme preuve. Ne pas annoncer qu\u2019une description modifi\u00e9e dans le portail g\u00e9n\u00e8re une PR 007.',
      '4:00-5:00. Ouvrir Actions et identifier Infra, Validate, Extract et Release. Les jobs avec identifiants exigent APIM007_ENABLED=true et des identit\u00e9s OIDC limit\u00e9es aux environnements. La version main contient des d\u00e9pendances IA : les deux services APIM seuls ne suffisent pas.',
      '5:00-6:30. Les images backend et les contrats sont construits et v\u00e9rifi\u00e9s, puis le candidat est fig\u00e9 en pr\u00e9version GitHub avec ses empreintes. Dev publie, r\u00e9extrait, compare, teste et republie. Le plan prod est en lecture seule. L\u2019approbation porte sur le candidat et les empreintes du manifeste et des substitutions. Il s\u2019agit d\u2019une orchestration du workflow, pas d\u2019une commande apiops promote.',
      '6:30-12:00. Ouvrir la PR pr\u00e9par\u00e9e. L\u2019artefact Weather actuel ne contient pas de description ; son ajout est le changement le plus simple. Ne pas modifier le contrat OpenAPI normalis\u00e9 : la livraison le compare au backend. Texte propos\u00e9 inchang\u00e9 dans les deux langues : APIOps 007 - reviewed promotion demo. Fusionner seulement apr\u00e8s validation et r\u00e9vision. La g\u00e9n\u00e9ration du diaporama n\u2019autorise aucun commit ni aucune fusion.',
      '12:00-17:00. Montrer la nouvelle description en dev alors que prod attend, puis approuver et rev\u00e9rifier. Comparer les tags candidats et les empreintes d\u2019archive des preuves de livraison. La description est une m\u00e9tadonn\u00e9e ARM, pas une r\u00e9ponse de passerelle. Un HTTP 200 v\u00e9rifie la sant\u00e9, pas la description. Les notes historiques indiquent environ 25 minutes jusqu\u2019au plan et 10 minutes de plus en prod ; anticiper l\u2019ex\u00e9cution et conserver les preuves d\u2019une r\u00e9p\u00e9tition.',
      'Annexe seulement. Le provisionnement d\u00e9passe la dur\u00e9e de la pr\u00e9sentation. Consulter le runbook pour Basic v2, les d\u00e9pendances IA, les co\u00fbts et l\u2019expiration. Ce labo anonyme ne constitue pas une architecture de s\u00e9curit\u00e9 de production. Aucune purge APIM ni suppression sans autorisation explicite. rollback_candidate_tag relance une livraison contr\u00f4l\u00e9e d\u2019un candidat clean connu.',
      'Annexe seulement. Les exemples utilisent les vrais noms de param\u00e8tres CLI. 007 ajoute le filtre de propri\u00e9t\u00e9, les substitutions g\u00e9n\u00e9r\u00e9es, les contr\u00f4les d\u2019int\u00e9grit\u00e9, les v\u00e9rifications du service et les preuves. Le README officiel main peut d\u00e9crire une version plus r\u00e9cente. V\u00e9rifier toute nouvelle option avec l\u2019aide du CLI verrouill\u00e9.',
    ],
  },
};

function build(language) {
  const text = translations[language];
  const pptx = new PptxGenJS();
  pptx.layout = 'LAYOUT_WIDE';
  pptx.author = 'Emmanuel Knafo';
  pptx.subject = 'APIOps CLI: extract, publish and promote with the 007 workflows';
  pptx.title = language === 'en' ? 'APIOps | A reviewed path to production' : 'APIOps | Une livraison approuv\u00e9e en production';
  pptx.company = 'APIM 007 demo';
  pptx.lang = text.lang;
  pptx.theme = { headFontFace: 'Aptos Display', bodyFontFace: 'Aptos', lang: text.lang };
  const shape = pptx.ShapeType;
  const bounds = [];
  function box(slide, value, x, y, width, height, size = 20, options = {}) {
    bounds.push({ language, slide: pptx._slides.length, value: String(value).slice(0, 60), x, y, width, height });
    slide.addText(value, { x, y, w: width, h: height, fontFace: 'Aptos', fontSize: size,
      color: colors.ink, margin: 0, breakLine: false, valign: 'mid', paraSpaceAfterPt: 0,
      ...options });
  }
  function rect(slide, x, y, width, height, fill, line = fill) {
    slide.addShape(shape.rect, { x, y, w: width, h: height, fill: { color: fill }, line: { color: line, width: 0.8 } });
  }
  function arrow(slide, x, y, width, fill = colors.teal) {
    slide.addShape(shape.chevron, { x, y, w: width, h: 0.27, fill: { color: fill }, line: { color: fill } });
  }
  function node(slide, title, x, y, width, fill = colors.white, color = colors.ink) {
    rect(slide, x, y, width, 1.03, fill, fill === colors.white ? colors.line : fill);
    box(slide, title, x + 0.1, y + 0.15, width - 0.2, 0.72, 17, { color, bold: true, align: 'center' });
  }
  function base(title, subtitle, number, appendix = false) {
    const slide = pptx.addSlide();
    slide.background = { color: colors.paper };
    rect(slide, 0, 0, 13.333, 0.07, colors.teal);
    box(slide, appendix ? `APIOPS / 007 / ${text.appendix}` : 'APIOPS / 007', 0.62, 0.32, 10.8, 0.25, 10, { bold: true, color: colors.teal, charSpacing: 0 });
    box(slide, title, 0.62, 0.88, 12.0, 0.95, language === 'fr' ? 31 : 34, { bold: true, fontFace: 'Aptos Display' });
    box(slide, subtitle, 0.64, 1.92, 12.0, 0.65, 17, { color: colors.muted });
    rect(slide, 0.62, 6.96, 12.04, 0.01, colors.line);
    box(slide, 'Azure API Management  |  apiops-cli  |  007', 0.64, 7.08, 10.0, 0.19, 9, { color: colors.muted });
    box(slide, String(number).padStart(2, '0'), 12.05, 7.04, 0.6, 0.25, 11, { color: colors.teal, align: 'right', bold: true });
    const note = number === 3 ? text.cliNotes : text.notes[number - 1];
    slide.addNotes(`${note}\n\nSources:\n${Object.values(sources).join('\n')}`);
    return slide;
  }
  function bottom(slide, value) {
    rect(slide, 0.62, 6.03, 12.04, 0.64, colors.pale);
    box(slide, value, 0.83, 6.12, 11.62, 0.43, 14, { color: colors.teal });
  }
  {
    const slide = pptx.addSlide();
    slide.background = { color: colors.ink };
    rect(slide, 0, 0, 0.12, 7.5, colors.lime);
    box(slide, 'AZURE API MANAGEMENT / 007', 0.7, 0.5, 11.9, 0.4, 13, { color: colors.lime, bold: true });
    box(slide, text.cover[0], 0.68, 1.15, 11.9, 1.4, 76, { color: colors.white, bold: true, fontFace: 'Aptos Display' });
    box(slide, text.cover[1], 0.73, 2.55, 11.8, 1.55, 36, { color: colors.white });
    box(slide, text.coverSub, 0.75, 4.46, 11.8, 0.55, 20, { color: 'BBD7DC' });
    const labels = language === 'fr'
      ? ['EXTRAIRE', 'GIT', 'DEV', 'APPROBATION', 'PROD']
      : ['EXTRACT', 'GIT', 'DEV', 'APPROVAL', 'PROD'];
    labels.forEach((value, index) => {
      const position = 0.75 + index * 2.5;
      node(slide, value, position, 5.52, 1.88, index === 4 ? colors.lime : colors.code, index === 4 ? colors.ink : colors.white);
      if (index < 4) arrow(slide, position + 2.02, 5.9, 0.31, colors.lime);
    });
    box(slide, `${text.agenda}  |  ${text.label}`, 0.75, 7.01, 11.9, 0.25, 11, { color: 'BBD7DC' });
    slide.addNotes(`${text.notes[0]}\n\n${text.promise}\n\n${sources.cli}\n${sources.runbook}`);
  }
  {
    const slide = base(text.whyTitle, text.whySub, 2);
    text.why.forEach((item, index) => {
      const position = 0.64 + index * 4.1;
      rect(slide, position, 3.03, 3.78, 0.05, [colors.blue, colors.teal, colors.gold][index]);
      box(slide, item[0], position, 3.36, 3.78, 0.35, 12, { color: colors.teal, bold: true });
      box(slide, item[1], position, 3.94, 3.78, 0.9, 25, { bold: true, valign: 'top' });
      box(slide, item[2], position, 5.01, 3.78, 0.95, 16, { color: colors.muted, valign: 'top' });
    });
    bottom(slide, text.whyBottom);
  }
  {
    const slide = base(text.cliTitle, text.cliSub, 3);
    node(slide, text.azure, 0.8, 3.0, 2.7, colors.blue, colors.white);
    node(slide, text.files, 9.84, 3.0, 2.7, colors.teal, colors.white);
    rect(slide, 3.95, 2.99, 5.44, 1.04, colors.white, colors.line);
    arrow(slide, 3.63, 3.35, 0.22);
    arrow(slide, 9.5, 3.35, 0.22);
    box(slide, 'apiops extract', 4.2, 3.19, 4.94, 0.44, 24, { fontFace: 'Cascadia Code', align: 'center', bold: true });
    box(slide, text.extractBody, 0.84, 4.45, 5.8, 1.02, 20, { color: colors.muted });
    box(slide, text.publishBody, 7.1, 4.45, 5.3, 1.02, 20, { color: colors.muted });
    rect(slide, 3.95, 4.04, 5.44, 0.04, colors.gold);
    slide.addShape(shape.chevron, { x: 3.63, y: 4.14, w: 0.22, h: 0.27, rotate: 180, fill: { color: colors.teal }, line: { color: colors.teal } });
    slide.addShape(shape.chevron, { x: 9.5, y: 4.14, w: 0.22, h: 0.27, rotate: 180, fill: { color: colors.teal }, line: { color: colors.teal } });
    box(slide, 'apiops publish', 4.15, 4.12, 4.99, 0.36, 18, { fontFace: 'Cascadia Code', align: 'center', color: colors.teal });
    bottom(slide, text.cliBottom);
  }
  {
    const slide = base(text.loopTitle, text.loopSub, 4);
    box(slide, text.loopTop, 0.72, 2.86, 11.9, 0.48, 17, { bold: true, color: colors.teal });
    text.loopNodes.forEach((value, index) => {
      const position = 0.72 + index * 2.5;
      node(slide, value, position, 3.63, 1.92, index === 2 ? colors.gold : colors.white);
      if (index < 4) arrow(slide, position + 2.08, 4.01, 0.25);
    });
    box(slide, text.loopBottom, 0.76, 5.07, 11.85, 0.64, 20, { bold: true });
    bottom(slide, text.loopGuard);
  }
  {
    const slide = base(text.workflowsTitle, text.workflowsSub, 5);
    text.workflowRows.forEach((item, index) => {
      const position = 2.85 + index * 0.73;
      if (index % 2 === 0) rect(slide, 0.64, position, 12.02, 0.68, colors.white);
      rect(slide, 0.65, position + 0.1, 0.05, 0.48, [colors.blue, colors.teal, colors.gold, colors.teal][index]);
      box(slide, item[0], 0.85, position + 0.08, 3.15, 0.48, 17, { bold: true });
      box(slide, item[1], 4.12, position + 0.08, 2.77, 0.48, 14, { color: colors.teal });
      box(slide, item[2], 7.13, position + 0.06, 5.27, 0.54, 15, { color: colors.muted });
    });
    bottom(slide, text.workflowBottom);
  }
  {
    const slide = base(text.promoteTitle, text.promoteSub, 6);
    const positions = [0.7, 3.15, 5.62, 8.07, 10.52];
    [text.candidate, text.dev, text.plan, text.approve, text.prod].forEach((value, index) => {
      node(slide, value, positions[index], 3.05, 2.05,
        [colors.ink, colors.blue, colors.white, colors.gold, colors.teal][index],
        [colors.white, colors.white, colors.ink, colors.ink, colors.white][index]);
      if (index < 4) arrow(slide, positions[index] + 2.16, 3.43, 0.18);
    });
    box(slide, text.devTests, 2.94, 4.33, 2.49, 0.84, 14, { color: colors.muted, align: 'center' });
    box(slide, text.prodTests, 10.27, 4.33, 2.53, 0.84, 14, { color: colors.muted, align: 'center' });
    box(slide, text.overrideTitle, 0.76, 5.29, 3.0, 0.36, 17, { bold: true, color: colors.teal });
    box(slide, text.overrideBody, 3.83, 5.22, 8.7, 0.57, 16, { color: colors.muted });
    bottom(slide, text.promoteBottom);
  }
  {
    const slide = base(text.demoTitle, text.demoSub, 7);
    text.demoSteps.forEach((item, index) => {
      const position = 2.84 + index * 0.67;
      box(slide, item[0], 0.72, position, 0.58, 0.46, 25, { color: colors.teal, bold: true });
      box(slide, item[1], 1.52, position, 3.27, 0.46, 19, { bold: true });
      box(slide, item[2], 4.87, position - 0.01, 7.58, 0.49, 16, { color: colors.muted });
    });
    box(slide, text.descriptionLabel, 0.75, 5.57, 11.85, 0.27, 13, { fontFace: 'Cascadia Code', color: colors.teal });
    bottom(slide, text.demoBottom);
  }
  {
    const slide = base(text.takeTitle, text.takeSub, 8);
    box(slide, 'DEV-007', 6.08, 2.88, 2.8, 0.35, 16, { bold: true, color: colors.blue });
    box(slide, 'PROD-007', 9.44, 2.88, 2.8, 0.35, 16, { bold: true, color: colors.teal });
    text.takeRows.forEach((item, index) => {
      const position = 3.46 + index * 0.73;
      rect(slide, 0.65, position, 12.0, 0.62, index === 1 ? 'FFF2D6' : colors.white);
      box(slide, item[0], 0.82, position + 0.07, 4.95, 0.46, 14, { bold: true });
      box(slide, item[1], 6.08, position + 0.07, 2.96, 0.46, 16, { color: colors.blue });
      box(slide, item[2], 9.44, position + 0.07, 3.02, 0.46, 16, { color: colors.teal });
    });
    bottom(slide, text.takeBottom);
  }
  {
    const slide = base(text.prepTitle, '', 9, true);
    text.prepRows.forEach((item, index) => {
      const position = 2.21 + index * 0.69;
      rect(slide, 0.68, position + 0.57, 11.94, 0.01, colors.line);
      box(slide, item[0], 0.75, position, 3.0, 0.52, 17, { bold: true, color: colors.teal });
      box(slide, item[1], 3.93, position - 0.01, 8.55, 0.57, 16, { color: colors.muted });
    });
    bottom(slide, text.prepBottom);
  }
  {
    const slide = base(text.refTitle, text.refSub, 10, true);
    rect(slide, 0.68, 2.85, 12.0, 1.61, colors.code);
    box(slide, 'apiops extract --resource-group <rg> --service-name <apim>\n  --output ./artifacts\napiops publish --resource-group <rg> --service-name <apim>\n  --source ./artifacts --overrides ./target.json --dry-run',
      0.96, 3.06, 11.45, 1.16, 17, { fontFace: 'Cascadia Code', color: colors.white, breakLine: false });
    const labels = language === 'en'
      ? [['Official CLI + commands', sources.cli], ['007 runbook + demo', sources.runbook], ['007 release workflow', sources.release], ['Official support policy', sources.support]]
      : [['CLI officiel et commandes', sources.cli], ['Runbook et d\u00e9mo 007', sources.runbook], ['Workflow de livraison 007', sources.release], ['Politique de support officielle', sources.support]];
    labels.forEach((item, index) => {
      const column = index % 2;
      const row = Math.floor(index / 2);
      box(slide, item[0], 0.84 + column * 6.12, 4.78 + row * 0.43, 5.8, 0.32, 17,
        { color: colors.blue, underline: true, hyperlink: { url: item[1] } });
    });
    bottom(slide, text.support);
  }
  for (const item of bounds) {
    if (item.x < 0 || item.y < 0 || item.x + item.width > 13.334 || item.y + item.height > 7.501) {
      throw new Error(`Text outside slide: ${JSON.stringify(item)}`);
    }
  }
  return { pptx, file: path.join(output, text.file) };
}

await fs.mkdir(output, { recursive: true });
for (const language of ['en', 'fr']) {
  const { pptx, file } = build(language);
  await pptx.writeFile({ fileName: file });
  const archive = await unzipper.Open.file(file);
  const slides = archive.files.filter(item => /^ppt\/slides\/slide\d+\.xml$/.test(item.path));
  const notes = archive.files.filter(item => /^ppt\/notesSlides\/notesSlide\d+\.xml$/.test(item.path));
  if (slides.length !== 10 || notes.length !== 10) throw new Error(`Incomplete deck: ${file}`);
  for (const item of archive.files.filter(entry => entry.path.endsWith('.xml'))) {
    await parseStringPromise((await item.buffer()).toString());
  }
  const stats = await fs.stat(file);
  if (stats.size < 10000) throw new Error(`Unexpectedly small deck: ${file}`);
  console.log(JSON.stringify({ file, slides: slides.length, notes: notes.length, bytes: stats.size, xml: 'valid', bounds: 'valid' }));
}