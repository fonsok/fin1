#!/usr/bin/env node
/**
 * Renders Mermaid diagrams as single-page, horizontally centered PDFs.
 * Builds German (DE) and English (EN) variants.
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';
import { PDFDocument } from 'pdf-lib';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const mmdc = 'npx --no-install @mermaid-js/mermaid-cli';
const marginPt = 48;
const renderWidth = 4800;
const renderHeight = 3600;
const renderScale = 1;

const locales = [
  {
    suffix: '',
    diagrams: [
      'rc5-signup-flow-overview',
      'rc5-signup-flow-investor',
      'rc5-signup-flow-trader',
      'rc5-signup-flow-completion',
    ],
    merged: 'rc5-signup-flow-4seiten.pdf',
    alias: 'rc5-signup-flow.pdf',
    legacyAlias: 'rc5-signup-flow-3seiten.pdf',
  },
  {
    suffix: '-en',
    diagrams: [
      'rc5-signup-flow-overview-en',
      'rc5-signup-flow-investor-en',
      'rc5-signup-flow-trader-en',
      'rc5-signup-flow-completion-en',
    ],
    merged: 'rc5-signup-flow-4seiten-en.pdf',
    alias: 'rc5-signup-flow-en.pdf',
    legacyAlias: 'rc5-signup-flow-3seiten-en.pdf',
  },
];

function run(cmd) {
  execSync(cmd, { cwd: __dirname, stdio: 'inherit' });
}

async function buildCenteredPdf(baseName) {
  const input = `${baseName}.mmd`;
  const png = `${baseName}.png`;
  const pdf = `${baseName}.pdf`;

  run(
    `${mmdc} -i "${input}" -o "${png}" -b white -w ${renderWidth} -H ${renderHeight} -s ${renderScale} ` +
      `-c mermaid-config.json -C mermaid-export.css -p puppeteer-config.json`
  );

  const pngBytes = fs.readFileSync(path.join(__dirname, png));
  const doc = await PDFDocument.create();
  const image = await doc.embedPng(pngBytes);
  const minPageWidth = 842;
  const contentMaxWidth = minPageWidth - marginPt * 2;
  let drawWidth = image.width;
  let drawHeight = image.height;
  if (drawWidth < contentMaxWidth * 0.9) {
    const scale = (contentMaxWidth * 0.9) / drawWidth;
    drawWidth *= scale;
    drawHeight *= scale;
  }
  const pageWidth = Math.max(drawWidth + marginPt * 2, minPageWidth);
  const pageHeight = drawHeight + marginPt * 2;
  const page = doc.addPage([pageWidth, pageHeight]);
  const x = (pageWidth - drawWidth) / 2;
  const y = (pageHeight - drawHeight) / 2;
  page.drawImage(image, { x, y, width: drawWidth, height: drawHeight });

  fs.writeFileSync(path.join(__dirname, pdf), await doc.save());
  console.log(`✓ ${pdf} (${Math.round(pageWidth)}×${Math.round(pageHeight)} pt, 1 page, centered)`);
}

async function mergeLocale({ diagrams, merged, alias, legacyAlias }) {
  const out = await PDFDocument.create();
  for (const baseName of diagrams) {
    const bytes = fs.readFileSync(path.join(__dirname, `${baseName}.pdf`));
    const doc = await PDFDocument.load(bytes);
    const pages = await out.copyPages(doc, doc.getPageIndices());
    pages.forEach((p) => out.addPage(p));
  }
  const mergedPath = path.join(__dirname, merged);
  const mergedBytes = await out.save();
  fs.writeFileSync(mergedPath, mergedBytes);
  fs.writeFileSync(path.join(__dirname, alias), mergedBytes);
  if (legacyAlias) {
    fs.writeFileSync(path.join(__dirname, legacyAlias), mergedBytes);
  }
  console.log(`✓ ${merged} + ${alias} (${diagrams.length} pages)`);
}

for (const locale of locales) {
  console.log(`\n--- ${locale.suffix === '' ? 'DE' : 'EN'} ---`);
  for (const baseName of locale.diagrams) {
    await buildCenteredPdf(baseName);
  }
  await mergeLocale(locale);
}
