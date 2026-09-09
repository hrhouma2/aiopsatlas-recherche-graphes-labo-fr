// Contraintes d'unicité : garantissent qu'un même id ne crée jamais deux nœuds,
// et créent au passage un index sur chaque id (les MERGE du chargement restent
// rapides même sur des milliers de lignes).
CREATE CONSTRAINT etudiant_id IF NOT EXISTS FOR (e:Etudiant) REQUIRE e.id IS UNIQUE;
CREATE CONSTRAINT professeur_id IF NOT EXISTS FOR (p:Professeur) REQUIRE p.id IS UNIQUE;
CREATE CONSTRAINT cours_id IF NOT EXISTS FOR (c:Cours) REQUIRE c.id IS UNIQUE;
CREATE CONSTRAINT competence_id IF NOT EXISTS FOR (k:Competence) REQUIRE k.id IS UNIQUE;
CREATE CONSTRAINT ville_nom IF NOT EXISTS FOR (v:Ville) REQUIRE v.nom IS UNIQUE;

// Index de recherche sur les titres de cours (utile pour CONTAINS / STARTS WITH).
CREATE INDEX cours_titre IF NOT EXISTS FOR (c:Cours) ON (c.titre);
