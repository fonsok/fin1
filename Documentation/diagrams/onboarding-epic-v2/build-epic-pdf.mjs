#!/usr/bin/env node
/**
 * Builds EPIC Onboarding State Machine v2 — diagrams + tables as one PDF.
 * Run from repo root: node Documentation/diagrams/onboarding-epic-v2/build-epic-pdf.mjs
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';
import puppeteer from 'puppeteer';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const diagramsRoot = path.join(__dirname, '..');
const mmdc = 'npx --no-install @mermaid-js/mermaid-cli';
const outputPdf = path.join(__dirname, 'epic-onboarding-state-machine-v2.pdf');
const outputPdfCopy = path.join(
  diagramsRoot,
  '..',
  'FIN1_APP_DOCS',
  'EPIC_ONBOARDING_STATE_MACHINE_V2.pdf'
);

const diagrams = [
  { key: 'ist', file: 'epic-ist-architecture', title: 'Ist-Architektur — verteilter State' },
  { key: 'soll', file: 'epic-soll-state-machine', title: 'Soll — Onboarding State Machine' },
];

function run(cmd, cwd = __dirname) {
  execSync(cmd, { cwd, stdio: 'inherit' });
}

function renderMermaid(baseName) {
  const png = `${baseName}.png`;
  run(
    `${mmdc} -i "${baseName}.mmd" -o "${png}" -b white -w 3200 -H 2400 -s 1 ` +
      `-c "${path.join(diagramsRoot, 'mermaid-config.json')}" ` +
      `-C "${path.join(diagramsRoot, 'mermaid-export.css')}" ` +
      `-p "${path.join(diagramsRoot, 'puppeteer-config.json')}"`
  );
  return fs.readFileSync(path.join(__dirname, png)).toString('base64');
}

function table(headers, rows) {
  const head = `<tr>${headers.map((h) => `<th>${h}</th>`).join('')}</tr>`;
  const body = rows
    .map((row) => `<tr>${row.map((c) => `<td>${c}</td>`).join('')}</tr>`)
    .join('');
  return `<table><thead>${head}</thead><tbody>${body}</tbody></table>`;
}

function section(title, body) {
  return `<section class="block"><h2>${title}</h2>${body}</section>`;
}

function buildHtml(diagramData) {
  const istImg = `data:image/png;base64,${diagramData.ist}`;
  const sollImg = `data:image/png;base64,${diagramData.soll}`;

  const painRows = [
    ['SignUpData (~400+ Zeilen)', 'Formular + Validierung + Export', 'UI-State, Domain, API-DTO vermischt'],
    ['SignUpCoordinator (11 Dateien)', 'Navigation, Persistenz, Finalize', 'God-Object, schwer testbar'],
    ['SignUpFlowSession', 'Global static', 'Nicht serialisierbar, nicht server-synced'],
    ['User.onboardingCompleted', 'Dashboard-Gate', 'Client/Server divergieren'],
    ['UserSessionObserver', 'UI-Reaktion', 'Workaround für fehlende SSOT'],
    ['NotificationCenter', 'Cross-View Events', 'Implizite Kopplung'],
    ['Backend (3 APIs)', 'Persistenz + Audit', '24 UI-Steps ≠ 7 Backend-Steps'],
  ];

  const layerRows = [
    ['OnboardingSession (neu)', 'Enum-State + SavedOnboardingData + SignUpStep'],
    ['OnboardingEngine (neu)', 'Transitions, Validierung, Server-Commands'],
    ['OnboardingAPIService', 'get / save / complete — einzige Server-Schnittstelle'],
    ['Step Views (bestehend)', 'Nur UI + Bindings an Session-Slice'],
    ['AuthenticationRouter (neu)', 'session.phase == completed → Dashboard'],
  ];

  const serverRows = [
    ['In Progress', 'OnboardingProgress.data, onboardingStep', 'Nur optimistisch bis save bestätigt'],
    ['Phase complete', 'OnboardingAudit, _User.onboardingStep', '—'],
    ['Role agreement', 'LegalConsent, acceptedTrader/Investor*', 'Nach recordRoleAgreementConsent'],
    ['Completed', '_User.onboardingCompleted = true', 'Nach Server-Bestätigung / getUserMe'],
  ];

  const phaseRows = [
    ['0 — Vorbereitung', '2–3 Tage', 'Mapping, Contracts, Feature-Flag, Baseline-Metriken'],
    ['1 — Domain Layer', '3–4 Tage', 'OnboardingSession, Engine, Unit-Tests'],
    ['2 — Server-Sync', '2–3 Tage', 'getOnboardingSession, finalize-Pipeline'],
    ['3 — UI-Migration', '3–5 Tage', 'Strangler: Coordinator → Engine, UI-Tests'],
    ['4 — Aufräumen', '2–3 Tage', 'Legacy entfernen, Flag default on, Docs'],
  ];

  const successRows = [
    ['Kein blauer Placeholder nach Signup', '0 reproduzierbare Fälle in 2 Wochen QA'],
    ['Single API resume', 'max. 1 Call beim App-Start (getOnboardingSession)'],
    ['Testabdeckung Engine', '≥ 90 % Transitions unit-tested'],
    ['Finalize Netzwerk', '≤ 3 sequenzielle Server-Calls'],
    ['Legal Gate', 'Scroll-to-Accept UI-Test grün'],
    ['Kein SignUpFlowSession', 'Grep = 0 Treffer'],
  ];

  const riskRows = [
    ['24 Steps brechen bei Migration', 'Hoch', 'Strangler + Feature-Flag'],
    ['Server/Client Step-Mismatch', 'Hoch', 'Contract-JSON + CI-Test'],
    ['Investor vs. Trader Regression', 'Mittel', 'Parametrisierte Tests pro Role'],
    ['Verschlüsselte OnboardingProgress', 'Mittel', 'Früh mit echtem Server testen'],
    ['Zeitdruck andere Features', 'Hoch', 'Phase 0–1 parallel, UI später'],
  ];

  const backlogRows = [
    ['1', 'OnboardingSession enum + Transition-Tabelle', '3', '0–1'],
    ['2', 'OnboardingEngine unit tests (Trader)', '5', '1'],
    ['3', 'OnboardingEngine unit tests (Investor)', '3', '1'],
    ['4', 'getOnboardingSession Cloud Function', '5', '2'],
    ['5', 'Engine.resume + save/complete integration', '5', '2'],
    ['6', 'SignUpView → Engine (Feature-Flag)', '8', '3'],
    ['7', 'AuthenticationRouter + Dashboard gate', '5', '3'],
    ['8', 'LegalDocumentGate unified', '3', '3'],
    ['9', 'UI-Test Happy Path Trader', '5', '3'],
    ['10', 'Remove SignUpCoordinator / FlowSession', '5', '4'],
    ['11', 'Docs + Flag default on', '2', '4'],
  ];

  return `<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="utf-8" />
  <title>Epic — Onboarding State Machine v2</title>
  <style>
    @page { size: A4; margin: 18mm 16mm; }
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
      font-size: 10pt;
      line-height: 1.45;
      color: #1a1a1a;
      max-width: 100%;
    }
    h1 { font-size: 20pt; margin: 0 0 8pt; color: #0d3b66; }
    h2 { font-size: 13pt; margin: 18pt 0 8pt; color: #0d3b66; border-bottom: 1px solid #ccc; padding-bottom: 4pt; }
    .meta { color: #555; font-size: 9pt; margin-bottom: 16pt; }
    .meta p { margin: 2pt 0; }
    .diagram { text-align: center; margin: 12pt 0; page-break-inside: avoid; }
    .diagram img { max-width: 100%; height: auto; }
    .diagram figcaption { font-size: 9pt; color: #444; margin-top: 6pt; font-style: italic; }
    table { width: 100%; border-collapse: collapse; margin: 8pt 0 12pt; font-size: 9pt; page-break-inside: avoid; }
    th, td { border: 1px solid #bbb; padding: 5pt 6pt; text-align: left; vertical-align: top; }
    th { background: #e8f0f8; font-weight: 600; }
    tr:nth-child(even) td { background: #f9f9f9; }
    .block { page-break-inside: avoid; }
    ul { margin: 6pt 0; padding-left: 18pt; }
    li { margin: 3pt 0; }
    .page-break { page-break-before: always; }
  </style>
</head>
<body>
  <h1>Epic: Onboarding State Machine v2</h1>
  <div class="meta">
    <p><strong>Epic-ID:</strong> FIN1-ONB-v2</p>
    <p><strong>Stand:</strong> 2026-06-23</p>
    <p><strong>Ziel:</strong> Ein testbarer Onboarding-Zustand als Single Source of Truth — von Step-Navigation bis Dashboard-Gate.</p>
    <p><strong>Aufwand:</strong> 1,5–2,5 Wochen (fokussiert) · 49 Story Points</p>
    <p><strong>Vollständige Epic-Beschreibung:</strong> Documentation/FIN1_APP_DOCS/EPIC_ONBOARDING_STATE_MACHINE_V2.md</p>
  </div>

  ${section(
    'Diagramm 1 — Ist-Architektur',
    `<figure class="diagram"><img src="${istImg}" alt="Ist-Architektur" /><figcaption>Verteilter State heute: SignUpData, Coordinator, FlowSession, UserService, Observer, Notifications</figcaption></figure>`
  )}

  ${section('Tabelle 1 — Schmerzpunkte (Ist)', table(['Komponente', 'Rolle', 'Problem'], painRows))}

  <div class="page-break"></div>

  ${section(
    'Diagramm 2 — Soll State Machine',
    `<figure class="diagram"><img src="${sollImg}" alt="Soll State Machine" /><figcaption>Explizite Zustände: idle → … → completed → MainTabView</figcaption></figure>`
  )}

  ${section('Tabelle 2 — Ziel-Schichten (Soll)', table(['Schicht', 'Verantwortung'], layerRows))}

  ${section('Tabelle 3 — Server als Single Source of Truth', table(['Phase', 'Server schreibt', 'Client'], serverRows))}

  ${section('Tabelle 4 — Phasenplan', table(['Phase', 'Dauer', 'Deliverables'], phaseRows))}

  <div class="page-break"></div>

  ${section('Tabelle 5 — Erfolgskriterien (Definition of Done)', table(['Kriterium', 'Messung'], successRows))}

  ${section('Tabelle 6 — Risiken & Mitigation', table(['Risiko', 'Impact', 'Mitigation'], riskRows))}

  ${section('Tabelle 7 — Backlog-Schnitt', table(['#', 'Story', 'Points', 'Phase'], backlogRows))}

  ${section(
    'Go / No-Go',
  `<p><strong>Go</strong> (mind. 2): Re-Consent geplant · Multi-Device Resume · 2. schwerer Onboarding-Bug · ≥10 Dev-Tage Budget</p>
   <p><strong>No-Go:</strong> Nur Code-Schönheit · kein QA-Budget · paralleles Groß-Release ohne Freeze</p>
   <p><strong>Empfehlung:</strong> Epic ins Backlog; Phase 0 (Mapping + Contract) als Spike (1–2 Tage). Phase 1–4 bei Re-Consent, Multi-Device Resume oder 2. Production-Bug.</p>`
  )}
</body>
</html>`;
}

async function main() {
  console.log('Rendering Mermaid diagrams…');
  const diagramData = {};
  for (const d of diagrams) {
    diagramData[d.key] = renderMermaid(d.file);
  }

  const html = buildHtml(diagramData);
  const htmlPath = path.join(__dirname, 'epic-onboarding-document.html');
  fs.writeFileSync(htmlPath, html);
  console.log(`Wrote ${htmlPath}`);

  console.log('Generating PDF…');
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();
  await page.goto(`file://${htmlPath}`, { waitUntil: 'networkidle0' });
  await page.pdf({
    path: outputPdf,
    format: 'A4',
    printBackground: true,
    margin: { top: '18mm', right: '16mm', bottom: '18mm', left: '16mm' },
  });
  await browser.close();

  fs.copyFileSync(outputPdf, outputPdfCopy);
  console.log(`✓ ${outputPdf}`);
  console.log(`✓ ${outputPdfCopy}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
