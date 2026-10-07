// Generates the animated diagrams (EN + FR) into docs/assets/anim/.
// Usage: node scripts/anim/build-anims.mjs
import { writeFileSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";

const out = fileURLToPath(new URL("../../docs/assets/anim/", import.meta.url));
mkdirSync(out, { recursive: true });
const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

const T = {
  en: {
    flowTitle: "APIOps 007: one frozen candidate, from Git to dev to prod",
    flowSub: "APIops CLI 1.0.4 · GitHub Actions · Azure API Management Basic v2 · human approval before prod",
    laneGit: "GIT", laneRelease: "RELEASE", laneLoop: "EXTRACTION GITOPS · ROLLBACK",
    dev: "Developer", devSub: "edits artifacts.007",
    pr: "Pull request", prSub: "Bicep · Pester · bundle check",
    main: "main", mainSub: "squash merge · AB#id",
    freeze: "Freeze candidate", freezeSub: "immutable GitHub release",
    cand: "candidate.tar.gz", candSub: "SHA256 · image digests",
    deployDev: "deploy-dev · dev-007", deployDev1: "overrides · dry run · publish", deployDev2: "extract · compare · gateway tests",
    plan: "plan-prod", planSub: "read-only · same hash",
    approval: "Approval", approvalSub: "prod-007 reviewer", approved: "approved",
    deployProd: "deploy-prod · prod-007", deployProd1: "same candidate, prod overrides", deployProd2: "tests · release state · receipt",
    portal: "Portal edit", portalSub: "dev-007 only",
    extract: "extract-apiops-007", extractSub: "dev must run main",
    projected: "Policy-only PR", projectedSub: "projected from extraction",
    rollback: "Rollback by tag", rollbackSub: "trusted history · same gates",
    legendPromo: "promotion", legendExtract: "extraction GitOps", legendRollback: "rollback",
    footer: "Bundle: environment-neutral · Overrides: generated per environment · State: apim007-release-state named value",
    aiTitle: "AI gateway: five policies between every team and the model",
    aiSub: "One APIM API · two team products · managed identity to Azure OpenAI · no keys leave APIM",
    retail: "team-retail", retailSub: "subscription key",
    finance: "team-finance", financeSub: "subscription key",
    anon: "anonymous", anonSub: "no api-key",
    apim: "Azure API Management · ai-gateway API",
    c1: "api-key", c1a: "product", c1b: "subscription",
    c2: "token limit", c2a: "TPM + daily", c2b: "per subscription",
    c3: "content safety", c3a: "shield prompt", c3b: "+ blocklist",
    c4: "managed identity", c4a: "Entra token", c4b: "no API keys",
    c5: "token metric", c5a: "API · product", c5b: "subscription",
    aoai: "Azure OpenAI", aoaiSub: "gpt-4o · chat deployment",
    cs: "Content Safety", csSub: "blocklist apim007-demo",
    ai: "Application Insights", aiInsSub: "AppMetrics · showback",
    p401: "401 · missing subscription key", p200: "200 · answer + remaining-tokens", p429: "429 · Retry-After (team-finance)", p403: "403 · content safety: blocked",
    s1: "T1 · no key", s2: "T2 · team-retail", s3: "T3 · finance burst", s4: "T4 · blocked term",
    ovTitle: "One environment-neutral bundle, two environments",
    ovSub: "The bundle never holds hosts, limits or secrets: generated overrides fill them in at publish time",
    bundle: "artifacts.007 (bundle)", gen: "New-Apim007Overrides.ps1", genDev: "dev manifest + ai-settings", genProd: "prod manifest + ai-settings",
    devApim: "dev-007", prodApim: "prod-007", filter: "ownership filter: only owned resources",
  },
  fr: {
    flowTitle: "APIOps 007 : un seul candidat figé, de Git au dev puis à la prod",
    flowSub: "APIops CLI 1.0.4 · GitHub Actions · Azure API Management Basic v2 · approbation humaine avant la prod",
    laneGit: "GIT", laneRelease: "PUBLICATION", laneLoop: "GITOPS PAR EXTRACTION · RETOUR ARRIÈRE",
    dev: "Développeur", devSub: "modifie artifacts.007",
    pr: "Pull request", prSub: "Bicep · Pester · paquet",
    main: "main", mainSub: "fusion squash · AB#id",
    freeze: "Figer le candidat", freezeSub: "release GitHub immuable",
    cand: "candidate.tar.gz", candSub: "SHA256 · empreintes d'images",
    deployDev: "deploy-dev · dev-007", deployDev1: "substitutions · essai · publication", deployDev2: "extraction · comparaison · tests",
    plan: "plan-prod", planSub: "lecture seule · même hachage",
    approval: "Approbation", approvalSub: "réviseur prod-007", approved: "approuvé",
    deployProd: "deploy-prod · prod-007", deployProd1: "même candidat, valeurs prod", deployProd2: "tests · état de version · reçu",
    portal: "Modif. portail", portalSub: "dev-007 seulement",
    extract: "extract-apiops-007", extractSub: "le dev doit exécuter main",
    projected: "PR de stratégies", projectedSub: "projetée depuis l'extraction",
    rollback: "Retour par étiquette", rollbackSub: "historique fiable · mêmes contrôles",
    legendPromo: "promotion", legendExtract: "GitOps par extraction", legendRollback: "retour arrière",
    footer: "Paquet : neutre · Substitutions : générées par environnement · État : valeur nommée apim007-release-state",
    aiTitle: "Passerelle IA : cinq stratégies entre chaque équipe et le modèle",
    aiSub: "Une API APIM · deux produits d'équipe · identité managée vers Azure OpenAI · aucune clé ne sort d'APIM",
    retail: "team-retail", retailSub: "clé d'abonnement",
    finance: "team-finance", financeSub: "clé d'abonnement",
    anon: "anonyme", anonSub: "sans api-key",
    apim: "Azure API Management · API ai-gateway",
    c1: "api-key", c1a: "abonnement", c1b: "au produit",
    c2: "limite jetons", c2a: "TPM + quotidien", c2b: "par abonnement",
    c3: "sécurité contenu", c3a: "bouclier invite", c3b: "+ liste de blocage",
    c4: "identité managée", c4a: "jeton Entra", c4b: "aucune clé d'API",
    c5: "métrique jetons", c5a: "API · produit", c5b: "abonnement",
    aoai: "Azure OpenAI", aoaiSub: "gpt-4o · déploiement chat",
    cs: "Content Safety", csSub: "liste apim007-demo",
    ai: "Application Insights", aiInsSub: "AppMetrics · refacturation",
    p401: "401 · clé d'abonnement manquante", p200: "200 · réponse + remaining-tokens", p429: "429 · Retry-After (team-finance)", p403: "403 · sécurité du contenu : bloqué",
    s1: "T1 · sans clé", s2: "T2 · team-retail", s3: "T3 · rafale finance", s4: "T4 · terme bloqué",
    ovTitle: "Un paquet neutre, deux environnements",
    ovSub: "Le paquet ne contient ni hôtes, ni limites, ni secrets : les substitutions générées les fournissent à la publication",
    bundle: "artifacts.007 (paquet)", gen: "New-Apim007Overrides.ps1", genDev: "manifeste dev + ai-settings", genProd: "manifeste prod + ai-settings",
    devApim: "dev-007", prodApim: "prod-007", filter: "filtre de propriété : ressources possédées seulement",
  },
};

const defs = `<defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#0b1020"/><stop offset="100%" stop-color="#101a33"/></linearGradient>
    <linearGradient id="apim" x1="0" y1="0" x2="1" y2="0"><stop offset="0%" stop-color="#7c3aed"/><stop offset="100%" stop-color="#2563eb"/></linearGradient>
    <linearGradient id="accent" x1="0" y1="0" x2="1" y2="0"><stop offset="0%" stop-color="#0ea5e9"/><stop offset="50%" stop-color="#a855f7"/><stop offset="100%" stop-color="#ef4444"/></linearGradient>
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="4" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
    <marker id="arrow" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto"><path d="M0,0 L9,3 L0,6 Z" fill="#64748b"/></marker>
    <style>
      .t { fill:#e2e8f0; } .muted { fill:#94a3b8; font-size:12.5px; } .lane { fill:#64748b; font-size:11px; font-weight:700; letter-spacing:.14em; }
      .box { fill:#111c36; stroke:#334155; stroke-width:1.5; }
      .wire { stroke:#475569; stroke-width:2; fill:none; }
      .flow { stroke-width:2.5; fill:none; stroke-dasharray:8 10; opacity:.7; animation:dash 1.1s linear infinite; }
      .green { stroke:#4ade80; } .amber { stroke:#fbbf24; } .red { stroke:#f87171; } .blue { stroke:#38bdf8; }
      @keyframes dash { to { stroke-dashoffset:-36; } }
      .title { font-size:22px; font-weight:700; fill:#f1f5f9; } .h { font-size:14.5px; font-weight:650; fill:#e2e8f0; }
      .pill { font-size:12.5px; font-weight:650; }
      @media (prefers-reduced-motion: reduce) { .flow { animation:none; } .motion { display:none; } }
    </style>
  </defs>`;

const head = (w, h, title, sub) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" font-family="Segoe UI, Helvetica, Arial, sans-serif" role="img" aria-label="${esc(title)}">
  <title>${esc(title)}</title>
  ${defs}
  <rect width="${w}" height="${h}" fill="url(#bg)"/>
  <rect width="${w}" height="4" fill="url(#accent)"/>
  <text x="${w / 2}" y="44" text-anchor="middle" class="title">${esc(title)}</text>
  <text x="${w / 2}" y="68" text-anchor="middle" class="muted">${esc(sub)}</text>`;

const box = (x, y, w, h, title, sub, opts = {}) => {
  const fill = opts.apim ? `fill="url(#apim)"` : `class="box"`;
  const cx = x + w / 2;
  const lines = [sub, opts.sub2].filter(Boolean);
  const top = y + h / 2 - (lines.length * 9) + 2;
  return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="12" ${fill}/>
  <text x="${cx}" y="${top}" text-anchor="middle" class="h">${esc(title)}</text>
  ${lines.map((l, i) => `<text x="${cx}" y="${top + 19 + i * 17}" text-anchor="middle" class="muted"${opts.apim ? ' fill="#e9d5ff" style="fill:#e9d5ff"' : ""}>${esc(l)}</text>`).join("\n  ")}`;
};

