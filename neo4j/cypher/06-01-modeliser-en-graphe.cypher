// Module 6 — Leçon 01 : Modéliser en graphe (nœuds, relations, propriétés)
// Exécution : .\labo.ps1 cypher 06-01-modeliser-en-graphe.cypher
// Toutes ces requêtes sont en lecture seule : elles ne modifient rien.

// 1. Combien de nœuds au total ?
MATCH (n) RETURN count(n) AS noeuds;

// 2. Les étiquettes (labels) présentes dans le graphe
CALL db.labels();

// 3. Les types de relations
CALL db.relationshipTypes();

// 4. Le schéma vu par Neo4j : un nœud par label, une relation par type
CALL db.schema.visualization();

// 5. Les nœuds par étiquette
MATCH (n) RETURN labels(n)[0] AS etiquette, count(*) AS noeuds ORDER BY etiquette;

// 6. Quelles relations partent de quel label vers quel label ?
MATCH (a)-[r]->(b)
RETURN labels(a)[0] AS depuis, type(r) AS relation, labels(b)[0] AS vers, count(*) AS n
ORDER BY depuis, relation;

// 7. Les propriétés d'un nœud Cours, d'un Etudiant et d'une Ville
MATCH (c:Cours {id: 'C0001'}) RETURN c;
MATCH (e:Etudiant {id: 'E0001'}) RETURN e;
MATCH (v:Ville {nom: 'Montréal'}) RETURN v;

// 8. Les propriétés d'une relation INSCRIT_A
MATCH (e:Etudiant {id: 'E0001'})-[i:INSCRIT_A]->(c:Cours) RETURN e.prenom, i, c.titre;

// 9. Quelles clés de propriété existent, par label ?
CALL db.schema.nodeTypeProperties() YIELD nodeLabels, propertyName, propertyTypes
RETURN nodeLabels[0] AS etiquette, propertyName AS propriete, propertyTypes[0] AS type
ORDER BY etiquette, propriete;

// 10. Contraintes et index posés par le kit (01-contraintes.cypher)
SHOW CONSTRAINTS;
SHOW INDEXES;
