// Module 6 — Pratique guidée : le parcours d'un étudiant dans le graphe,
// du profil à la recommandation.
// Exécution : ./labo.sh cypher 06-pratique-le-parcours-d-un-etudiant.cypher
//             .\labo.ps1 cypher 06-pratique-le-parcours-d-un-etudiant.cypher
// Étudiant étudié : E0091 (Lucas Bouchard, Tunis, intérêt Cloud).
// Lecture seule sur le graphe du kit ; la seule écriture est un nœud
// (:Test:Parcours) et ses 5 relations PROPOSE, supprimés à la fin.
// Rejouable : aucun nœud :Test ne survit à l'exécution.

// 0. Point de départ : aucun nœud :Test (on nettoie au cas où une exécution
//    précédente aurait été interrompue, puis on vérifie).
MATCH (n:Test) DETACH DELETE n;
MATCH (n:Test) RETURN count(n) AS test_avant;

// ---------------------------------------------------------------------------
// Étape 1 — La fiche de l'étudiant
// ---------------------------------------------------------------------------

// 1a. Profil et ville
MATCH (moi:Etudiant {id: 'E0091'})-[:HABITE]->(v:Ville)
RETURN moi.prenom + ' ' + moi.nom AS etudiant, moi.interet AS interet,
       moi.inscription_le AS inscrit_le, v.nom AS ville, v.pays AS pays;

// 1b. Ses cours, avec la progression et la note portées par INSCRIT_A
MATCH (moi:Etudiant {id: 'E0091'})-[i:INSCRIT_A]->(c:Cours)
RETURN c.id AS id, c.titre AS titre, c.niveau AS niveau,
       i.progression AS progression, i.note AS note, i.date AS depuis
ORDER BY i.date;

// ---------------------------------------------------------------------------
// Étape 2 — Les cours terminés et les compétences acquises
// ---------------------------------------------------------------------------

// 2a. Que veut dire « terminé » dans ces données ? On croise progression et note
//     sur TOUTES les inscriptions : une note n'existe que si progression = 100.
MATCH ()-[i:INSCRIT_A]->()
RETURN i.progression = 100 AS progression_100, i.note IS NOT NULL AS a_une_note, count(*) AS inscriptions
ORDER BY progression_100, a_une_note;

// 2b. Les cours terminés de l'étudiant et les compétences qu'ils couvrent
MATCH (moi:Etudiant {id: 'E0091'})-[i:INSCRIT_A]->(c:Cours)-[:COUVRE]->(k:Competence)
WHERE i.progression = 100
RETURN c.id AS id, c.titre AS titre, i.note AS note, collect(k.nom) AS competences
ORDER BY id;

// 2c. Le bilan : les compétences acquises, dédoublonnées
MATCH (moi:Etudiant {id: 'E0091'})-[i:INSCRIT_A]->(c:Cours)-[:COUVRE]->(k:Competence)
WHERE i.progression = 100
RETURN collect(DISTINCT k.nom) AS acquises, count(DISTINCT k) AS nb_competences;

// ---------------------------------------------------------------------------
// Étape 3 — Les prérequis manquants
// ---------------------------------------------------------------------------

// Cours suivis dont un prérequis direct n'est pas suivi (ni terminé, ni commencé)
MATCH (moi:Etudiant {id: 'E0091'})-[i:INSCRIT_A]->(c:Cours)<-[:PREREQUIS_DE]-(pre:Cours)
WHERE NOT EXISTS { (moi)-[:INSCRIT_A]->(pre) }
RETURN c.id AS cours, c.titre AS titre, i.progression AS progression,
       pre.id AS prerequis_manquant, pre.titre AS titre_prerequis
ORDER BY cours;

// ---------------------------------------------------------------------------
// Étape 4 — Le plus court chemin de prérequis vers un cours cible
// ---------------------------------------------------------------------------

// 4a. Les cours avancés atteignables depuis ses cours en suivant PREREQUIS_DE
MATCH (moi:Etudiant {id: 'E0091'})-[:INSCRIT_A]->(c:Cours)
MATCH chemin = (c)-[:PREREQUIS_DE*1..6]->(cible:Cours {niveau: 'avance'})
RETURN c.id AS depart, cible.id AS cible, cible.titre AS titre_cible, length(chemin) AS sauts
ORDER BY sauts DESC, depart, cible
LIMIT 5;

