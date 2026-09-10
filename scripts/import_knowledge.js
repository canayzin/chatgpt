#!/usr/bin/env node

'use strict';

const fs = require('node:fs');
const path = require('node:path');

const BATCH_SIZE = 450;
const COLLECTION = 'knowledge_cards';
const REQUIRED_FIELDS = [
  'id',
  'baslik',
  'kisaIcerik',
  'detayIcerik',
  'kategori',
  'altKategori',
  'sira',
];

function usage() {
  console.error('Kullanım: node scripts/import_knowledge.js <dosya.json> [--only id1,id2] [--dry-run | --commit]');
}

function parseArgs(args) {
  let fileArg;
  let onlyArg;
  let commit = false;
  let dryRun = false;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === '--commit') commit = true;
    else if (arg === '--dry-run') dryRun = true;
    else if (arg === '--only') {
      if (onlyArg !== undefined || !args[index + 1] || args[index + 1].startsWith('--')) return null;
      onlyArg = args[index + 1];
      index += 1;
    } else if (arg.startsWith('--only=')) {
      if (onlyArg !== undefined) return null;
      onlyArg = arg.slice('--only='.length);
    } else if (arg.startsWith('--') || fileArg) return null;
    else fileArg = arg;
  }

  if (!fileArg || (commit && dryRun)) return null;
  const rawOnlyIds = onlyArg === undefined ? null : onlyArg.split(',').map((id) => id.trim());
  if (rawOnlyIds && rawOnlyIds.some((id) => !id)) return null;
  return {
    fileArg,
    commit,
    onlyIds: rawOnlyIds ? [...new Set(rawOnlyIds)] : null,
    duplicateOnlyIds: rawOnlyIds
      ? [...new Set(rawOnlyIds.filter((id, index) => rawOnlyIds.indexOf(id) !== index))]
      : [],
  };
}

function normalize(value) {
  return String(value)
    .toLocaleLowerCase('tr-TR')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/ı/g, 'i')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function buildSearchTokens(card) {
  const source = [
    card.baslik,
    card.kisaIcerik,
    card.kategori,
    card.altKategori,
    card.altKategoriBaslik,
    ...(Array.isArray(card.etiketler) ? card.etiketler : []),
  ];
  const words = normalize(source.filter(Boolean).join(' ')).split(/\s+/).filter(Boolean);
  const tokens = new Set();
  for (const word of words) {
    tokens.add(word);
    for (let length = 2; length <= word.length; length += 1) tokens.add(word.slice(0, length));
  }
  return [...tokens].slice(0, 1000);
}

function validateCard(card, index) {
  if (!card || typeof card !== 'object' || Array.isArray(card)) return `Kayıt ${index + 1}: nesne değil`;
  const missing = REQUIRED_FIELDS.filter((field) => card[field] === undefined || card[field] === null || card[field] === '');
  if (missing.length) return `${card.id || `Kayıt ${index + 1}`}: eksik alanlar: ${missing.join(', ')}`;
  if (typeof card.id !== 'string') return `Kayıt ${index + 1}: id metin olmalı`;
  if (!Number.isFinite(card.sira)) return `${card.id}: sira sayı olmalı`;
  return null;
}

function countBy(cards, field) {
  return cards.reduce((counts, card) => {
    const key = String(card[field]);
    counts[key] = (counts[key] || 0) + 1;
    return counts;
  }, {});
}

function printCounts(label, counts) {
  console.log(`${label}:`);
  for (const [name, count] of Object.entries(counts).sort(([a], [b]) => a.localeCompare(b, 'tr'))) {
    console.log(`  - ${name}: ${count}`);
  }
}

