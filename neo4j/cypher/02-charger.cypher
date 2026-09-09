// Chargement du graphe du labo depuis les CSV montés dans /var/lib/neo4j/import.
// Tout est en MERGE : relancer ce script ne crée jamais de doublon.

// --- Nœuds -------------------------------------------------------------------
LOAD CSV WITH HEADERS FROM 'file:///villes.csv' AS ligne
MERGE (v:Ville {nom: ligne.nom})
SET v.pays = ligne.pays,
    v.latitude = toFloat(ligne.latitude),
    v.longitude = toFloat(ligne.longitude);

LOAD CSV WITH HEADERS FROM 'file:///competences.csv' AS ligne
MERGE (k:Competence {id: ligne.id})
SET k.nom = ligne.nom;

LOAD CSV WITH HEADERS FROM 'file:///professeurs.csv' AS ligne
MERGE (p:Professeur {id: ligne.id})
SET p.prenom = ligne.prenom,
    p.nom = ligne.nom,
    p.specialite = ligne.specialite,
    p.annees_experience = toInteger(ligne.annees_experience)
WITH p, ligne
MATCH (v:Ville {nom: ligne.ville})
MERGE (p)-[:HABITE]->(v);

LOAD CSV WITH HEADERS FROM 'file:///etudiants.csv' AS ligne
MERGE (e:Etudiant {id: ligne.id})
SET e.prenom = ligne.prenom,
    e.nom = ligne.nom,
    e.interet = ligne.interet,
    e.inscription_le = date(ligne.inscription_le)
WITH e, ligne
MATCH (v:Ville {nom: ligne.ville})
MERGE (e)-[:HABITE]->(v);

LOAD CSV WITH HEADERS FROM 'file:///cours.csv' AS ligne
MERGE (c:Cours {id: ligne.id})
SET c.titre = ligne.titre,
    c.categorie = ligne.categorie,
    c.sujet = ligne.sujet,
    c.niveau = ligne.niveau,
    c.prix = toFloat(ligne.prix),
    c.duree_heures = toInteger(ligne.duree_heures),
    c.date_publication = date(ligne.date_publication)
WITH c, ligne
MATCH (p:Professeur {id: ligne.professeur_id})
MERGE (p)-[:ENSEIGNE]->(c);

// --- Relations ---------------------------------------------------------------
LOAD CSV WITH HEADERS FROM 'file:///couvre.csv' AS ligne
MATCH (c:Cours {id: ligne.cours_id})
MATCH (k:Competence {id: ligne.competence_id})
MERGE (c)-[:COUVRE]->(k);

LOAD CSV WITH HEADERS FROM 'file:///prerequis.csv' AS ligne
MATCH (avant:Cours {id: ligne.prerequis_id})
MATCH (apres:Cours {id: ligne.cours_id})
MERGE (avant)-[:PREREQUIS_DE]->(apres);

LOAD CSV WITH HEADERS FROM 'file:///inscriptions.csv' AS ligne
MATCH (e:Etudiant {id: ligne.etudiant_id})
MATCH (c:Cours {id: ligne.cours_id})
MERGE (e)-[i:INSCRIT_A]->(c)
SET i.date = date(ligne.date),
    i.progression = toInteger(ligne.progression),
    i.note = CASE WHEN ligne.note = '' THEN null ELSE toInteger(ligne.note) END;

// --- Bilan -------------------------------------------------------------------
MATCH (n)
RETURN labels(n)[0] AS etiquette, count(*) AS noeuds
ORDER BY etiquette;
