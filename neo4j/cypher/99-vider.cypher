// Vide complètement le graphe (nœuds + relations), par lots pour ne pas
// saturer la mémoire. Les contraintes et index sont conservés : relancer
// 02-charger.cypher reconstruit tout.
MATCH (n)
CALL (n) {
  DETACH DELETE n
} IN TRANSACTIONS OF 1000 ROWS;

MATCH (n) RETURN count(n) AS noeuds_restants;
