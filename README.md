# Labo « Recherche & graphes » — Elasticsearch, Kibana, OpenSearch, Neo4j

Kit de travaux pratiques du cours **[Elasticsearch, OpenSearch, Kibana et Neo4j : le labo Docker clé en main](https://aiopsatlas.com/cours/elasticsearch-opensearch-neo4j-labo-docker)** sur aiopsatlas.com.

Tout tourne dans Docker. Vous n'installez **rien d'autre** : ni Java, ni Node, ni curl. Chaque commande du cours a été exécutée sur ce kit, avec exactement ces versions :

| Service | Version | Adresse | Rôle |
| --- | --- | --- | --- |
| Elasticsearch | 9.5.3 | http://localhost:9200 | moteur de recherche |
| Kibana | 9.5.3 | http://localhost:5601 | Dev Tools, Discover, tableaux de bord |
| Neo4j Community | 5.26 | http://localhost:7474 · bolt://localhost:7687 | base de graphes (Cypher) |
| OpenSearch *(optionnel)* | 3.8.0 | http://localhost:9201 | le « cousin » open source d'Elasticsearch |
| OpenSearch Dashboards *(optionnel)* | 3.8.0 | http://localhost:5602 | l'équivalent de Kibana |

Identifiants Neo4j : `neo4j` / `aiopsatlas2026`. Elasticsearch et OpenSearch tournent **sans sécurité** : c'est un labo local, jamais une configuration de production.

## Démarrer en 3 commandes

```bash
# Linux, macOS, WSL2, Git Bash                # Windows PowerShell
./labo.sh prerequis                           .\labo.ps1 prerequis
./labo.sh demarrer                            .\labo.ps1 demarrer
./labo.sh importer                            .\labo.ps1 importer
./labo.sh charger-graphe                      .\labo.ps1 charger-graphe
```

La première fois, le téléchargement des images prend plusieurs minutes (~6 Go d'images, ~12 Go avec OpenSearch). Ensuite le labo démarre en moins d'une minute.

Pour ajouter OpenSearch : `./labo.sh demarrer opensearch` puis `./labo.sh importer opensearch`.

## Prérequis

- Docker Desktop (Windows, macOS) ou Docker Engine + plugin Compose (Linux)
- 8 Go de RAM sur la machine, dont **4 Go alloués à Docker** (6 Go avec OpenSearch)
- 15 Go d'espace disque libre (25 Go avec OpenSearch)
- Ports libres : 9200, 5601, 7474, 7687 (+ 9201, 5602 pour OpenSearch)

`./labo.sh prerequis` vérifie tout cela pour vous et vous dit exactement quoi corriger.

## Ce que contient le kit

```
docker-compose.yml          la stack complète, versions figées, healthchecks
labo.sh / labo.ps1          le même outil en bash et en PowerShell
elasticsearch/
  mappings/                 cours.json, avis.json, acces.json (types de champs, analyseur français)
  donnees/                  cours.ndjson, avis.ndjson, acces.ndjson (format _bulk)
  requetes/                 toutes les requêtes du cours, à coller dans Kibana Dev Tools
neo4j/
  import/                   CSV chargés par LOAD CSV (étudiants, cours, inscriptions…)
  cypher/                   contraintes, chargement, requêtes du cours, remise à zéro
kibana/                     le tableau de bord « Labo — Trafic du site » à importer (module 4)
outils/generer-donnees.mjs  régénère les jeux de données (déterministe) — optionnel
outils/tester-requetes.mjs  rejoue un fichier de requêtes sur Elasticsearch ou OpenSearch
```

Rejouer toutes les requêtes d'un module, par exemple le module 3 :

```bash
node outils/tester-requetes.mjs elasticsearch/requetes/03-01-match-multi-match-term-et-bool.txt
node outils/tester-requetes.mjs elasticsearch/requetes/05-02-opensearch-seulement.txt --url http://localhost:9201   # côté OpenSearch
```

## Le jeu de données : une plateforme de cours en ligne

Le même univers sert aux trois moteurs, pour comparer ce que chacun fait de mieux.

| Jeu | Volume | Utilisé dans |
| --- | --- | --- |
| `cours` — titre, description, catégorie, niveau, prix, tags, note | 504 documents | recherche full-text, filtres, agrégations |
| `avis` — note, texte, ville, date | 609 documents | analyse de texte, agrégations imbriquées |
| `acces` — journaux web sur 30 jours | 12 000 lignes | Kibana Discover / Lens, OpenSearch Dashboards |
| graphe Neo4j — étudiants, professeurs, cours, compétences, prérequis, inscriptions | 872 nœuds · 3 712 relations | Cypher, recommandations, plus court chemin |

## Quand quelque chose ne marche pas

1. `./labo.sh etat` — qui répond, qui ne répond pas.
2. `./labo.sh journal elasticsearch` (ou `kibana`, `neo4j`, `opensearch`) — les 100 dernières lignes.
3. Le module 1 du cours (« Lire l'état et réparer en 5 minutes ») liste les 10 pannes classiques et leur remède.
4. En dernier recours : `./labo.sh reinitialiser` puis `./labo.sh demarrer` — vous repartez d'un labo neuf en deux minutes.

## Licence

Code et jeux de données : MIT. Les leçons, quiz et certificats font partie du cours sur [aiopsatlas.com](https://aiopsatlas.com).