// A pill that is visible only between keyTimes a..b (fractions of dur).
const pill = (cx, y, w, label, color, bg, a, b, dur) => `<g opacity="0"><rect x="${cx - w / 2}" y="${y}" width="${w}" height="28" rx="14" fill="${bg}" stroke="${color}"/>
    <text x="${cx}" y="${y + 19}" text-anchor="middle" class="pill" fill="${color}">${esc(label)}</text>
    <animate attributeName="opacity" dur="${dur}s" repeatCount="indefinite" values="0;0;1;1;0;0" keyTimes="0;${a};${(a + 0.02).toFixed(3)};${(b - 0.02).toFixed(3)};${b};1"/></g>`;

function flow(L) {
  const W = 1200, H = 720, D = 14;
  const p = [];
  p.push(head(W, H, L.flowTitle, L.flowSub));
  p.push(`<text x="40" y="108" class="lane">${L.laneGit}</text><text x="40" y="288" class="lane">${L.laneRelease}</text><text x="40" y="508" class="lane">${L.laneLoop}</text>`);
  // Wires and animated flows first, so the boxes drawn afterwards sit on top.
  for (const [a, b] of [[200, 260], [460, 520], [670, 730], [950, 990]]) p.push(`<path class="wire" d="M${a},155 H${b}" marker-end="url(#arrow)"/>`);
  for (const [a, b] of [[370, 420], [610, 660], [810, 860]]) p.push(`<path class="wire" d="M${a},355 H${b}" marker-end="url(#arrow)"/>`);
  p.push(`<path class="wire" d="M1075,190 V250 H205 V300" marker-end="url(#arrow)"/>`);
  p.push(`<path class="wire" d="M100,410 V520" stroke-dasharray="4 5"/>`);
  p.push(`<path class="wire" d="M240,555 H300" marker-end="url(#arrow)"/><path class="wire" d="M530,555 H570" marker-end="url(#arrow)"/>`);
  p.push(`<path class="wire" d="M635,520 V225 H360 V190" marker-end="url(#arrow)"/>`);
  p.push(`<path class="wire" d="M1160,555 H1180 V250 H1075" marker-end="url(#arrow)"/>`);
  p.push(`<path class="flow green" d="M200,155 H990"/><path class="flow green" d="M1075,190 V250 H205 V300"/><path class="flow green" d="M370,355 H860"/>`);
  p.push(`<path class="flow amber" d="M240,555 H570"/><path class="flow amber" d="M635,520 V225 H360 V190"/>`);
  p.push(`<path class="flow red" d="M1160,555 H1180 V250 H1100"/>`);
  // Row 1
  p.push(box(40, 120, 160, 70, L.dev, L.devSub));
  p.push(box(260, 120, 200, 70, L.pr, L.prSub));
  p.push(box(520, 120, 150, 70, L.main, L.mainSub));
  p.push(box(730, 120, 220, 70, L.freeze, L.freezeSub));
  p.push(box(990, 120, 170, 70, L.cand, L.candSub));
  // Row 2
  p.push(box(40, 300, 330, 110, L.deployDev, L.deployDev1, { apim: true, sub2: L.deployDev2 }));
  p.push(box(420, 300, 190, 110, L.plan, L.planSub));
  p.push(box(660, 300, 150, 110, L.approval, L.approvalSub));
  p.push(box(860, 300, 300, 110, L.deployProd, L.deployProd1, { apim: true, sub2: L.deployProd2 }));
  // Row 3
  p.push(box(40, 520, 200, 70, L.portal, L.portalSub));
  p.push(box(300, 520, 230, 70, L.extract, L.extractSub));
  p.push(box(570, 520, 200, 70, L.projected, L.projectedSub));
  p.push(box(860, 520, 300, 70, L.rollback, L.rollbackSub));
  // Release badges (x-demo-release) that switch during the cycle
  const badge = (cx, a, b, switchAt) => `<g class="pill">
    <g><rect x="${cx - 95}" y="420" width="190" height="28" rx="14" fill="#0f172a" stroke="#64748b"/><text x="${cx}" y="439" text-anchor="middle" fill="#cbd5e1">x-demo-release: ${a}</text>
      <animate attributeName="opacity" dur="${D}s" repeatCount="indefinite" values="1;1;0;0" keyTimes="0;${switchAt};${(switchAt + 0.01).toFixed(3)};1"/></g>
    <g opacity="0"><rect x="${cx - 95}" y="420" width="190" height="28" rx="14" fill="#052e1b" stroke="#16a34a"/><text x="${cx}" y="439" text-anchor="middle" fill="#4ade80">x-demo-release: ${b}</text>
      <animate attributeName="opacity" dur="${D}s" repeatCount="indefinite" values="0;0;1;1" keyTimes="0;${switchAt};${(switchAt + 0.01).toFixed(3)};1"/></g></g>`;
  p.push(badge(290, "baseline-a", "candidate-b", 0.47));
  p.push(badge(1010, "baseline-a", "candidate-b", 0.86));
  // Approval highlight
  p.push(`<g opacity="0"><rect x="660" y="300" width="150" height="110" rx="12" fill="none" stroke="#fbbf24" stroke-width="3" filter="url(#glow)"/>
    <rect x="685" y="382" width="100" height="22" rx="11" fill="#3b2a06" stroke="#f59e0b"/><text x="735" y="397" text-anchor="middle" class="pill" fill="#fbbf24">✓ ${esc(L.approved)}</text>
    <animate attributeName="opacity" dur="${D}s" repeatCount="indefinite" values="0;0;1;1;0;0" keyTimes="0;0.64;0.66;0.8;0.82;1"/></g>`);
  // Packets
  p.push(`<g class="motion">
  <circle r="8" fill="#4ade80" filter="url(#glow)" opacity="0">
    <animateMotion dur="${D}s" repeatCount="indefinite" path="M120,155 H1075 V250 H205 V355 H1010" keyPoints="0;0.371;0.716;0.716;0.825;0.903;0.903;1;1" keyTimes="0;0.25;0.42;0.5;0.58;0.64;0.76;0.84;1" calcMode="linear"/>
    <animate attributeName="opacity" dur="${D}s" repeatCount="indefinite" values="0;1;1;0;0" keyTimes="0;0.02;0.88;0.9;1"/>
  </circle>
  <circle r="7" fill="#fbbf24" filter="url(#glow)" opacity="0">
    <animateMotion dur="${D}s" repeatCount="indefinite" path="M140,555 H635 V225 H360 V190" keyPoints="0;0;1;1" keyTimes="0;0.5;0.8;1" calcMode="linear"/>
    <animate attributeName="opacity" dur="${D}s" repeatCount="indefinite" values="0;0;1;1;0;0" keyTimes="0;0.5;0.52;0.8;0.82;1"/>
  </circle></g>`);
  // Legend + footer
  const lg = (x, color, label) => `<circle cx="${x}" cy="636" r="6" fill="${color}"/><text x="${x + 12}" y="641" class="muted">${esc(label)}</text>`;
  p.push(lg(40, "#4ade80", L.legendPromo) + lg(220, "#fbbf24", L.legendExtract) + lg(470, "#f87171", L.legendRollback));
  p.push(`<text x="600" y="690" text-anchor="middle" class="muted">${esc(L.footer)}</text>`);
  p.push(`</svg>`);
  return p.join("\n  ");
}

