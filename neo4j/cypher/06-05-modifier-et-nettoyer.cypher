// Module 6 — Leçon 05 : Modifier et nettoyer sans casser le graphe
// Exécution : .\labo.ps1 cypher 06-05-modifier-et-nettoyer.cypher
// Tout se passe sur des nœuds :Test créés ici et supprimés à la fin.
// Les nœuds du kit (Etudiant, Cours, …) ne sont jamais touchés.

// 0. Point de départ : aucun nœud :Test
MATCH (t:Test) RETURN count(t) AS test_avant;

// 1. CREATE : deux nœuds et une relation d'un coup
CREATE (a:Test {id: 'T1', nom: 'Alice'}),
       (b:Test {id: 'T2', nom: 'Bruno'}),
       (a)-[:CONNAIT {depuis: 2024}]->(b)
RETURN a.nom, b.nom;

// 2. SET : une propriété, puis plusieurs
MATCH (t:Test {id: 'T1'}) SET t.ville = 'Montréal' RETURN t;
MATCH (t:Test {id: 'T1'}) SET t.age = 31, t.actif = true RETURN t;

// 3. SET += : fusionner une map (ajoute/écrase sans toucher au reste)
MATCH (t:Test {id: 'T1'}) SET t += {age: 32, langue: 'fr'} RETURN t;

// 4. REMOVE : enlever une propriété (équivalent : SET t.langue = null)
MATCH (t:Test {id: 'T1'}) REMOVE t.langue RETURN t;

// 5. Ajouter puis retirer un label
MATCH (t:Test {id: 'T1'}) SET t:Vip RETURN labels(t) AS labels;
MATCH (t:Test {id: 'T1'}) REMOVE t:Vip RETURN labels(t) AS labels;

// 6. MERGE … ON CREATE SET … ON MATCH SET : la même requête deux fois
MERGE (t:Test {id: 'T3'})
ON CREATE SET t.nom = 'Chloé', t.cree_le = datetime(), t.vues = 1
ON MATCH SET t.vues = t.vues + 1
RETURN t.nom, t.vues;

MERGE (t:Test {id: 'T3'})
ON CREATE SET t.nom = 'Chloé', t.cree_le = datetime(), t.vues = 1
ON MATCH SET t.vues = t.vues + 1
RETURN t.nom, t.vues;

// 7. Créer une relation entre deux nœuds existants (MERGE : jamais en double)
MATCH (a:Test {id: 'T2'}), (c:Test {id: 'T3'})
MERGE (a)-[r:CONNAIT]->(c)
RETURN a.nom, type(r), c.nom;

MATCH (a:Test {id: 'T2'}), (c:Test {id: 'T3'})
MERGE (a)-[r:CONNAIT]->(c)
RETURN a.nom, type(r), c.nom;

MATCH (:Test)-[r:CONNAIT]->(:Test) RETURN count(r) AS relations_connait;

// 8. DELETE d'une relation seule (les nœuds restent)
MATCH (:Test {id: 'T2'})-[r:CONNAIT]->(:Test {id: 'T3'}) DELETE r;
MATCH (:Test)-[r:CONNAIT]->(:Test) RETURN count(r) AS relations_connait;

// 9. DELETE d'un nœud qui a ENCORE une relation : refusé.
//    Décommente pour voir l'erreur (cypher-shell s'arrête alors ici) :
// MATCH (t:Test {id: 'T1'}) DELETE t;
//    → "Cannot delete node<872>, because it still has relationships.
//       To delete this node, you must first delete its relationships."

// 10. DETACH DELETE : supprime le nœud ET ses relations
MATCH (t:Test {id: 'T1'}) DETACH DELETE t;
MATCH (t:Test) RETURN t.id AS id, t.nom AS nom ORDER BY id;

// 11. Suppression par lots : on crée 2 500 nœuds :Test puis on les supprime 1 000 par transaction
UNWIND range(1, 2500) AS i
CREATE (:Test {id: 'L' + toString(i), lot: true});
MATCH (t:Test) RETURN count(t) AS test_avant_lots;

MATCH (t:Test {lot: true})
CALL (t) {
  DETACH DELETE t
} IN TRANSACTIONS OF 1000 ROWS;
MATCH (t:Test) RETURN count(t) AS test_apres_lots;

// 12. Qui travaille sur la base en ce moment ?
SHOW TRANSACTIONS YIELD transactionId, currentQuery, status, elapsedTime
RETURN transactionId, left(currentQuery, 60) AS requete, status, elapsedTime;

// 13. Sauvegarde logique avec APOC : l'export vers un fichier est désactivé par défaut
//     (apoc.export.file.enabled=true nécessaire), mais l'export en flux fonctionne.
CALL apoc.export.json.all(null, {stream: true})
YIELD nodes, relationships, properties, data
RETURN nodes, relationships, properties, size(data) AS octets_json, left(data, 120) AS debut;

// 14. Nettoyage final : plus aucun nœud :Test
MATCH (t:Test) DETACH DELETE t;
MATCH (t:Test) RETURN count(t) AS test_restants;

// 15. Le graphe du kit est intact
MATCH (n) WHERE NOT n:Test
RETURN labels(n)[0] AS etiquette, count(*) AS noeuds ORDER BY etiquette;
