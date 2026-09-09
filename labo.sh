#!/usr/bin/env bash
# Labo « Recherche & graphes » — point d'entrée unique (Linux, macOS, WSL2, Git Bash).
#
#   ./labo.sh prerequis               vérifie Docker, la mémoire, les ports
#   ./labo.sh demarrer [opensearch]   démarre la stack et attend qu'elle soit prête
#   ./labo.sh etat                    état des conteneurs et des services
#   ./labo.sh importer [opensearch]   crée les index cours/avis/acces et charge les données
#   ./labo.sh charger-graphe          charge le graphe Neo4j depuis les CSV
#   ./labo.sh cypher <fichier>        exécute un script Cypher du dossier neo4j/cypher
#   ./labo.sh journal <service>       100 dernières lignes de journal d'un service
#   ./labo.sh arreter                 arrête les conteneurs (les données restent)
#   ./labo.sh reinitialiser           supprime conteneurs ET données (repart de zéro)
#
# Toutes les commandes qui parlent aux moteurs passent par `docker compose exec` :
# rien d'autre que Docker n'est requis sur votre machine.
set -euo pipefail
cd "$(dirname "$0")"

# Git Bash (Windows) réécrit les chemins /labo/... en C:/Program Files/Git/labo/...
# avant de les passer à docker : on désactive cette conversion.
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'

NEO4J_MDP="aiopsatlas2026"
ROUGE=$'\e[31m'; VERT=$'\e[32m'; JAUNE=$'\e[33m'; GRIS=$'\e[90m'; FIN=$'\e[0m'

ok()    { echo "  ${VERT}✔${FIN} $*"; }
ko()    { echo "  ${ROUGE}✘${FIN} $*"; }
info()  { echo "${GRIS}— $*${FIN}"; }
titre() { echo; echo "== $* =="; }

compose() { docker compose "$@"; }

# Exécute curl à l'intérieur d'un conteneur (elasticsearch ou opensearch).
requete() { # requete <service> <methode> <chemin> [fichier-donnees] [content-type]
  local service="$1" methode="$2" chemin="$3" fichier="${4:-}" type="${5:-application/json}"
  if [[ -n "$fichier" ]]; then
    compose exec -T "$service" curl -sS -X "$methode" "http://localhost:9200${chemin}" \
      -H "Content-Type: ${type}" --data-binary "@${fichier}"
  else
    compose exec -T "$service" curl -sS -X "$methode" "http://localhost:9200${chemin}"
  fi
}

cmd_prerequis() {
  titre "Prérequis"
  local erreurs=0

  if command -v docker >/dev/null 2>&1; then ok "docker : $(docker --version)"; else ko "docker introuvable — installez Docker Desktop (Windows/macOS) ou Docker Engine (Linux)"; erreurs=1; fi
  if docker info >/dev/null 2>&1; then ok "le démon Docker répond"; else ko "le démon Docker ne répond pas — lancez Docker Desktop et attendez l'icône verte"; erreurs=1; fi
  if docker compose version >/dev/null 2>&1; then ok "docker compose : $(docker compose version --short)"; else ko "docker compose (v2) introuvable"; erreurs=1; fi

  if docker info >/dev/null 2>&1; then
    local mem_octets mem_go
    mem_octets=$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)
    mem_go=$(( mem_octets / 1024 / 1024 / 1024 ))
    if (( mem_go >= 6 )); then ok "mémoire disponible pour Docker : ${mem_go} Go"
    elif (( mem_go >= 4 )); then echo "  ${JAUNE}!${FIN} mémoire pour Docker : ${mem_go} Go — suffisant sans OpenSearch ; 6 Go conseillés pour le profil opensearch"
    else ko "mémoire pour Docker : ${mem_go} Go — il en faut au moins 4 (Docker Desktop → Settings → Resources, ou .wslconfig sous Windows)"; erreurs=1; fi

    local cpus
    cpus=$(docker info --format '{{.NCPU}}' 2>/dev/null || echo 0)
    if (( cpus >= 2 )); then ok "processeurs : ${cpus}"; else ko "processeurs : ${cpus} — 2 minimum"; erreurs=1; fi
  fi

  for port in 9200 5601 7474 7687; do
    if (command -v ss >/dev/null && ss -ltn 2>/dev/null | grep -q ":${port} ") || (command -v lsof >/dev/null && lsof -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1); then
      if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^labo-'; then ok "port ${port} : utilisé par le labo lui-même"
      else ko "port ${port} déjà occupé par un autre programme — arrêtez-le ou changez le port dans docker-compose.yml"; erreurs=1; fi
    else ok "port ${port} libre"; fi
  done

  echo
  if (( erreurs == 0 )); then echo "${VERT}Tout est prêt. Lancez : ./labo.sh demarrer${FIN}"; else echo "${ROUGE}Corrigez les points marqués ✘ puis relancez ./labo.sh prerequis${FIN}"; exit 1; fi
}

