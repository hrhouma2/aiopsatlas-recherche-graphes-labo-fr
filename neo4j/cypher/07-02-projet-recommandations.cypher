// Module 7 — Leçon 02 : Corrigé du projet final, partie Neo4j (E6 et E7)
// Lecture seule : aucune écriture dans le graphe.
// Exécution : ./labo.sh cypher 07-02-projet-recommandations.cypher
//             .\labo.ps1 cypher 07-02-projet-recommandations.cypher

// ---------------------------------------------------------------------------
// E6 — « Ceux qui ont suivi X ont aussi suivi… »
// ---------------------------------------------------------------------------

// 1. Quel cours choisir comme X ? Le plus populaire (nombre d'inscriptions).
//    Trois cours sont à égalité avec 10 inscrits : on départage par identifiant.
MATCH (e:Etudiant)-[:INSCRIT_A]->(c:Cours)
RETURN c.id AS id, c.titre AS titre, c.sujet AS sujet, count(e) AS inscrits
ORDER BY inscrits DESC, id
LIMIT 5;

// 2. Les 5 recommandations pour C0213 : les cours co-suivis par ses étudiants,
//    classés par nombre d'étudiants en commun (départage par titre).
MATCH (x:Cours {id: 'C0213'})<-[:INSCRIT_A]-(e:Etudiant)-[:INSCRIT_A]->(autre:Cours)
WHERE autre <> x
RETURN autre.id AS id, autre.titre AS titre, autre.categorie AS categorie,
       count(DISTINCT e) AS etudiants_communs
ORDER BY etudiants_communs DESC, titre
LIMIT 5;

// 3. Contrôle : combien d'étudiants suivent C0213 et combien de cours distincts
//    ils suivent par ailleurs (la « base » des recommandations).
MATCH (x:Cours {id: 'C0213'})<-[:INSCRIT_A]-(e:Etudiant)
OPTIONAL MATCH (e)-[:INSCRIT_A]->(autre:Cours) WHERE autre <> x
RETURN count(DISTINCT e) AS inscrits, count(DISTINCT autre) AS cours_cosuivis;

// 4. Variante personnalisée : les recommandations pour UN étudiant donné,
//    en excluant les cours qu'il suit déjà. On prend le premier étudiant
//    inscrit à C0213 (par identifiant).
MATCH (moi:Etudiant)-[:INSCRIT_A]->(:Cours {id: 'C0213'})
WITH moi ORDER BY moi.id LIMIT 1
MATCH (moi)-[:INSCRIT_A]->(suivi:Cours)<-[:INSCRIT_A]-(pair:Etudiant)-[:INSCRIT_A]->(reco:Cours)
WHERE pair <> moi AND NOT (moi)-[:INSCRIT_A]->(reco)
RETURN moi.id AS etudiant, moi.prenom AS prenom,
       reco.id AS id, reco.titre AS titre, count(DISTINCT pair) AS pairs
ORDER BY pairs DESC, titre
LIMIT 5;

// ---------------------------------------------------------------------------
// E7 — Parcours conseillé : la chaîne de prérequis jusqu'à un cours avancé
// ---------------------------------------------------------------------------

// 5. Trouver deux cours reliés par une chaîne PREREQUIS_DE longue :
//    départ sans prérequis, arrivée de niveau avancé, chemin de 3 étapes ou plus.
MATCH p = (depart:Cours)-[:PREREQUIS_DE*3..6]->(arrivee:Cours {niveau: 'avance'})
WHERE NOT ( ()-[:PREREQUIS_DE]->(depart) )
RETURN depart.id AS depart, depart.titre AS titre_depart,
       arrivee.id AS arrivee, arrivee.titre AS titre_arrivee,
       length(p) AS etapes
ORDER BY etapes DESC, depart
LIMIT 5;

// 6. Le parcours conseillé : plus court chemin de « Docker expliqué simplement »
//    (C0001) à « Docker avancé : industrialiser des conteneurs en production » (C0002).
MATCH (a:Cours {id: 'C0001'}), (b:Cours {id: 'C0002'})
MATCH p = shortestPath((a)-[:PREREQUIS_DE*..10]->(b))
RETURN length(p) AS etapes,
       [n IN nodes(p) | n.id + ' — ' + n.titre + ' (' + n.niveau + ')'] AS parcours;

// 7. Le même parcours présenté ligne par ligne, avec la durée cumulée.
MATCH (a:Cours {id: 'C0001'}), (b:Cours {id: 'C0002'})
MATCH p = shortestPath((a)-[:PREREQUIS_DE*..10]->(b))
UNWIND range(0, length(p)) AS i
WITH nodes(p)[i] AS c, i,
     reduce(total = 0, n IN nodes(p)[0..i+1] | total + n.duree_heures) AS heures_cumulees
RETURN i + 1 AS etape, c.id AS id, c.titre AS titre, c.niveau AS niveau,
       c.duree_heures AS heures, heures_cumulees;

// 8. Contrôle : est-ce vraiment le seul chemin ? (tous les chemins de C0001 à C0002)
MATCH p = (:Cours {id: 'C0001'})-[:PREREQUIS_DE*..10]->(:Cours {id: 'C0002'})
RETURN length(p) AS etapes, [n IN nodes(p) | n.id] AS identifiants
ORDER BY etapes;

// 9. Bonus : « que dois-je avoir suivi avant C0002 ? » — tous les prérequis,
//    directs et indirects, avec leur distance.
MATCH p = (avant:Cours)-[:PREREQUIS_DE*1..10]->(cible:Cours {id: 'C0002'})
RETURN avant.id AS id, avant.titre AS titre, min(length(p)) AS distance
ORDER BY distance;
