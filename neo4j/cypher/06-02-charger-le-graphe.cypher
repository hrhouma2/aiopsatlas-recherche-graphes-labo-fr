// Module 6 — Leçon 02 : Charger le graphe (contraintes, LOAD CSV, MERGE)
// Exécution : .\labo.ps1 cypher 06-02-charger-le-graphe.cypher
// Ne recharge PAS le graphe (c'est le rôle de .\labo.ps1 charger-graphe) :
// on regarde ce que LOAD CSV lit, on teste les conversions, on prouve MERGE
// sur des nœuds :Test que l'on supprime à la fin.

// 1. Les contraintes du kit sont-elles bien en place ? (posées par 01-contraintes.cypher)
SHOW CONSTRAINTS YIELD name, type, labelsOrTypes, properties;

// 2. Regarder ce que LOAD CSV lit, sans rien écrire : chaque ligne est une map de chaînes
LOAD CSV WITH HEADERS FROM 'file:///villes.csv' AS ligne
RETURN ligne LIMIT 3;

// 3. Même chose sur inscriptions.csv : la note vide arrive comme chaîne vide ''
LOAD CSV WITH HEADERS FROM 'file:///inscriptions.csv' AS ligne
RETURN ligne.etudiant_id, ligne.cours_id, ligne.progression, ligne.note
LIMIT 5;

// 4. Combien de lignes dans chaque CSV ? (comparer aux nœuds/relations créés)
LOAD CSV WITH HEADERS FROM 'file:///cours.csv' AS ligne RETURN 'cours.csv' AS fichier, count(*) AS lignes
UNION ALL
LOAD CSV WITH HEADERS FROM 'file:///inscriptions.csv' AS ligne RETURN 'inscriptions.csv' AS fichier, count(*) AS lignes
UNION ALL
LOAD CSV WITH HEADERS FROM 'file:///couvre.csv' AS ligne RETURN 'couvre.csv' AS fichier, count(*) AS lignes
UNION ALL
LOAD CSV WITH HEADERS FROM 'file:///prerequis.csv' AS ligne RETURN 'prerequis.csv' AS fichier, count(*) AS lignes;

// 5. Les conversions utilisées par 02-charger.cypher
RETURN toInteger('5') AS entier, toFloat('129') AS reel, date('2024-08-14') AS d,
       date('2024-08-14').year AS annee,
       CASE WHEN '' = '' THEN null ELSE toInteger('') END AS note_vide,
       CASE WHEN '4' = '' THEN null ELSE toInteger('4') END AS note_4;

// 6. Sans conversion, la comparaison est textuelle : '9' > '10' !
RETURN '9' > '10' AS texte, toInteger('9') > toInteger('10') AS nombre;

// 7. MERGE vs CREATE, sur des nœuds :Test (jamais sur le graphe du kit)
CREATE (:Test {id: 'T1', origine: 'create'});
CREATE (:Test {id: 'T1', origine: 'create'});
MATCH (t:Test {id: 'T1'}) RETURN count(t) AS apres_deux_CREATE;

MERGE (t:Test {id: 'T2'}) SET t.origine = 'merge';
MERGE (t:Test {id: 'T2'}) SET t.origine = 'merge';
MATCH (t:Test {id: 'T2'}) RETURN count(t) AS apres_deux_MERGE;

// 8. Nettoyage des nœuds :Test
MATCH (t:Test) DETACH DELETE t;
MATCH (t:Test) RETURN count(t) AS test_restants;

// 9. Bilan par étiquette (le même que la fin de 02-charger.cypher)
MATCH (n)
RETURN labels(n)[0] AS etiquette, count(*) AS noeuds
ORDER BY etiquette;

// 10. Bilan par type de relation
MATCH ()-[r]->()
RETURN type(r) AS relation, count(*) AS n
ORDER BY relation;

// 11. Total nœuds + relations : à comparer avant/après un nouveau charger-graphe
MATCH (n) WITH count(n) AS noeuds
MATCH ()-[r]->() RETURN noeuds, count(r) AS relations;

// 12. Combien d'inscriptions avec note, sans note ? (le CASE WHEN ... THEN null a fait son travail)
MATCH ()-[i:INSCRIT_A]->()
RETURN i.note IS NOT NULL AS a_une_note, count(*) AS n;

// 13. CALL {} IN TRANSACTIONS : la forme pour les gros fichiers, ici en lecture seule
//     (on vérifie que chaque ligne du CSV a bien sa relation, 500 lignes par transaction)
LOAD CSV WITH HEADERS FROM 'file:///inscriptions.csv' AS ligne
CALL (ligne) {
  MATCH (e:Etudiant {id: ligne.etudiant_id})-[i:INSCRIT_A]->(c:Cours {id: ligne.cours_id})
  RETURN i
} IN TRANSACTIONS OF 500 ROWS
RETURN count(i) AS relations_verifiees;