# Attend qu'un conteneur soit « healthy » (ou simplement « running » s'il n'a
# pas de healthcheck, comme opensearch-dashboards).
attendre_sante() { # attendre_sante <service> <secondes-max>
  local service="$1" max="${2:-240}" ecoule=0 etat
  printf "  %-24s" "$service"
  while (( ecoule < max )); do
    etat=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "labo-${service}" 2>/dev/null || echo "absent")
    case "$etat" in
      healthy) echo " ${VERT}prêt${FIN} (${ecoule}s)"; return 0 ;;
      running) echo " ${VERT}démarré${FIN} (${ecoule}s)"; return 0 ;;
      unhealthy|exited|dead) echo " ${ROUGE}${etat}${FIN}"; return 1 ;;
    esac
    sleep 3; ecoule=$((ecoule+3)); printf "."
  done
  echo " ${ROUGE}délai dépassé${FIN}"; return 1
}

cmd_demarrer() {
  local profil=()
  [[ "${1:-}" == "opensearch" ]] && profil=(--profile opensearch)
  titre "Téléchargement des images (long la première fois : ~6 Go, ~12 Go avec OpenSearch)"
  compose "${profil[@]}" pull --quiet
  titre "Démarrage"
  compose "${profil[@]}" up -d
  titre "Attente que chaque service soit prêt"
  local echec=0
  attendre_sante elasticsearch 240 || echec=1
  attendre_sante kibana 240 || echec=1
  attendre_sante neo4j 240 || echec=1
  if [[ "${1:-}" == "opensearch" ]]; then
    attendre_sante opensearch 240 || echec=1
    attendre_sante opensearch-dashboards 120 || echec=1
  fi
  echo
  if (( echec == 0 )); then
    echo "${VERT}Le labo est prêt.${FIN}"
    echo "  Kibana                 http://localhost:5601   (Dev Tools : menu ☰ → Management → Dev Tools)"
    echo "  Elasticsearch          http://localhost:9200"
    echo "  Neo4j Browser          http://localhost:7474   (utilisateur neo4j · mot de passe ${NEO4J_MDP})"
    if [[ "${1:-}" == "opensearch" ]]; then
      echo "  OpenSearch Dashboards  http://localhost:5602"
      echo "  OpenSearch             http://localhost:9201"
    fi
    echo
    echo "Étape suivante : ./labo.sh importer   puis   ./labo.sh charger-graphe"
  else
    echo "${ROUGE}Un service n'a pas démarré.${FIN} Regardez son journal : ./labo.sh journal <service>"
    echo "Les causes classiques et leurs remèdes sont dans la leçon « Lire l'état et réparer en 5 minutes »."
    exit 1
  fi
}

cmd_etat() {
  titre "Conteneurs"
  compose --profile opensearch ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}'
  titre "Services"
  if requete elasticsearch GET /_cluster/health >/dev/null 2>&1; then
    ok "Elasticsearch : $(requete elasticsearch GET '/_cluster/health?filter_path=status,number_of_nodes')"
    echo "     index : $(requete elasticsearch GET '/_cat/indices/cours,avis,acces?h=index,docs.count&s=index' 2>/dev/null | tr '\n' ' ' || echo 'aucun index du labo')"
  else ko "Elasticsearch ne répond pas"; fi
  if compose exec -T kibana curl -fsS http://localhost:5601/api/status >/dev/null 2>&1; then ok "Kibana répond (http://localhost:5601)"; else ko "Kibana ne répond pas encore"; fi
  if compose exec -T neo4j cypher-shell -u neo4j -p "$NEO4J_MDP" "MATCH (n) RETURN count(n) AS n" >/dev/null 2>&1; then
    ok "Neo4j répond — nœuds : $(compose exec -T neo4j cypher-shell -u neo4j -p "$NEO4J_MDP" --format plain "MATCH (n) RETURN count(n)" | tail -n 1)"
  else ko "Neo4j ne répond pas"; fi
  if docker ps --format '{{.Names}}' | grep -q '^labo-opensearch$'; then
    if requete opensearch GET /_cluster/health >/dev/null 2>&1; then ok "OpenSearch : $(requete opensearch GET '/_cluster/health?filter_path=status,number_of_nodes')"; else ko "OpenSearch ne répond pas"; fi
  else info "OpenSearch non démarré (profil optionnel : ./labo.sh demarrer opensearch)"; fi
}