function aiGateway(L) {
  const W = 1200, H = 640, D = 16;
  const p = [];
  p.push(head(W, H, L.aiTitle, L.aiSub));
  p.push(`<path class="wire" d="M210,192 H235 V295 H990" marker-end="url(#arrow)"/><path class="wire" d="M210,295 H250"/><path class="wire" d="M210,398 H235 V295"/>`);
  p.push(`<path class="wire" d="M600,400 V480" stroke-dasharray="4 5"/><path class="wire" d="M868,400 V480" stroke-dasharray="4 5"/>`);
  p.push(`<path class="flow blue" d="M235,295 H984"/>`);
  p.push(box(30, 160, 180, 64, L.retail, L.retailSub));
  p.push(box(30, 263, 180, 64, L.finance, L.financeSub));
  p.push(box(30, 366, 180, 64, L.anon, L.anonSub));
  p.push(`<rect x="250" y="110" width="700" height="330" rx="16" fill="url(#apim)" opacity=".25" stroke="#7c3aed"/>`);
  p.push(`<text x="600" y="140" text-anchor="middle" class="h">${esc(L.apim)}</text>`);
  const chips = [[L.c1, L.c1a, L.c1b], [L.c2, L.c2a, L.c2b], [L.c3, L.c3a, L.c3b], [L.c4, L.c4a, L.c4b], [L.c5, L.c5a, L.c5b]];
  const icons = ["🔑", "⏱️", "🛡️", "🪪", "📊"];
  chips.forEach(([a, b, c], i) => {
    const x = 270 + i * 134;
    p.push(`<rect x="${x}" y="190" width="124" height="210" rx="12" fill="#111c36" stroke="#6366f1"/>
  <circle cx="${x + 62}" cy="218" r="13" fill="#38bdf8"/><text x="${x + 62}" y="223" text-anchor="middle" font-size="13" font-weight="700" fill="#0b1020">${i + 1}</text>
  <text x="${x + 62}" y="258" text-anchor="middle" class="h" font-size="12.5">${esc(a)}</text>
  <text x="${x + 62}" y="313" text-anchor="middle" font-size="30">${icons[i]}</text>
  <text x="${x + 62}" y="352" text-anchor="middle" class="muted">${esc(b)}</text><text x="${x + 62}" y="370" text-anchor="middle" class="muted">${esc(c)}</text>`);
  });
  p.push(box(990, 255, 180, 80, L.aoai, L.aoaiSub, { apim: true }));
  p.push(box(511, 480, 180, 64, L.cs, L.csSub));
  p.push(box(779, 480, 180, 64, L.ai, L.aiInsSub));
  // Scenarios: [label, path, chipIndex or -1 for model, color, pill text, pill colors]
  const sc = [
    [L.s1, "M210,398 H235 V295 H332", 0, "#94a3b8", L.p401, "#f87171", "#3f1010"],
    [L.s2, "M210,192 H235 V295 H1080", -1, "#4ade80", L.p200, "#4ade80", "#052e1b"],
    [L.s3, "M210,295 H466", 1, "#fbbf24", L.p429, "#fbbf24", "#3b2a06"],
    [L.s4, "M210,192 H235 V295 H600", 2, "#c084fc", L.p403, "#f87171", "#3f1010"],
  ];
  sc.forEach(([label, path, chip, color, ptxt, pc, pbg], i) => {
    const a = i / 4, b = (i + 1) / 4;
    const k = (v) => v.toFixed(3);
    p.push(`<g class="motion"><circle r="8" fill="${color}" filter="url(#glow)" opacity="0">
    <animateMotion dur="${D}s" repeatCount="indefinite" path="${path}" keyPoints="0;0;1;1;1" keyTimes="0;${k(a)};${k(a + 0.12)};${k(b)};1" calcMode="linear"/>
    <animate attributeName="opacity" dur="${D}s" repeatCount="indefinite" values="0;0;1;1;0;0" keyTimes="0;${k(a)};${k(a + 0.01)};${k(b - 0.02)};${k(b - 0.01)};1"/></circle></g>`);
    if (chip >= 0) {
      const x = 270 + chip * 134;
      p.push(`<g opacity="0"><rect x="${x}" y="190" width="124" height="210" rx="12" fill="none" stroke="${pc}" stroke-width="3" filter="url(#glow)"/>
    <animate attributeName="opacity" dur="${D}s" repeatCount="indefinite" values="0;0;1;1;0;0" keyTimes="0;${k(a + 0.12)};${k(a + 0.13)};${k(b - 0.02)};${k(b - 0.01)};1"/></g>`);
    }
    if (chip === 2) {
      p.push(`<g opacity="0"><rect x="511" y="480" width="180" height="64" rx="12" fill="none" stroke="#f87171" stroke-width="3" filter="url(#glow)"/>
    <animate attributeName="opacity" dur="${D}s" repeatCount="indefinite" values="0;0;1;1;0;0" keyTimes="0;${k(a + 0.12)};${k(a + 0.13)};${k(b - 0.02)};${k(b - 0.01)};1"/></g>`);
    }
    if (chip === -1) {
      p.push(`<g opacity="0"><rect x="779" y="480" width="180" height="64" rx="12" fill="none" stroke="#4ade80" stroke-width="3" filter="url(#glow)"/>
    <animate attributeName="opacity" dur="${D}s" repeatCount="indefinite" values="0;0;1;1;0;0" keyTimes="0;${k(a + 0.09)};${k(a + 0.1)};${k(b - 0.02)};${k(b - 0.01)};1"/></g>`);
    }
    p.push(`<g opacity="0"><text x="600" y="172" text-anchor="middle" class="pill" fill="${color}">${esc(label)}</text>
    <animate attributeName="opacity" dur="${D}s" repeatCount="indefinite" values="0;0;1;1;0;0" keyTimes="0;${k(a)};${k(a + 0.01)};${k(b - 0.02)};${k(b - 0.01)};1"/></g>`);
    p.push(pill(1080, 360, 210, ptxt, pc, pbg, +(a + 0.12).toFixed(3), +(b - 0.01).toFixed(3), D));
  });
  p.push(`<text x="600" y="600" text-anchor="middle" class="muted">${esc(L.s1)} · ${esc(L.s2)} · ${esc(L.s3)} · ${esc(L.s4)}</text>`);
  p.push(`</svg>`);
  return p.join("\n  ");
}

