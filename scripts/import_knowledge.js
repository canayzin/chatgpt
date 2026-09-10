#!/usr/bin/env node

'use strict';

const fs = require('node:fs');
const path = require('node:path');

const COLLECTION = 'knowledge_cards';
const BATCH_SIZE = 450;
const REQUIRED_FIELDS = ['id', 'baslik', 'kisaIcerik', 'detayIcerik', 'kategori', 'aktif', 'sira'];

function usage() {
  return [
    'Kullanım:',
    '  node scripts/import_knowledge.js <json-dosyası> [--dry-run|--commit]',
    '',
    '--dry-run varsayılandır ve Firestore\'a hiçbir veri yazmaz.',
  ].join('\n');
}

function parseArguments(argv) {
  const flags = argv.filter((argument) => argument.startsWith('--'));
  const files = argv.filter((argument) => !argument.startsWith('--'));
  const unknownFlags = flags.filter((flag) => flag !== '--dry-run' && flag !== '--commit');

  if (files.length !== 1 || unknownFlags.length > 0 || (flags.includes('--dry-run') && flags.includes('--commit'))) {
    throw new Error(usage());
  }

  return { file: files[0], commit: flags.includes('--commit') };
}

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function validateCard(card, index) {
  const errors = [];
  const label = `Kart ${index + 1}`;

  if (!card || typeof card !== 'object' || Array.isArray(card)) {
    return [`${label}: Bir JSON object olmalı.`];
  }

  for (const field of REQUIRED_FIELDS) {
    if (!Object.prototype.hasOwnProperty.call(card, field)) {
      errors.push(`${label}: "${field}" alanı eksik.`);
    }
  }

  for (const field of ['id', 'baslik', 'kisaIcerik', 'detayIcerik', 'kategori']) {
    if (Object.prototype.hasOwnProperty.call(card, field) && !isNonEmptyString(card[field])) {
      errors.push(`${label}: "${field}" boş olmayan bir string olmalı.`);
    }
  }
  if (isNonEmptyString(card.id) && card.id.includes('/')) {
    errors.push(`${label}: "id" Firestore document ID olarak kullanılamaz; "/" içeremez.`);
  }
  if (Object.prototype.hasOwnProperty.call(card, 'aktif') && typeof card.aktif !== 'boolean') {
    errors.push(`${label}: "aktif" boolean olmalı.`);
  }
  if (Object.prototype.hasOwnProperty.call(card, 'sira') &&
      (typeof card.sira !== 'number' || !Number.isFinite(card.sira))) {
    errors.push(`${label}: "sira" geçerli bir sayı olmalı.`);
  }
  if (card.etiketler !== undefined &&
      (!Array.isArray(card.etiketler) || card.etiketler.some((tag) => typeof tag !== 'string'))) {
    errors.push(`${label}: "etiketler" verilirse string array olmalı.`);
  }

  return errors;
}

function buildSearchTokens(card) {
  const values = [card.baslik, card.kategori, card.altKategori, ...(card.etiketler || [])];
  const tokens = values
    .filter((value) => typeof value === 'string')
    .flatMap((value) => value.toLocaleLowerCase('tr-TR').split(/[^\p{L}\p{N}_]+/u))
    .map((token) => token.trim())
    .filter(Boolean);
  return [...new Set(tokens)];
}

function countValues(cards, field) {
  return cards.reduce((counts, card) => {
    if (isNonEmptyString(card[field])) {
      const value = card[field].trim();
      counts.set(value, (counts.get(value) || 0) + 1);
    }
    return counts;
  }, new Map());
}

function findDuplicateIds(cards) {
  const counts = new Map();
  for (const card of cards) {
    if (isNonEmptyString(card && card.id)) {
      const id = card.id.trim();
      counts.set(id, (counts.get(id) || 0) + 1);
    }
  }
  return [...counts.entries()].filter(([, count]) => count > 1);
}

function printCounts(title, counts) {
  console.log(`\n${title}:`);
  if (counts.size === 0) console.log('-');
  for (const [name, count] of [...counts.entries()].sort(([a], [b]) => a.localeCompare(b, 'tr'))) {
    console.log(`${name}: ${count}`);
  }
}