cmd_importer() {
  local service="elasticsearch"
  [[ "${1:-}" == "opensearch" ]] && service="opensearch"
  titre "Import dans ${service}"
  for index in cours avis acces; do
    local code
    code=$(compose exec -T "$service" curl -s -o /dev/null -w '%{http_code}' -X PUT "http://localhost:9200/${index}" \
      -H 'Content-Type: application/json' --data-binary "@/labo/mappings/${index}.json")
    case "$code" in
      200) ok "index ${index} créé avec son mapping" ;;
      400) info "index ${index} existe déjà — conservé" ;;
      *)   ko "création de l'index ${index} : HTTP ${code}"; exit 1 ;;
    esac
    local erreurs
    erreurs=$(requete "$service" POST "/_bulk?filter_path=errors,items.*.error" "/labo/donnees/${index}.ndjson" application/x-ndjson)
    if [[ "$erreurs" == '{"errors":false}' ]]; then ok "données ${index} chargées"; else ko "erreurs pendant le bulk ${index} : ${erreurs:0:300}"; exit 1; fi
  done
  requete "$service" POST "/cours,avis,acces/_refresh" >/dev/null
  echo
  requete "$service" GET '/_cat/indices/cours,avis,acces?v&h=index,docs.count,store.size&s=index'
  echo
  echo "${VERT}Import terminé.${FIN} Attendu : cours = 504, avis = 609, acces = 12000."
}

cmd_charger_graphe() {
  titre "Chargement du graphe Neo4j"
  compose exec -T neo4j cypher-shell -u neo4j -p "$NEO4J_MDP" -f /labo/cypher/01-contraintes.cypher >/dev/null
  ok "contraintes et index en place"
  compose exec -T neo4j cypher-shell -u neo4j -p "$NEO4J_MDP" --format plain -f /labo/cypher/02-charger.cypher
  echo
  echo "${VERT}Graphe chargé.${FIN} Attendu : Competence 22, Cours 504, Etudiant 300, Professeur 30, Ville 16."
  echo "Ouvrez Neo4j Browser : http://localhost:7474 (neo4j / ${NEO4J_MDP})"
}

cmd_cypher() {
  local fichier="${1:?usage : ./labo.sh cypher <fichier.cypher> (dans neo4j/cypher)}"
  compose exec -T neo4j cypher-shell -u neo4j -p "$NEO4J_MDP" --format verbose -f "/labo/cypher/${fichier##*/}"
}

cmd_journal() {
  local service="${1:?usage : ./labo.sh journal <elasticsearch|kibana|neo4j|opensearch|opensearch-dashboards>}"
  compose --profile opensearch logs --tail 100 "$service"
}

cmd_arreter() { compose --profile opensearch stop; ok "conteneurs arrêtés — vos données sont conservées ; ./labo.sh demarrer pour reprendre"; }

cmd_reinitialiser() {
  echo "${JAUNE}Ceci supprime les conteneurs ET toutes les données du labo (index, graphe, tableaux de bord).${FIN}"
  read -r -p "Continuer ? (oui/non) " reponse
  [[ "$reponse" == "oui" ]] || { echo "Annulé."; exit 0; }
  compose --profile opensearch down -v --remove-orphans
  ok "labo remis à zéro — ./labo.sh demarrer pour repartir"
}

case "${1:-}" in
  prerequis) cmd_prerequis ;;
  demarrer) cmd_demarrer "${2:-}" ;;
  etat) cmd_etat ;;
  importer) cmd_importer "${2:-}" ;;
  charger-graphe) cmd_charger_graphe ;;
  cypher) cmd_cypher "${2:-}" ;;
  journal) cmd_journal "${2:-}" ;;
  arreter) cmd_arreter ;;
  reinitialiser) cmd_reinitialiser ;;
  *) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
