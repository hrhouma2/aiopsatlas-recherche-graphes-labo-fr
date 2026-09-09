/**
 * Rejoue un fichier de requêtes au format « Kibana Dev Tools » contre
 * Elasticsearch ou OpenSearch, et vérifie que chacune répond correctement.
 * C'est l'outil qui a servi à tester toutes les requêtes du cours.
 *
 *   node outils/tester-requetes.mjs elasticsearch/requetes/03-01-match-et-bool.txt
 *   node outils/tester-requetes.mjs elasticsearch/requetes/*.txt --url http://localhost:9201
 *
 * Format accepté (le même que celui que vous collez dans Dev Tools) :
 *   # commentaire
 *   GET cours/_search
 *   { "query": { "match_all": {} } }
 *
 * Une requête censée échouer se déclare avec un commentaire juste avant :
 *   # attendu: 404
 *   GET index-inexistant/_doc/1
 *
 * Nécessite Node.js 18+ (pour fetch). Facultatif : le cours n'en a pas besoin,
 * cet outil sert à vérifier le kit.
 */
import { readFileSync } from 'node:fs';

const args = process.argv.slice(2);
const indexUrl = args.indexOf('--url');
const base = (indexUrl >= 0 ? args[indexUrl + 1] : 'http://localhost:9200').replace(/\/$/, '');
const fichiers = args.filter((a, i) => a !== '--url' && !(indexUrl >= 0 && i === indexUrl + 1));

if (fichiers.length === 0) {
  console.error('usage : node outils/tester-requetes.mjs <fichier.txt> [...] [--url http://localhost:9201]');
  process.exit(2);
}

const METHODES = /^(GET|POST|PUT|DELETE|HEAD)\s+(\S+)\s*$/;

/** Découpe un fichier Dev Tools en requêtes { methode, chemin, corps, attendu, ligne }. */
export function analyser(texte) {
  const requetes = [];
  let attendu = null;
  let courante = null;
  texte.split(/\r?\n/).forEach((ligne, i) => {
    const m = ligne.match(METHODES);
    if (m) {
      courante = { methode: m[1], chemin: m[2], corps: [], attendu, ligne: i + 1 };
      requetes.push(courante);
      attendu = null;
      return;
    }
    const commentaire = ligne.match(/^\s*(?:#|\/\/)\s*(.*)$/);
    if (commentaire) {
      const a = commentaire[1].match(/^attendu\s*:\s*(\d{3})/i);
      if (a) attendu = Number(a[1]);
      return;
    }
    if (courante && ligne.trim() !== '') courante.corps.push(ligne);
  });
  return requetes;
}

function resume(json) {
  if (json === null || typeof json !== 'object') return '';
  if (json.hits?.total) return `hits ${json.hits.total.value}`;
  if (json.count !== undefined) return `count ${json.count}`;
  if (json.acknowledged !== undefined) return `acknowledged ${json.acknowledged}`;
  if (json.result) return `result ${json.result}`;
  if (json.errors !== undefined) return `bulk errors ${json.errors}`;
  if (json.tokens) return `${json.tokens.length} tokens`;
  if (json.values) return `${json.values.length} lignes ES|QL`;
  if (json.status && json.number_of_nodes) return `cluster ${json.status}`;
  return '';
}

let echecs = 0;
let total = 0;

for (const fichier of fichiers) {
  console.log(`\n${fichier}`);
  const requetes = analyser(readFileSync(fichier, 'utf8'));
  for (const r of requetes) {
    total += 1;
    const chemin = r.chemin.startsWith('/') ? r.chemin : `/${r.chemin}`;
    const corps = r.corps.join('\n');
    // _bulk exige du NDJSON terminé par un saut de ligne ; le reste est du JSON.
    const estBulk = chemin.includes('_bulk');
    // Comme Dev Tools : un GET avec un corps est envoyé en POST (les deux
    // moteurs acceptent POST pour _search, _analyze, _count…).
    const methode = r.methode === 'GET' && corps ? 'POST' : r.methode;
    const options = {
      method: methode,
      headers: corps ? { 'Content-Type': estBulk ? 'application/x-ndjson' : 'application/json' } : {},
      body: corps ? (estBulk ? `${corps}\n` : corps) : undefined,
    };
    try {
      const reponse = await fetch(base + chemin, options);
      const texte = await reponse.text();
      let json = null;
      try { json = JSON.parse(texte); } catch { /* réponse texte (_cat) */ }
      const attendu = r.attendu ?? null;
      const ok = attendu !== null ? reponse.status === attendu : reponse.status < 400;
      const detail = json ? resume(json) : texte.trim().split('\n').length + ' lignes';
      if (ok) {
        console.log(`  ✔ l.${String(r.ligne).padStart(3)}  ${r.methode} ${r.chemin} → ${reponse.status}${detail ? ` (${detail})` : ''}`);
      } else {
        echecs += 1;
        const raison = json?.error?.reason ?? json?.error?.root_cause?.[0]?.reason ?? texte.slice(0, 200);
        console.log(`  ✘ l.${String(r.ligne).padStart(3)}  ${r.methode} ${r.chemin} → ${reponse.status}${attendu ? ` (attendu ${attendu})` : ''} : ${raison}`);
      }
    } catch (erreur) {
      echecs += 1;
      console.log(`  ✘ l.${String(r.ligne).padStart(3)}  ${r.methode} ${r.chemin} → ${erreur.message}`);
    }
  }
}

console.log(`\n${total - echecs}/${total} requêtes réussies sur ${base}`);
process.exit(echecs === 0 ? 0 : 1);
