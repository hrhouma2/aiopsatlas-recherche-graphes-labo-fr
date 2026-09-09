// Module 6 — Leçon 03 : Cypher niveau 1 (MATCH, WHERE, RETURN)
// Exécution : .\labo.ps1 cypher 06-03-cypher-niveau-1.cypher
// Lecture seule.

// 1. Cinq cours, tels quels
MATCH (c:Cours) RETURN c LIMIT 5;

// 2. Seulement des propriétés, avec des alias
MATCH (c:Cours)
RETURN c.id AS id, c.titre AS titre, c.prix AS prix
LIMIT 5;

// 3. Égalité sur une propriété (dans le motif) ...
MATCH (c:Cours {sujet: 'Neo4j'}) RETURN c.titre, c.niveau ORDER BY c.titre;

// 4. ... ou dans WHERE (équivalent)
MATCH (c:Cours) WHERE c.sujet = 'Neo4j' AND c.niveau = 'debutant'
RETURN c.titre, c.prix;

// 5. IN, CONTAINS, STARTS WITH
MATCH (c:Cours) WHERE c.sujet IN ['Neo4j', 'Elasticsearch', 'Kibana']
RETURN c.sujet, count(*) AS n ORDER BY n DESC;

MATCH (c:Cours) WHERE c.titre CONTAINS 'cluster'
RETURN c.titre ORDER BY c.titre LIMIT 5;

MATCH (c:Cours) WHERE c.titre STARTS WITH 'Les bases de'
RETURN count(*) AS nb_les_bases_de;

// 6. Expression régulière : les titres qui contiennent « zéro » (insensible à la casse)
MATCH (c:Cours) WHERE c.titre =~ '(?i).*zéro.*'
RETURN c.titre LIMIT 5;

// 7. Comparaison de dates
MATCH (c:Cours) WHERE c.date_publication >= date('2025-01-01')
RETURN count(*) AS publies_depuis_2025;

MATCH (c:Cours) WHERE c.date_publication >= date('2026-01-01')
RETURN c.titre, c.date_publication ORDER BY c.date_publication DESC LIMIT 5;

// 8. ORDER BY, SKIP, LIMIT : la 2e page des cours les plus chers
MATCH (c:Cours)
RETURN c.titre, c.prix
ORDER BY c.prix DESC, c.titre
SKIP 5 LIMIT 5;

// 9. count et DISTINCT
MATCH (c:Cours) RETURN count(c) AS cours, count(DISTINCT c.sujet) AS sujets, count(DISTINCT c.categorie) AS categories;

MATCH (c:Cours) RETURN DISTINCT c.niveau AS niveau ORDER BY niveau;

// 10. Motif à une relation : les cours d'un professeur
MATCH (p:Professeur {id: 'P001'})-[:ENSEIGNE]->(c:Cours)
RETURN p.prenom + ' ' + p.nom AS professeur, count(c) AS nb_cours;

MATCH (p:Professeur {id: 'P001'})-[:ENSEIGNE]->(c:Cours)
RETURN c.titre, c.sujet ORDER BY c.titre LIMIT 5;

// 11. Les étudiants inscrits à un cours
MATCH (e:Etudiant)-[i:INSCRIT_A]->(c:Cours {id: 'C0001'})
RETURN e.prenom, e.nom, i.progression, i.note
ORDER BY i.progression DESC;

// 12. Le sens de la relation compte : sans flèche on trouve les deux sens
MATCH (c:Cours {id: 'C0001'})-[:PREREQUIS_DE]->(suite:Cours)
RETURN 'C0001 est prérequis de' AS sens, suite.id AS id, suite.titre AS titre
UNION ALL
MATCH (avant:Cours)-[:PREREQUIS_DE]->(c:Cours {id: 'C0001'})
RETURN 'prérequis de C0001' AS sens, avant.id AS id, avant.titre AS titre;

// 12 bis. Sans flèche : les deux sens d'un coup
MATCH (c:Cours {id: 'C0001'})-[:PREREQUIS_DE]-(autre:Cours)
RETURN autre.id, autre.titre;

// 13. Ce qui n'existe pas : les étudiants sans aucune inscription
MATCH (e:Etudiant)
WHERE NOT EXISTS { (e)-[:INSCRIT_A]->(:Cours) }
RETURN count(e) AS etudiants_sans_inscription;

// 14. Et les cours sans aucun inscrit ?
MATCH (c:Cours)
WHERE NOT EXISTS { (:Etudiant)-[:INSCRIT_A]->(c) }
RETURN count(c) AS cours_sans_inscrit;

// 15. Les cours qui n'ont pas de prérequis
MATCH (c:Cours)
WHERE NOT EXISTS { (:Cours)-[:PREREQUIS_DE]->(c) }
RETURN count(c) AS cours_sans_prerequis;

// 16. Retourner un chemin entier (dans Browser : vue graphe)
MATCH chemin = (p:Professeur)-[:ENSEIGNE]->(c:Cours {id: 'C0001'})<-[:INSCRIT_A]-(e:Etudiant)
RETURN chemin LIMIT 3;

// 17. Paramètres : dans Browser tape d'abord  :param sujet => 'Neo4j'
// (dans cypher-shell : :param sujet => 'Neo4j' fonctionne aussi)
:param sujet => 'Neo4j';
MATCH (c:Cours {sujet: $sujet}) RETURN count(c) AS nb_cours_sujet;
