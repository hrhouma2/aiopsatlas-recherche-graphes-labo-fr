/**
 * Génère les jeux de données du labo, de façon déterministe (même graine →
 * mêmes fichiers). Les fichiers produits sont committés : les étudiants n'ont
 * pas besoin de Node, ce script sert seulement à les régénérer.
 *
 *   node outils/generer-donnees.mjs
 *
 * Univers : une plateforme de cours en ligne.
 *   - Elasticsearch / OpenSearch : index `cours`, `avis`, `acces` (bulk NDJSON)
 *   - Neo4j : CSV dans neo4j/import (étudiants, professeurs, cours, compétences,
 *     inscriptions, prérequis…)
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const RACINE = join(dirname(fileURLToPath(import.meta.url)), '..');

// --- Générateur pseudo-aléatoire à graine (mulberry32) ----------------------
let graine = 20260909;

function alea() {
  graine |= 0;
  graine = (graine + 0x6d2b79f5) | 0;
  let t = Math.imul(graine ^ (graine >>> 15), 1 | graine);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

const entier = (min, max) => min + Math.floor(alea() * (max - min + 1));
const choix = (liste) => liste[Math.floor(alea() * liste.length)];
const melange = (liste) => {
  const copie = [...liste];
  for (let i = copie.length - 1; i > 0; i--) {
    const j = Math.floor(alea() * (i + 1));
    [copie[i], copie[j]] = [copie[j], copie[i]];
  }
  return copie;
};
const quelquesUns = (liste, n) => melange(liste).slice(0, n);
const arrondi = (x, d = 1) => Math.round(x * 10 ** d) / 10 ** d;
const dateISO = (d) => d.toISOString().slice(0, 10);
const ajouterJours = (d, n) => new Date(d.getTime() + n * 86400000);

// --- Référentiels -----------------------------------------------------------
const CATEGORIES = {
  DevOps: {
    sujets: ['Docker', 'Kubernetes', 'Terraform', 'Ansible', 'Jenkins', 'GitHub Actions', 'Helm', 'GitLab CI', 'Prometheus', 'Grafana', 'Nginx', 'Linux'],
    verbes: ['déployer', 'automatiser', 'superviser', 'industrialiser', 'fiabiliser'],
    objets: ['vos applications', 'une infrastructure', 'un pipeline CI/CD', 'des conteneurs en production', 'un cluster'],
  },
  Données: {
    sujets: ['Elasticsearch', 'OpenSearch', 'Kibana', 'Neo4j', 'Cypher', 'PostgreSQL', 'MongoDB', 'Kafka', 'Spark', 'Airflow', 'dbt', 'Redis'],
    verbes: ['indexer', 'interroger', 'modéliser', 'nettoyer', 'analyser'],
    objets: ['des millions de documents', 'un graphe de connaissances', 'des flux temps réel', 'un entrepôt de données', 'des journaux applicatifs'],
  },
  IA: {
    sujets: ['Machine learning', 'Deep learning', 'Scikit-learn', 'PyTorch', 'LangChain', 'RAG', 'Agents IA', 'Prompt engineering', 'Vision par ordinateur', 'NLP', 'MLOps', 'LLM open source'],
    verbes: ['entraîner', 'évaluer', 'déployer', 'comprendre', 'orchestrer'],
    objets: ['un modèle de classification', 'un assistant conversationnel', 'un pipeline de prédiction', 'des agents autonomes', 'un système de recommandation'],
  },
  'Développement web': {
    sujets: ['React', 'Next.js', 'TypeScript', 'Node.js', 'Vue.js', 'Tailwind CSS', 'REST API', 'GraphQL', 'Supabase', 'Stripe', 'Playwright', 'HTML et CSS'],
    verbes: ['construire', 'sécuriser', 'tester', 'publier', 'optimiser'],
    objets: ['une application web complète', 'un SaaS', 'une API', 'une boutique en ligne', 'un portfolio'],
  },
  Sécurité: {
    sujets: ['Cybersécurité', 'Analyse de ports', 'Pare-feu Linux', 'OWASP', 'Cryptographie', 'Pentest', 'SIEM', 'Zero Trust', 'Gestion des identités', 'Sécurité Docker', 'Wireshark', 'Nmap'],
    verbes: ['protéger', 'auditer', 'détecter', 'durcir', 'analyser'],
    objets: ['un serveur exposé', 'une application web', 'un réseau d’entreprise', 'des conteneurs', 'des accès utilisateurs'],
  },
  Cloud: {
    sujets: ['AWS', 'Azure', 'Google Cloud', 'AWS Lambda', 'S3 et CloudFront', 'IAM', 'EKS', 'Bedrock', 'Serverless', 'Coûts cloud', 'Architecture cloud', 'Migration cloud'],
    verbes: ['migrer', 'architecturer', 'sécuriser', 'optimiser', 'déployer'],
    objets: ['une charge de travail critique', 'une application serverless', 'un data lake', 'une plateforme multi-comptes', 'un site à fort trafic'],
  },
};

const FORMATS = [
  '{sujet} : de zéro à la production',
  '{sujet} pour les débutants',
  '{sujet} en pratique',
  'Maîtriser {sujet}',
  '{sujet} expliqué simplement',
  'Atelier {sujet} : {objet}',
  '{sujet} avancé : {verbe} {objet}',
  'Les bases de {sujet}',
  '{sujet} : le guide complet',
  '{sujet} par la pratique : {verbe} {objet}',
];

const NIVEAUX = ['debutant', 'intermediaire', 'avance'];
const LANGUES = ['fr', 'fr', 'fr', 'en'];

const PRENOMS = ['Amina', 'Youssef', 'Camille', 'Léa', 'Karim', 'Sofia', 'Nathan', 'Inès', 'Omar', 'Chloé', 'Mehdi', 'Julie', 'Adam', 'Sarah', 'Hugo', 'Yasmine', 'Lucas', 'Nour', 'Thomas', 'Emma', 'Rayan', 'Manon', 'Ali', 'Zoé', 'Malik', 'Alice', 'Ismaël', 'Louise', 'Bilal', 'Clara', 'Samir', 'Jade', 'Idris', 'Lina', 'Gabriel', 'Maya', 'Élias', 'Rania', 'Noah', 'Salma'];
const NOMS = ['Rehouma', 'Tremblay', 'Bouchard', 'Nguyen', 'Gagnon', 'Ben Ali', 'Roy', 'Côté', 'Lavoie', 'Haddad', 'Fortin', 'Morin', 'Diallo', 'Gauthier', 'Traoré', 'Pelletier', 'Chen', 'Bélanger', 'Mansour', 'Lévesque', 'Nadeau', 'Ouellet', 'Bergeron', 'Sow', 'Girard', 'Kaci', 'Simard', 'Boucher', 'Rahmani', 'Caron'];
const VILLES = [
  ['Montréal', 'Canada', 45.5019, -73.5674],
  ['Québec', 'Canada', 46.8139, -71.208],
  ['Laval', 'Canada', 45.6066, -73.7124],
  ['Gatineau', 'Canada', 45.4765, -75.7013],
  ['Sherbrooke', 'Canada', 45.4042, -71.8929],
  ['Toronto', 'Canada', 43.6532, -79.3832],
  ['Paris', 'France', 48.8566, 2.3522],
  ['Lyon', 'France', 45.764, 4.8357],
  ['Marseille', 'France', 43.2965, 5.3698],
  ['Bruxelles', 'Belgique', 50.8503, 4.3517],
  ['Genève', 'Suisse', 46.2044, 6.1432],
  ['Tunis', 'Tunisie', 36.8065, 10.1815],
  ['Casablanca', 'Maroc', 33.5731, -7.5898],
  ['Alger', 'Algérie', 36.7538, 3.0588],
  ['Dakar', 'Sénégal', 14.7167, -17.4677],
  ['Abidjan', 'Côte d’Ivoire', 5.3599, -4.0083],
];

const COMPETENCES = ['Conteneurisation', 'Orchestration', 'Infrastructure as Code', 'Intégration continue', 'Observabilité', 'Recherche full-text', 'Modélisation de graphes', 'Streaming de données', 'SQL', 'Apprentissage supervisé', 'Réseaux de neurones', 'Ingénierie de prompts', 'Développement front-end', 'Développement back-end', 'Tests automatisés', 'Sécurité applicative', 'Analyse réseau', 'Architecture cloud', 'Serverless', 'Gestion des coûts', 'Administration Linux', 'Bases de données NoSQL'];

const COMPETENCES_PAR_CATEGORIE = {
  DevOps: ['Conteneurisation', 'Orchestration', 'Infrastructure as Code', 'Intégration continue', 'Observabilité', 'Administration Linux'],
  Données: ['Recherche full-text', 'Modélisation de graphes', 'Streaming de données', 'SQL', 'Bases de données NoSQL', 'Observabilité'],
  IA: ['Apprentissage supervisé', 'Réseaux de neurones', 'Ingénierie de prompts', 'Streaming de données', 'SQL'],
  'Développement web': ['Développement front-end', 'Développement back-end', 'Tests automatisés', 'Sécurité applicative', 'SQL'],
  Sécurité: ['Sécurité applicative', 'Analyse réseau', 'Administration Linux', 'Conteneurisation'],
  Cloud: ['Architecture cloud', 'Serverless', 'Gestion des coûts', 'Infrastructure as Code', 'Orchestration'],
};

const AVIS_POSITIFS = [
  'Excellent cours, très clair et progressif.',
  'Les exercices pratiques font toute la différence, je recommande.',
  'Enfin une formation où tout fonctionne du premier coup grâce à Docker.',
  'Le professeur explique simplement des notions difficiles.',
  'J’ai pu appliquer le contenu au travail dès la semaine suivante.',
  'Très bon rythme, les quiz aident à retenir.',
  'Le projet final est concret et valorisable dans un portfolio.',
  'Contenu à jour, exemples réalistes, rien à redire.',
];
const AVIS_NEUTRES = [
  'Bon cours dans l’ensemble, quelques passages un peu rapides.',
  'Contenu correct, j’aurais aimé plus d’exercices.',
  'Utile, mais certains chapitres méritent d’être approfondis.',
  'Bien pour débuter, insuffisant pour un usage avancé.',
  'Les vidéos sont bonnes, la partie théorique est dense.',
];
const AVIS_NEGATIFS = [
  'Trop théorique à mon goût, pas assez de pratique.',
  'Plusieurs commandes ne fonctionnaient plus avec la nouvelle version.',
  'Le rythme est trop lent au début et trop rapide à la fin.',
  'Décevant : le contenu ne correspond pas au titre.',
  'Difficile de suivre sans prérequis solides.',
];

const CHEMINS_STATIQUES = ['/', '/cours', '/catalogue', '/tarifs', '/connexion', '/inscription', '/faq', '/contact', '/robots.txt', '/sitemap.xml'];
const PAYS_LOGS = [['CA', 0.45], ['FR', 0.25], ['TN', 0.06], ['MA', 0.06], ['BE', 0.05], ['DZ', 0.04], ['CH', 0.03], ['SN', 0.03], ['US', 0.03]];
const APPAREILS = [['desktop', 0.55], ['mobile', 0.38], ['tablette', 0.07]];
const NAVIGATEURS = [['Chrome', 0.6], ['Safari', 0.18], ['Firefox', 0.12], ['Edge', 0.1]];
const REFERENTS = [['direct', 0.4], ['google', 0.35], ['linkedin', 0.1], ['youtube', 0.08], ['newsletter', 0.07]];

function pondere(paires) {
  let r = alea();
  for (const [valeur, poids] of paires) {
    r -= poids;
    if (r <= 0) return valeur;
  }
  return paires[paires.length - 1][0];
}

// --- Professeurs -------------------------------------------------------------
const professeurs = Array.from({ length: 30 }, (_, i) => {
  const [ville, pays] = choix(VILLES);
  const categories = Object.keys(CATEGORIES);
  return {
    id: `P${String(i + 1).padStart(3, '0')}`,
    prenom: choix(PRENOMS),
    nom: choix(NOMS),
    ville,
    pays,
    specialite: categories[i % categories.length],
    annees_experience: entier(3, 25),
  };
});

// --- Cours -------------------------------------------------------------------
const DEBUT = new Date('2023-01-01T00:00:00Z');
const cours = [];
let numero = 0;

for (const [categorie, ref] of Object.entries(CATEGORIES)) {
  for (const sujet of ref.sujets) {
    const formats = quelquesUns(FORMATS, 7);
    for (const format of formats) {
      numero += 1;
      const verbe = choix(ref.verbes);
      const objet = choix(ref.objets);
      const titre = format.replace('{sujet}', sujet).replace('{verbe}', verbe).replace('{objet}', objet);
      const niveau = format.includes('débutants') || format.includes('bases') || format.includes('simplement') ? 'debutant' : format.includes('avancé') ? 'avance' : choix(NIVEAUX);
      const gratuit = alea() < 0.12;
      const prix = gratuit ? 0 : choix([19, 29, 39, 49, 59, 79, 99, 129, 149, 199]);
      const dureeHeures = niveau === 'debutant' ? entier(3, 12) : niveau === 'intermediaire' ? entier(8, 25) : entier(15, 45);
      const profsCategorie = professeurs.filter((p) => p.specialite === categorie);
      const prof = choix(profsCategorie);
      const autresSujets = quelquesUns(ref.sujets.filter((s) => s !== sujet), 2);
      const tags = [sujet, ...autresSujets, categorie].map((t) => t.toLowerCase().replace(/\s+/g, '-'));
      const nbAvis = entier(0, 400);
      const noteMoyenne = nbAvis === 0 ? null : arrondi(3.2 + alea() * 1.8);
      const description = `Dans ce cours ${niveau === 'debutant' ? 'accessible sans prérequis' : niveau === 'avance' ? 'destiné aux profils confirmés' : 'de niveau intermédiaire'}, vous apprenez à ${verbe} ${objet} avec ${sujet}. ` +
        `Chaque module alterne explications et travaux pratiques guidés ; vous manipulez aussi ${autresSujets.join(' et ')}. ` +
        `${gratuit ? 'Ce cours est entièrement gratuit.' : `Accès à vie, certificat inclus, ${dureeHeures} heures de contenu.`}`;

      cours.push({
        id: `C${String(numero).padStart(4, '0')}`,
        titre,
        description,
        categorie,
        sujet,
        niveau,
        langue: choix(LANGUES),
        prix,
        gratuit,
        duree_heures: dureeHeures,
        tags,
        date_publication: dateISO(ajouterJours(DEBUT, entier(0, 1300))),
        note_moyenne: noteMoyenne,
        nb_avis: nbAvis,
        professeur: { id: prof.id, nom: `${prof.prenom} ${prof.nom}`, ville: prof.ville },
        competences: quelquesUns(COMPETENCES_PAR_CATEGORIE[categorie], entier(1, 3)),
      });
    }
  }
}

// --- Étudiants ---------------------------------------------------------------
const etudiants = Array.from({ length: 300 }, (_, i) => {
  const [ville, pays] = choix(VILLES);
  return {
    id: `E${String(i + 1).padStart(4, '0')}`,
    prenom: choix(PRENOMS),
    nom: choix(NOMS),
    ville,
    pays,
    inscription_le: dateISO(ajouterJours(DEBUT, entier(0, 1300))),
    interet: choix(Object.keys(CATEGORIES)),
  };
});

// --- Inscriptions (graphe) ----------------------------------------------------
const inscriptions = [];
const inscrits = new Set();

for (const etu of etudiants) {
  // Chaque étudiant suit surtout sa catégorie d'intérêt, parfois autre chose.
  const coursInteret = cours.filter((c) => c.categorie === etu.interet);
  const nb = entier(2, 9);
  const choisis = [...quelquesUns(coursInteret, Math.max(1, nb - 1)), ...quelquesUns(cours, 1)];
  for (const c of choisis) {
    const cle = `${etu.id}-${c.id}`;
    if (inscrits.has(cle)) continue;
    inscrits.add(cle);
    const progression = choix([100, 100, 100, entier(5, 95), entier(5, 95), 0]);
    inscriptions.push({
      etudiant_id: etu.id,
      cours_id: c.id,
      date: dateISO(ajouterJours(new Date(etu.inscription_le), entier(0, 400))),
      progression,
      note: progression === 100 && alea() < 0.7 ? entier(1, 5) : '',
    });
  }
}

// --- Prérequis (graphe) : "bases" → "pratique" → "avancé" dans un même sujet ----
const prerequis = [];
for (const ref of Object.values(CATEGORIES)) {
  for (const sujet of ref.sujets) {
    const duSujet = cours.filter((c) => c.sujet === sujet);
    const ordre = { debutant: 0, intermediaire: 1, avance: 2 };
    const tries = [...duSujet].sort((a, b) => ordre[a.niveau] - ordre[b.niveau]);
    for (let i = 1; i < tries.length; i++) {
      if (ordre[tries[i].niveau] > ordre[tries[i - 1].niveau] || alea() < 0.3) {
        prerequis.push({ prerequis_id: tries[i - 1].id, cours_id: tries[i].id });
      }
    }
  }
}

// --- Avis (Elasticsearch) ------------------------------------------------------
const avis = [];
let numeroAvis = 0;
for (const ins of inscriptions) {
  if (ins.note === '') continue;
  numeroAvis += 1;
  const etu = etudiants.find((e) => e.id === ins.etudiant_id);
  const texte = ins.note >= 4 ? choix(AVIS_POSITIFS) : ins.note === 3 ? choix(AVIS_NEUTRES) : choix(AVIS_NEGATIFS);
  avis.push({
    id: `A${String(numeroAvis).padStart(5, '0')}`,
    cours_id: ins.cours_id,
    etudiant: etu.prenom,
    ville: etu.ville,
    pays: etu.pays,
    note: ins.note,
    texte,
    date: dateISO(ajouterJours(new Date(ins.date), entier(7, 90))),
    utile: entier(0, 40),
  });
}

// --- Journaux d'accès (Kibana / Dashboards) -----------------------------------
const acces = [];
const FIN_LOGS = new Date('2026-09-08T00:00:00Z');
for (let i = 0; i < 12000; i++) {
  const jour = entier(0, 29);
  // Plus de trafic en semaine et en journée.
  const heure = pondere([[9, 0.06], [10, 0.09], [11, 0.1], [12, 0.07], [13, 0.07], [14, 0.1], [15, 0.1], [16, 0.09], [17, 0.07], [18, 0.05], [19, 0.05], [20, 0.06], [21, 0.04], [22, 0.02], [8, 0.02], [23, 0.01]]);
  const ts = new Date(FIN_LOGS.getTime() - jour * 86400000 + heure * 3600000 + entier(0, 3599) * 1000);
  const surCours = alea() < 0.6;
  const c = surCours ? choix(cours) : null;
  const chemin = surCours ? (alea() < 0.15 ? `/cours/${c.id}/lecon/${entier(1, 12)}` : `/cours/${c.id}`) : choix(CHEMINS_STATIQUES);
  const statut = pondere([[200, 0.9], [301, 0.03], [304, 0.02], [404, 0.035], [500, 0.01], [503, 0.005]]);
  const pays = pondere(PAYS_LOGS);
  const appareil = pondere(APPAREILS);
  acces.push({
    '@timestamp': ts.toISOString(),
    methode: alea() < 0.95 ? 'GET' : 'POST',
    chemin,
    cours_id: c ? c.id : null,
    categorie: c ? c.categorie : null,
    statut,
    octets: statut === 200 ? entier(2000, 180000) : entier(200, 2000),
    duree_ms: statut >= 500 ? entier(800, 5000) : entier(20, 900),
    ip: `${entier(1, 223)}.${entier(0, 255)}.${entier(0, 255)}.${entier(1, 254)}`,
    pays,
    appareil,
    navigateur: pondere(NAVIGATEURS),
    referent: pondere(REFERENTS),
  });
}
acces.sort((a, b) => a['@timestamp'].localeCompare(b['@timestamp']));

// --- Écriture ------------------------------------------------------------------
function ecrire(chemin, contenu) {
  const absolu = join(RACINE, chemin);
  mkdirSync(dirname(absolu), { recursive: true });
  writeFileSync(absolu, contenu, 'utf8');
  console.log(`  ${chemin}`);
}

function bulk(index, docs) {
  return docs.map((d) => `${JSON.stringify({ index: { _index: index, _id: d.id ?? undefined } })}\n${JSON.stringify(d)}`).join('\n') + '\n';
}

function csv(lignes, colonnes) {
  const echap = (v) => {
    const s = v === null || v === undefined ? '' : String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  return [colonnes.join(','), ...lignes.map((l) => colonnes.map((c) => echap(l[c])).join(','))].join('\n') + '\n';
}

console.log('Jeux de données Elasticsearch / OpenSearch :');
ecrire('elasticsearch/donnees/cours.ndjson', bulk('cours', cours));
ecrire('elasticsearch/donnees/avis.ndjson', bulk('avis', avis));
ecrire('elasticsearch/donnees/acces.ndjson', bulk('acces', acces.map((a, i) => ({ id: `L${String(i + 1).padStart(6, '0')}`, ...a }))));

console.log('Jeux de données Neo4j (CSV) :');
ecrire('neo4j/import/etudiants.csv', csv(etudiants, ['id', 'prenom', 'nom', 'ville', 'pays', 'inscription_le', 'interet']));
ecrire('neo4j/import/professeurs.csv', csv(professeurs, ['id', 'prenom', 'nom', 'ville', 'pays', 'specialite', 'annees_experience']));
ecrire('neo4j/import/cours.csv', csv(cours.map((c) => ({ ...c, professeur_id: c.professeur.id })), ['id', 'titre', 'categorie', 'sujet', 'niveau', 'prix', 'duree_heures', 'date_publication', 'professeur_id']));
ecrire('neo4j/import/competences.csv', csv(COMPETENCES.map((nom, i) => ({ id: `K${String(i + 1).padStart(2, '0')}`, nom })), ['id', 'nom']));
ecrire('neo4j/import/couvre.csv', csv(cours.flatMap((c) => c.competences.map((k) => ({ cours_id: c.id, competence_id: `K${String(COMPETENCES.indexOf(k) + 1).padStart(2, '0')}` }))), ['cours_id', 'competence_id']));
ecrire('neo4j/import/inscriptions.csv', csv(inscriptions, ['etudiant_id', 'cours_id', 'date', 'progression', 'note']));
ecrire('neo4j/import/prerequis.csv', csv(prerequis, ['prerequis_id', 'cours_id']));
ecrire('neo4j/import/villes.csv', csv(VILLES.map(([nom, pays, lat, lon]) => ({ nom, pays, latitude: lat, longitude: lon })), ['nom', 'pays', 'latitude', 'longitude']));

console.log(`\nRésumé : ${cours.length} cours, ${professeurs.length} professeurs, ${etudiants.length} étudiants, ${inscriptions.length} inscriptions, ${prerequis.length} prérequis, ${avis.length} avis, ${acces.length} lignes de journal.`);