async function commitCards(cards) {
  // Firebase yalnızca açıkça --commit istendiğinde yüklenir ve başlatılır.
  const { applicationDefault, getApps, initializeApp } = require('firebase-admin/app');
  const { FieldValue, getFirestore } = require('firebase-admin/firestore');
  if (!getApps().length) initializeApp({ credential: applicationDefault() });
  const firestore = getFirestore();
  let written = 0;
  let skipped = 0;

  for (let offset = 0; offset < cards.length; offset += BATCH_SIZE) {
    const chunk = cards.slice(offset, offset + BATCH_SIZE);
    const refs = chunk.map((card) => firestore.collection(COLLECTION).doc(card.id));
    const existing = await firestore.getAll(...refs);
    const batch = firestore.batch();
    existing.forEach((snapshot, index) => {
      if (snapshot.exists) {
        skipped += 1;
        return;
      }
      const card = chunk[index];
      const serverTimestamp = FieldValue.serverTimestamp();
      batch.create(refs[index], {
        ...card,
        searchTokens: buildSearchTokens(card),
        createdAt: serverTimestamp,
        olusturulmaTarihi: serverTimestamp,
        readCount: card.readCount ?? 0,
        favoriteCount: card.favoriteCount ?? 0,
        qualityScore: card.qualityScore ?? 0,
        engagementScore: card.engagementScore ?? 0,
        viralScore: card.viralScore ?? 0,
        viralityScore: card.viralityScore ?? 0,
        isDailyKnowledge: card.isDailyKnowledge ?? false,
        audioUrl: card.audioUrl ?? null,
      });
      written += 1;
    });
    await batch.commit();
  }
  return { written, skipped };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (!options) {
    usage();
    process.exitCode = 1;
    return;
  }

  const { commit, duplicateOnlyIds, fileArg, onlyIds } = options;
  const inputPath = path.resolve(fileArg);
  const parsed = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
  if (!Array.isArray(parsed)) throw new Error('JSON kök değeri bir kart dizisi olmalı.');

  let selectedCards = parsed;
  if (onlyIds) {
    const availableIds = new Set(parsed.map((card) => card && card.id));
    const missingIds = onlyIds.filter((id) => !availableIds.has(id));
    if (missingIds.length) {
      console.error(`JSON içinde bulunamayan --only ID: ${missingIds.join(', ')}`);
      console.log('Firebase SDK başlatıldı mı: Hayır');
      console.log('Firebase veri yazımı: Hayır');
      process.exitCode = 1;
      return;
    }
    const requestedIds = new Set(onlyIds);
    selectedCards = parsed.filter((card) => card && requestedIds.has(card.id));
  }

  const seen = new Set();
  const duplicateIds = new Set();
  const errors = [];
  const validCards = [];
  selectedCards.forEach((card, index) => {
    const error = validateCard(card, index);
    if (card && typeof card.id === 'string') {
      if (seen.has(card.id)) duplicateIds.add(card.id);
      seen.add(card.id);
    }
    if (error) errors.push(error);
    else validCards.push(card);
  });

  console.log(`Mod: ${commit ? 'COMMIT' : 'DRY-RUN'}`);
  console.log(`Toplam kart: ${parsed.length}`);
  console.log(`Filtre: ${onlyIds ? 'only' : 'yok'}`);
  if (onlyIds) {
    console.log(`Seçilen ID: ${onlyIds.join(', ')}`);
    console.log(`Seçilen kart: ${selectedCards.length}`);
    console.log(`Tekrarlanan --only ID: ${duplicateOnlyIds.length ? duplicateOnlyIds.join(', ') : 'yok'}`);
  }
  console.log(`Geçerli kart: ${validCards.length}`);
  console.log(`Hatalı kart: ${errors.length}`);
  console.log(`Duplicate ID: ${duplicateIds.size}`);
  if (duplicateIds.size) console.log(`Duplicate ID listesi: ${[...duplicateIds].join(', ')}`);
  printCounts('Ana kategoriler', countBy(validCards, 'kategori'));
  printCounts('Alt kategoriler', countBy(validCards, 'altKategori'));
  const order = validCards.map((card) => card.sira);
  console.log(`Min/max sira: ${order.length ? `${Math.min(...order)} / ${Math.max(...order)}` : '- / -'}`);

  if (errors.length) {
    console.error('Doğrulama hataları:');
    errors.forEach((error) => console.error(`  - ${error}`));
  }
  if (duplicateIds.size || errors.length) {
    console.log('Firebase SDK başlatıldı mı: Hayır');
    console.log('Firebase veri yazımı: Hayır');
    process.exitCode = 1;
    return;
  }
  if (!commit) {
    // Token üretimini dry-run sırasında da gerçekten doğrula.
    validCards.forEach(buildSearchTokens);
    console.log('Firebase SDK başlatıldı mı: Hayır');
    console.log('Firebase veri yazımı: Hayır');
    return;
  }

  const result = await commitCards(validCards);
  console.log('Firebase SDK başlatıldı mı: Evet');
  console.log(`Mevcut doküman (skip): ${result.skipped}`);
  console.log(`Firebase veri yazımı: ${result.written}`);
}

main().catch((error) => {
  console.error(`Importer hatası: ${error.message}`);
  process.exitCode = 1;
});