function printReport({ file, cards, errors, duplicates, commit, written = 0, skipped = 0 }) {
  console.log('\nAI Learn Content Import\n');
  console.log(`Dosya: ${file}`);
  console.log(`Toplam kart: ${cards.length}`);
  console.log(`Geçerli: ${cards.length - new Set(errors.map((error) => error.index)).size}`);
  console.log(`Hatalı: ${new Set(errors.map((error) => error.index)).size}`);
  console.log(`Duplicate ID: ${duplicates.length}`);
  printCounts('Kategoriler', countValues(cards, 'kategori'));
  printCounts('Alt kategoriler', countValues(cards, 'altKategori'));
  console.log(commit ? `\nCOMMIT\nYazılan: ${written}\nAtlanan (zaten mevcut): ${skipped}` : '\nDRY RUN\nFirestore\'a hiçbir veri yazılmadı.');
}

async function commitCards(cards) {
  let admin;
  try {
    admin = require('firebase-admin');
  } catch (_) {
    throw new Error('Commit için firebase-admin bulunamadı. Önce "npm install" çalıştırın.');
  }

  if (!admin.apps.length) admin.initializeApp();
  const firestore = admin.firestore();
  let written = 0;
  let skipped = 0;

  for (let offset = 0; offset < cards.length; offset += BATCH_SIZE) {
    const chunk = cards.slice(offset, offset + BATCH_SIZE);
    const refs = chunk.map((card) => firestore.collection(COLLECTION).doc(card.id.trim()));
    const existing = await firestore.getAll(...refs);
    const batch = firestore.batch();

    chunk.forEach((card, index) => {
      if (existing[index].exists) {
        skipped += 1;
        return;
      }
      const timestamp = admin.firestore.FieldValue.serverTimestamp();
      batch.create(refs[index], {
        ...card,
        id: card.id.trim(),
        readCount: 0,
        favoriteCount: 0,
        qualityScore: 0,
        engagementScore: 0,
        viralScore: 0,
        viralityScore: 0,
        isDailyKnowledge: false,
        audioUrl: null,
        searchTokens: buildSearchTokens(card),
        createdAt: timestamp,
        olusturulmaTarihi: timestamp,
      });
      written += 1;
    });

    if (chunk.some((_, index) => !existing[index].exists)) await batch.commit();
  }
  return { written, skipped };
}

async function main() {
  let options;
  try {
    options = parseArguments(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 2;
    return;
  }

  const resolvedFile = path.resolve(process.cwd(), options.file);
  let cards;
  try {
    cards = JSON.parse(fs.readFileSync(resolvedFile, 'utf8'));
  } catch (error) {
    console.error(`JSON dosyası okunamadı: ${resolvedFile}\n${error.message}`);
    process.exitCode = 1;
    return;
  }
  if (!Array.isArray(cards)) {
    console.error('JSON kök değeri bir array olmalı. Hiçbir veri yazılmadı.');
    process.exitCode = 1;
    return;
  }

  const validationErrors = cards.flatMap((card, index) =>
    validateCard(card, index).map((message) => ({ index, message })),
  );
  const duplicates = findDuplicateIds(cards);
  duplicates.forEach(([id, count]) => console.error(`Duplicate ID: "${id}" (${count} kez)`));
  validationErrors.forEach(({ message }) => console.error(message));

  if (validationErrors.length > 0 || duplicates.length > 0) {
    printReport({ file: resolvedFile, cards, errors: validationErrors, duplicates, commit: false });
    console.error('\nValidation başarısız. Import durduruldu; Firestore\'a hiçbir veri yazılmadı.');
    process.exitCode = 1;
    return;
  }

  const enrichedCards = cards.map((card) => ({ ...card, searchTokens: buildSearchTokens(card) }));
  if (!options.commit) {
    printReport({ file: resolvedFile, cards: enrichedCards, errors: [], duplicates, commit: false });
    return;
  }

  const result = await commitCards(enrichedCards);
  printReport({ file: resolvedFile, cards: enrichedCards, errors: [], duplicates, commit: true, ...result });
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`Import başarısız: ${error.message}`);
    process.exitCode = 1;
  });
}

module.exports = { buildSearchTokens, findDuplicateIds, validateCard };