// 4b. Le plus court chemin de « AWS pour les débutants » (suivi à 28 %)
//     à « AWS avancé : optimiser une plateforme multi-comptes »
MATCH (depart:Cours {id: 'C0426'}), (cible:Cours {id: 'C0427'}),
      chemin = shortestPath((depart)-[:PREREQUIS_DE*]->(cible))
RETURN length(chemin) AS sauts,
       [n IN nodes(chemin) | n.id + ' — ' + n.titre] AS parcours,
       reduce(h = 0, n IN nodes(chemin) | h + n.duree_heures) AS heures_totales;

// ---------------------------------------------------------------------------
// Étape 5 — Recommandation collaborative
// ---------------------------------------------------------------------------

// 5a. Les « voisins » : étudiants qui partagent au moins 2 cours avec lui
MATCH (moi:Etudiant {id: 'E0091'})-[:INSCRIT_A]->(c:Cours)<-[:INSCRIT_A]-(autre:Etudiant)
WHERE autre <> moi
WITH autre, count(c) AS cours_communs
WHERE cours_communs >= 2
RETURN autre.id AS voisin, autre.prenom AS prenom, autre.interet AS interet, cours_communs
ORDER BY cours_communs DESC, voisin;

// 5b. Ce que suivent les voisins et qu'il ne suit pas encore, classé par fréquence
MATCH (moi:Etudiant {id: 'E0091'})-[:INSCRIT_A]->(c:Cours)<-[:INSCRIT_A]-(autre:Etudiant)
WHERE autre <> moi
WITH moi, autre, count(c) AS cours_communs
WHERE cours_communs >= 2
MATCH (autre)-[:INSCRIT_A]->(reco:Cours)
WHERE NOT EXISTS { (moi)-[:INSCRIT_A]->(reco) }
RETURN reco.id AS id, reco.titre AS titre, reco.niveau AS niveau, count(DISTINCT autre) AS voisins
ORDER BY voisins DESC, id
LIMIT 5;

// ---------------------------------------------------------------------------
// Étape 6 — Recommandation par compétence
// ---------------------------------------------------------------------------

// 6a. Les compétences de son domaine d'intérêt (catégorie Cloud) qu'il n'a pas encore acquises
MATCH (moi:Etudiant {id: 'E0091'})
OPTIONAL MATCH (moi)-[i:INSCRIT_A]->(:Cours)-[:COUVRE]->(k:Competence)
WHERE i.progression = 100
WITH moi, collect(DISTINCT k) AS acquises
MATCH (:Cours {categorie: moi.interet})-[:COUVRE]->(cible:Competence)
WHERE NOT cible IN acquises
RETURN DISTINCT cible.id AS id, cible.nom AS competence_a_acquerir
ORDER BY id;

// 6b. Les cours non suivis qui apportent ces compétences, classés par nombre de compétences apportées
MATCH (moi:Etudiant {id: 'E0091'})
OPTIONAL MATCH (moi)-[i:INSCRIT_A]->(:Cours)-[:COUVRE]->(k:Competence)
WHERE i.progression = 100
WITH moi, collect(DISTINCT k) AS acquises
MATCH (:Cours {categorie: moi.interet})-[:COUVRE]->(cible:Competence)
WHERE NOT cible IN acquises
WITH moi, collect(DISTINCT cible) AS cibles
MATCH (reco:Cours)-[:COUVRE]->(cible:Competence)
WHERE cible IN cibles AND NOT EXISTS { (moi)-[:INSCRIT_A]->(reco) }
RETURN reco.id AS id, reco.titre AS titre, reco.niveau AS niveau,
       collect(cible.nom) AS apporte, count(cible) AS score
ORDER BY score DESC, id
LIMIT 5;

// ---------------------------------------------------------------------------
// Étape 7 — Écrire le parcours proposé : (:Test:Parcours)-[:PROPOSE {rang}]->(:Cours)
// ---------------------------------------------------------------------------