function overrides(L, lang) {
  const W = 1200, H = 520, D = 10;
  const p = [];
  p.push(head(W, H, L.ovTitle, L.ovSub));
  p.push(`<rect x="40" y="105" width="330" height="330" rx="14" class="box"/>`);
  p.push(`<text x="60" y="135" class="h">📦 ${esc(L.bundle)}</text>`);
  const files = [
    ["apis/ai-gateway/policy.xml", "{{ai-safety-threshold}}"],
    ["backends/ai-foundry", "https://ai-foundry.invalid"],
    ["namedValues/ai-team-retail-tpm", "UNCONFIGURED"],
    ["products/team-retail/policy.xml", "{{ai-team-retail-tpm}}"],
    ["apis/weather/policy.xml", "x-demo-release"],
  ];
  files.forEach(([f, v], i) => {
    p.push(`<text x="60" y="${172 + i * 46}" font-family="Cascadia Code, Consolas, monospace" font-size="12.5" fill="#cbd5e1">${esc(f)}</text>
  <text x="76" y="${190 + i * 46}" font-family="Cascadia Code, Consolas, monospace" font-size="12" fill="#fbbf24">${esc(v)}</text>`);
  });
  p.push(`<text x="60" y="420" class="muted">🔒 ${esc(L.filter)}</text>`);
  p.push(box(450, 120, 300, 90, L.gen, L.genDev));
  p.push(box(450, 330, 300, 90, L.gen, L.genProd));
  const env = (y, name, host, tpm, finance) => `<rect x="830" y="${y}" width="330" height="150" rx="14" fill="url(#apim)" opacity=".93"/>
  <text x="850" y="${y + 30}" class="h">${esc(name)}</text>
  <text x="850" y="${y + 62}" font-family="Cascadia Code, Consolas, monospace" font-size="12" fill="#e9d5ff">ai-foundry → ${esc(host)}</text>
  <text x="850" y="${y + 90}" font-family="Cascadia Code, Consolas, monospace" font-size="12" fill="#e9d5ff">ai-team-retail-tpm = ${tpm}</text>
  <text x="850" y="${y + 118}" font-family="Cascadia Code, Consolas, monospace" font-size="12" fill="#e9d5ff">ai-team-finance-tpm = ${finance}</text>`;
  p.push(env(105, L.devApim, "ais-apim007-dev-…", 2000, 300));
  p.push(env(315, L.prodApim, "ais-apim007-prod-…", 5000, 500));
  p.push(`<path class="wire" d="M370,200 H450" marker-end="url(#arrow)"/><path class="wire" d="M370,340 H410 V375 H450" marker-end="url(#arrow)"/>`);
  p.push(`<path class="wire" d="M750,165 H830" marker-end="url(#arrow)"/><path class="wire" d="M750,375 H830" marker-end="url(#arrow)"/>`);
  p.push(`<path class="flow blue" d="M370,200 H450"/><path class="flow blue" d="M370,340 H410 V375 H450"/><path class="flow green" d="M750,165 H830"/><path class="flow green" d="M750,375 H830"/>`);
  // Values appear in each environment after the packet arrives
  const reveal = (y, a) => `<rect x="845" y="${y + 45}" width="305" height="85" fill="#4c1d95" opacity="1">
    <animate attributeName="opacity" dur="${D}s" repeatCount="indefinite" values="1;1;0;0;1" keyTimes="0;${a};${(a + 0.06).toFixed(2)};0.95;1"/></rect>`;
  p.push(`<g class="motion">${reveal(105, 0.35)}${reveal(315, 0.6)}
  <circle r="8" fill="#38bdf8" filter="url(#glow)" opacity="0"><animateMotion dur="${D}s" repeatCount="indefinite" path="M370,200 H600 V165 H830" keyPoints="0;1;1" keyTimes="0;0.35;1" calcMode="linear"/>
    <animate attributeName="opacity" dur="${D}s" repeatCount="indefinite" values="0;1;1;0;0" keyTimes="0;0.02;0.34;0.36;1"/></circle>
  <circle r="8" fill="#4ade80" filter="url(#glow)" opacity="0"><animateMotion dur="${D}s" repeatCount="indefinite" path="M370,340 H410 V375 H830" keyPoints="0;0;1;1" keyTimes="0;0.3;0.6;1" calcMode="linear"/>
    <animate attributeName="opacity" dur="${D}s" repeatCount="indefinite" values="0;0;1;1;0;0" keyTimes="0;0.3;0.32;0.59;0.61;1"/></circle></g>`);
  p.push(`<text x="600" y="480" text-anchor="middle" class="muted">publish --source artifacts.007 --overrides overrides.&lt;env&gt;.json --filter configuration.007.ownership.yaml --no-transitive</text>`);
  p.push(`</svg>`);
  return p.join("\n  ");
}

for (const lang of ["en", "fr"]) {
  const L = T[lang];
  const suffix = lang === "en" ? "" : ".fr";
  writeFileSync(`${out}apiops-flow${suffix}.svg`, flow(L));
  writeFileSync(`${out}ai-gateway-flow${suffix}.svg`, aiGateway(L));
  writeFileSync(`${out}bundle-overrides${suffix}.svg`, overrides(L, lang));
}
console.log("animations written to", out);
