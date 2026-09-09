// Module 6 — Leçon 04 : Cypher niveau 2 (chemins, plus court chemin, agrégations)
// Exécution : .\labo.ps1 cypher 06-04-cypher-niveau-2.cypher
// Lecture seule.

// 1. Deux sauts : les villes des étudiants inscrits à un cours
MATCH (c:Cours {id: 'C0111'})<-[:INSCRIT_A]-(e:Etudiant)-[:HABITE]->(v:Ville)
RETURN v.nom AS ville, count(e) AS etudiants
ORDER BY etudiants DESC, ville;

// 2. Longueur variable : ce qu'il faut suivre avant « Maîtriser Neo4j », de 1 à 3 sauts en arrière
MATCH (avant:Cours)-[:PREREQUIS_DE*1..3]->(c:Cours {id: 'C0110'})
RETURN avant.id AS id, avant.titre AS titre, avant.niveau AS niveau;

// 3. Le même parcours, avec la distance
MATCH chemin = (avant:Cours)-[:PREREQUIS_DE*1..3]->(c:Cours {id: 'C0110'})
RETURN avant.id AS id, length(chemin) AS sauts
ORDER BY sauts;

// 4. Plus court chemin entre deux cours Neo4j (du premier au dernier de la filière)
MATCH (debut:Cours {id: 'C0111'}), (fin:Cours {id: 'C0110'}),
      chemin = shortestPath((debut)-[:PREREQUIS_DE*]-(fin))
RETURN length(chemin) AS sauts, [n IN nodes(chemin) | n.titre] AS parcours;

// 5. Tous les plus courts chemins (ici il n'y en a qu'un : la filière est linéaire)
MATCH (debut:Cours {id: 'C0111'}), (fin:Cours {id: 'C0110'}),
      chemin = allShortestPaths((debut)-[:PREREQUIS_DE*]-(fin))
RETURN count(chemin) AS nb_chemins;

// 6. Pas de chemin entre deux sujets différents : shortestPath renvoie… rien
MATCH (a:Cours {id: 'C0111'}), (b:Cours {id: 'C0001'}),
      chemin = shortestPath((a)-[:PREREQUIS_DE*]-(b))
RETURN chemin;

// 7. OPTIONAL MATCH : garder les cours Neo4j même sans prérequis
MATCH (c:Cours {sujet: 'Neo4j'})
OPTIONAL MATCH (avant:Cours)-[:PREREQUIS_DE]->(c)
RETURN c.id AS id, c.titre AS titre, avant.id AS prerequis
ORDER BY id;

// 8. collect : une ligne par professeur, la liste de ses sujets
MATCH (p:Professeur)-[:ENSEIGNE]->(c:Cours)
RETURN p.nom AS professeur, collect(DISTINCT c.sujet) AS sujets
ORDER BY professeur LIMIT 3;

// 9. avg / sum / max / min sur les inscriptions d'un cours
MATCH (e:Etudiant)-[i:INSCRIT_A]->(c:Cours {id: 'C0111'})
RETURN count(i) AS inscrits, avg(i.progression) AS progression_moyenne,
       max(i.note) AS meilleure_note, avg(i.note) AS note_moyenne,
       sum(CASE WHEN i.progression = 100 THEN 1 ELSE 0 END) AS termines;

// 10. size() d'une liste et d'un motif
MATCH (p:Professeur {id: 'P001'})-[:ENSEIGNE]->(c:Cours)
WITH p, collect(c.titre) AS titres
RETURN p.nom, size(titres) AS nb_cours, titres[0..3] AS trois_premiers;

// 11. UNWIND : éclater une liste en lignes
WITH ['Neo4j', 'Docker', 'Kafka'] AS sujets
UNWIND sujets AS sujet
MATCH (c:Cours {sujet: sujet})
RETURN sujet, count(c) AS nb_cours, round(avg(c.prix), 2) AS prix_moyen;

// 12. WITH … ORDER BY … LIMIT : le top 3 des cours les plus suivis, puis la suite du raisonnement
MATCH (e:Etudiant)-[:INSCRIT_A]->(c:Cours)
WITH c, count(e) AS inscrits
ORDER BY inscrits DESC, c.id LIMIT 3
MATCH (p:Professeur)-[:ENSEIGNE]->(c)
RETURN c.id AS id, c.titre AS titre, inscrits, p.nom AS professeur;

// 13. Recommandation collaborative : « ceux qui ont suivi ce cours ont aussi suivi… »
MATCH (moi:Etudiant {id: 'E0001'})-[:INSCRIT_A]->(c:Cours)<-[:INSCRIT_A]-(autre:Etudiant)-[:INSCRIT_A]->(reco:Cours)
WHERE autre <> moi
  AND NOT EXISTS { (moi)-[:INSCRIT_A]->(reco) }
RETURN reco.id AS id, reco.titre AS titre, count(DISTINCT autre) AS co_inscrits
ORDER BY co_inscrits DESC, id
LIMIT 5;

// 14. Recommandation par compétence : cours couvrant les compétences de mes cours terminés, non suivis
MATCH (moi:Etudiant {id: 'E0001'})-[i:INSCRIT_A]->(fini:Cours)-[:COUVRE]->(k:Competence)<-[:COUVRE]-(reco:Cours)
WHERE i.progression = 100
  AND NOT EXISTS { (moi)-[:INSCRIT_A]->(reco) }
RETURN reco.id AS id, reco.titre AS titre, collect(DISTINCT k.nom) AS competences_communes, count(DISTINCT k) AS score
ORDER BY score DESC, id
LIMIT 5;

// 15. Le professeur le plus « connecté » : le plus d'étudiants distincts via ses cours
MATCH (p:Professeur)-[:ENSEIGNE]->(:Cours)<-[:INSCRIT_A]-(e:Etudiant)
RETURN p.prenom + ' ' + p.nom AS professeur, count(DISTINCT e) AS etudiants_distincts
ORDER BY etudiants_distincts DESC LIMIT 3;

// 16. La ville avec le plus d'étudiants
MATCH (e:Etudiant)-[:HABITE]->(v:Ville)
RETURN v.nom AS ville, v.pays AS pays, count(e) AS etudiants
ORDER BY etudiants DESC LIMIT 3;

// 17. EXPLAIN : le plan sans exécuter
EXPLAIN MATCH (c:Cours {id: 'C0111'}) RETURN c.titre;

// 18. PROFILE avec index (contrainte d'unicité sur Cours.id) : très peu de db hits
PROFILE MATCH (c:Cours {id: 'C0111'}) RETURN c.titre;

// 19. PROFILE sans index (Cours.sujet n'est pas indexé) : balayage du label + filtre
PROFILE MATCH (c:Cours {sujet: 'Neo4j'}) RETURN c.titre;

// 20. Bonus APOC : statistiques du graphe en une procédure
CALL apoc.meta.stats() YIELD nodeCount, relCount, labels, relTypesCount
RETURN nodeCount, relCount, labels, relTypesCount;

// 21. Bonus APOC : l'aide intégrée
CALL apoc.help('meta.stats') YIELD name, text RETURN name, text;