// 7a. Le nœud Parcours + 5 relations PROPOSE vers le top 5 collaboratif (MERGE : rejouable)
MATCH (moi:Etudiant {id: 'E0091'})-[:INSCRIT_A]->(c:Cours)<-[:INSCRIT_A]-(autre:Etudiant)
WHERE autre <> moi
WITH moi, autre, count(c) AS cours_communs
WHERE cours_communs >= 2
MATCH (autre)-[:INSCRIT_A]->(reco:Cours)
WHERE NOT EXISTS { (moi)-[:INSCRIT_A]->(reco) }
WITH moi, reco, count(DISTINCT autre) AS voisins
ORDER BY voisins DESC, reco.id
LIMIT 5
WITH moi, collect(reco) AS recos
MERGE (p:Test:Parcours {etudiant_id: moi.id})
ON CREATE SET p.cree_le = datetime()
WITH p, recos
UNWIND range(0, size(recos) - 1) AS i
WITH p, recos[i] AS reco, i + 1 AS rang
MERGE (p)-[r:PROPOSE]->(reco)
SET r.rang = rang
RETURN p.etudiant_id AS etudiant, rang, reco.id AS id, reco.titre AS titre
ORDER BY rang;

// 7b. La même requête une seconde fois : rien ne doit être ajouté (idempotence)
MATCH (moi:Etudiant {id: 'E0091'})-[:INSCRIT_A]->(c:Cours)<-[:INSCRIT_A]-(autre:Etudiant)
WHERE autre <> moi
WITH moi, autre, count(c) AS cours_communs
WHERE cours_communs >= 2
MATCH (autre)-[:INSCRIT_A]->(reco:Cours)
WHERE NOT EXISTS { (moi)-[:INSCRIT_A]->(reco) }
WITH moi, reco, count(DISTINCT autre) AS voisins
ORDER BY voisins DESC, reco.id
LIMIT 5
WITH moi, collect(reco) AS recos
MERGE (p:Test:Parcours {etudiant_id: moi.id})
ON CREATE SET p.cree_le = datetime()
WITH p, recos
UNWIND range(0, size(recos) - 1) AS i
WITH p, recos[i] AS reco, i + 1 AS rang
MERGE (p)-[r:PROPOSE]->(reco)
SET r.rang = rang
RETURN count(r) AS relations_propose;

// 7c. Relire le parcours (dans Neo4j Browser, vue Graph : 1 Parcours, 5 Cours, 5 PROPOSE)
MATCH chemin = (p:Test:Parcours)-[:PROPOSE]->(c:Cours)
RETURN chemin;

// ---------------------------------------------------------------------------
// Étape 8 — À toi de jouer : le professeur dont il a suivi le plus de cours
// ---------------------------------------------------------------------------

MATCH (moi:Etudiant {id: 'E0091'})-[:INSCRIT_A]->(c:Cours)<-[:ENSEIGNE]-(prof:Professeur)
RETURN prof.prenom + ' ' + prof.nom AS professeur, prof.specialite AS specialite,
       count(c) AS cours_suivis, collect(c.id) AS cours
ORDER BY cours_suivis DESC, professeur
LIMIT 1;

// ---------------------------------------------------------------------------
// Étape 9 — Vérification finale
// ---------------------------------------------------------------------------

// 9a. Le parcours écrit contient exactement 5 propositions
MATCH (p:Test:Parcours)-[r:PROPOSE]->(c)
RETURN p.etudiant_id AS etudiant, count(r) AS propositions;

// 9b. Le coût réel de la recommandation collaborative (db hits)
PROFILE
MATCH (moi:Etudiant {id: 'E0091'})-[:INSCRIT_A]->(c:Cours)<-[:INSCRIT_A]-(autre:Etudiant)
WHERE autre <> moi
WITH moi, autre, count(c) AS cours_communs
WHERE cours_communs >= 2
MATCH (autre)-[:INSCRIT_A]->(reco:Cours)
WHERE NOT EXISTS { (moi)-[:INSCRIT_A]->(reco) }
RETURN reco.id AS id, count(DISTINCT autre) AS voisins
ORDER BY voisins DESC, id
LIMIT 5;

// ---------------------------------------------------------------------------
// Nettoyage — plus aucun nœud :Test, le graphe du kit intact
// ---------------------------------------------------------------------------

MATCH (n:Test) DETACH DELETE n;
MATCH (n:Test) RETURN count(n) AS test_restants;
MATCH (n) RETURN count(n) AS noeuds_du_kit;
