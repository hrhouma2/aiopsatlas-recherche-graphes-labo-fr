<#
Labo « Recherche & graphes » — point d'entrée unique pour Windows (PowerShell 5.1 ou 7).

  .\labo.ps1 prerequis               vérifie Docker, la mémoire, les ports
  .\labo.ps1 demarrer [opensearch]   démarre la stack et attend qu'elle soit prête
  .\labo.ps1 etat                    état des conteneurs et des services
  .\labo.ps1 importer [opensearch]   crée les index cours/avis/acces et charge les données
  .\labo.ps1 charger-graphe          charge le graphe Neo4j depuis les CSV
  .\labo.ps1 cypher <fichier>        exécute un script Cypher du dossier neo4j/cypher
  .\labo.ps1 journal <service>       100 dernières lignes de journal d'un service
  .\labo.ps1 arreter                 arrête les conteneurs (les données restent)
  .\labo.ps1 reinitialiser           supprime conteneurs ET données (repart de zéro)

Si PowerShell refuse d'exécuter le script :
  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
#>
param(
  [Parameter(Position = 0)] [string] $Commande = '',
  [Parameter(Position = 1)] [string] $Argument = ''
)

$ErrorActionPreference = 'Continue'
Set-Location $PSScriptRoot
$NEO4J_MDP = 'aiopsatlas2026'

function Ok($m)    { Write-Host "  ✔ $m" -ForegroundColor Green }
function Ko($m)    { Write-Host "  ✘ $m" -ForegroundColor Red }
function Info($m)  { Write-Host "— $m" -ForegroundColor DarkGray }
function Titre($m) { Write-Host ""; Write-Host "== $m ==" }

# Exécute curl à l'intérieur d'un conteneur (elasticsearch ou opensearch).
function Requete($service, $methode, $chemin, $fichier = '', $type = 'application/json') {
  if ($fichier) {
    docker compose exec -T $service curl -sS -X $methode "http://localhost:9200$chemin" -H "Content-Type: $type" --data-binary "@$fichier"
  } else {
    docker compose exec -T $service curl -sS -X $methode "http://localhost:9200$chemin"
  }
}

function Prerequis {
  Titre 'Prérequis'
  $erreurs = 0
  if (Get-Command docker -ErrorAction SilentlyContinue) { Ok "docker : $(docker --version)" } else { Ko 'docker introuvable — installez Docker Desktop'; $erreurs++ }
  docker info *> $null
  if ($LASTEXITCODE -eq 0) { Ok 'le démon Docker répond' } else { Ko "le démon Docker ne répond pas — lancez Docker Desktop et attendez l'icône verte"; $erreurs++ }
  docker compose version *> $null
  if ($LASTEXITCODE -eq 0) { Ok "docker compose : $(docker compose version --short)" } else { Ko 'docker compose (v2) introuvable'; $erreurs++ }

  if ($erreurs -eq 0) {
    $memGo = [math]::Floor([double](docker info --format '{{.MemTotal}}') / 1GB)
    if ($memGo -ge 6) { Ok "mémoire disponible pour Docker : $memGo Go" }
    elseif ($memGo -ge 4) { Write-Host "  ! mémoire pour Docker : $memGo Go — suffisant sans OpenSearch ; 6 Go conseillés pour le profil opensearch" -ForegroundColor Yellow }
    else { Ko "mémoire pour Docker : $memGo Go — il en faut au moins 4 (fichier %UserProfile%\.wslconfig : [wsl2] memory=6GB, puis wsl --shutdown)"; $erreurs++ }
    $cpus = [int](docker info --format '{{.NCPU}}')
    if ($cpus -ge 2) { Ok "processeurs : $cpus" } else { Ko "processeurs : $cpus — 2 minimum"; $erreurs++ }
  }

  $laboTourne = (docker ps --format '{{.Names}}' 2>$null) -match '^labo-'
  foreach ($port in 9200, 5601, 7474, 7687) {
    $occupe = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($occupe) {
      if ($laboTourne) { Ok "port $port : utilisé par le labo lui-même" } else { Ko "port $port déjà occupé par un autre programme — arrêtez-le ou changez le port dans docker-compose.yml"; $erreurs++ }
    } else { Ok "port $port libre" }
  }

  Write-Host ''
  if ($erreurs -eq 0) { Write-Host 'Tout est prêt. Lancez : .\labo.ps1 demarrer' -ForegroundColor Green }
  else { Write-Host 'Corrigez les points marqués ✘ puis relancez .\labo.ps1 prerequis' -ForegroundColor Red; exit 1 }
}

# Attend qu'un conteneur soit « healthy » (ou « running » s'il n'a pas de healthcheck).
function AttendreSante($service, $max = 240) {
  Write-Host ("  {0,-24}" -f $service) -NoNewline
  $ecoule = 0
  while ($ecoule -lt $max) {
    $etat = docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "labo-$service" 2>$null
    if (-not $etat) { $etat = 'absent' }
    switch ($etat) {
      'healthy'   { Write-Host " prêt ($ecoule s)" -ForegroundColor Green; return $true }
      'running'   { Write-Host " démarré ($ecoule s)" -ForegroundColor Green; return $true }
      { $_ -in 'unhealthy', 'exited', 'dead' } { Write-Host " $etat" -ForegroundColor Red; return $false }
    }
    Start-Sleep 3; $ecoule += 3; Write-Host '.' -NoNewline
  }
  Write-Host ' délai dépassé' -ForegroundColor Red; return $false
}

function Demarrer($profil) {
  $args = @(); if ($profil -eq 'opensearch') { $args = @('--profile', 'opensearch') }
  Titre 'Téléchargement des images (long la première fois : ~6 Go, ~12 Go avec OpenSearch)'
  docker compose @args pull --quiet
  Titre 'Démarrage'
  docker compose @args up -d
  Titre 'Attente que chaque service soit prêt'
  $okTous = (AttendreSante elasticsearch) -and (AttendreSante kibana) -and (AttendreSante neo4j)
  if ($profil -eq 'opensearch') { $okTous = (AttendreSante opensearch) -and (AttendreSante opensearch-dashboards 120) -and $okTous }
  Write-Host ''
  if ($okTous) {
    Write-Host 'Le labo est prêt.' -ForegroundColor Green
    Write-Host '  Kibana                 http://localhost:5601   (Dev Tools : menu ☰ → Management → Dev Tools)'
    Write-Host '  Elasticsearch          http://localhost:9200'
    Write-Host "  Neo4j Browser          http://localhost:7474   (utilisateur neo4j · mot de passe $NEO4J_MDP)"
    if ($profil -eq 'opensearch') {
      Write-Host '  OpenSearch Dashboards  http://localhost:5602'
      Write-Host '  OpenSearch             http://localhost:9201'
    }
    Write-Host ''
    Write-Host 'Étape suivante : .\labo.ps1 importer   puis   .\labo.ps1 charger-graphe'
  } else {
    Write-Host "Un service n'a pas démarré. Regardez son journal : .\labo.ps1 journal <service>" -ForegroundColor Red
    Write-Host 'Les causes classiques et leurs remèdes sont dans la leçon « Lire l''état et réparer en 5 minutes ».'
    exit 1
  }
}

function Etat {
  Titre 'Conteneurs'
  docker compose --profile opensearch ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}'
  Titre 'Services'
  $sante = Requete elasticsearch GET '/_cluster/health?filter_path=status,number_of_nodes' 2>$null
  if ($LASTEXITCODE -eq 0 -and $sante) {
    Ok "Elasticsearch : $sante"
    $index = (Requete elasticsearch GET '/_cat/indices/cours,avis,acces?h=index,docs.count&s=index' 2>$null) -join ' '
    Write-Host "     index : $(if ($index) { $index } else { 'aucun index du labo' })"
  } else { Ko 'Elasticsearch ne répond pas' }
  docker compose exec -T kibana curl -fsS http://localhost:5601/api/status *> $null
  if ($LASTEXITCODE -eq 0) { Ok 'Kibana répond (http://localhost:5601)' } else { Ko 'Kibana ne répond pas encore' }
  $noeuds = docker compose exec -T neo4j cypher-shell -u neo4j -p $NEO4J_MDP --format plain 'MATCH (n) RETURN count(n)' 2>$null
  if ($LASTEXITCODE -eq 0) { Ok "Neo4j répond — nœuds : $($noeuds | Select-Object -Last 1)" } else { Ko 'Neo4j ne répond pas' }
  if ((docker ps --format '{{.Names}}') -contains 'labo-opensearch') {
    $os = Requete opensearch GET '/_cluster/health?filter_path=status,number_of_nodes' 2>$null
    if ($LASTEXITCODE -eq 0) { Ok "OpenSearch : $os" } else { Ko 'OpenSearch ne répond pas' }
  } else { Info 'OpenSearch non démarré (profil optionnel : .\labo.ps1 demarrer opensearch)' }
}

function Importer($cible) {
  $service = if ($cible -eq 'opensearch') { 'opensearch' } else { 'elasticsearch' }
  Titre "Import dans $service"
  foreach ($index in 'cours', 'avis', 'acces') {
    $code = docker compose exec -T $service curl -s -o /dev/null -w '%{http_code}' -X PUT "http://localhost:9200/$index" -H 'Content-Type: application/json' --data-binary "@/labo/mappings/$index.json"
    switch ($code) {
      '200' { Ok "index $index créé avec son mapping" }
      '400' { Info "index $index existe déjà — conservé" }
      default { Ko "création de l'index $index : HTTP $code"; exit 1 }
    }
    $erreurs = Requete $service POST '/_bulk?filter_path=errors,items.*.error' "/labo/donnees/$index.ndjson" 'application/x-ndjson'
    if ($erreurs -eq '{"errors":false}') { Ok "données $index chargées" } else { Ko "erreurs pendant le bulk $index : $($erreurs.Substring(0, [math]::Min(300, $erreurs.Length)))"; exit 1 }
  }
  Requete $service POST '/cours,avis,acces/_refresh' *> $null
  Write-Host ''
  Requete $service GET '/_cat/indices/cours,avis,acces?v&h=index,docs.count,store.size&s=index'
  Write-Host ''
  Write-Host 'Import terminé. Attendu : cours = 504, avis = 609, acces = 12000.' -ForegroundColor Green
}

function ChargerGraphe {
  Titre 'Chargement du graphe Neo4j'
  docker compose exec -T neo4j cypher-shell -u neo4j -p $NEO4J_MDP -f /labo/cypher/01-contraintes.cypher *> $null
  Ok 'contraintes et index en place'
  docker compose exec -T neo4j cypher-shell -u neo4j -p $NEO4J_MDP --format plain -f /labo/cypher/02-charger.cypher
  Write-Host ''
  Write-Host 'Graphe chargé. Attendu : Competence 22, Cours 504, Etudiant 300, Professeur 30, Ville 16.' -ForegroundColor Green
  Write-Host "Ouvrez Neo4j Browser : http://localhost:7474 (neo4j / $NEO4J_MDP)"
}

function Cypher($fichier) {
  if (-not $fichier) { throw 'usage : .\labo.ps1 cypher <fichier.cypher> (dans neo4j/cypher)' }
  docker compose exec -T neo4j cypher-shell -u neo4j -p $NEO4J_MDP --format verbose -f "/labo/cypher/$(Split-Path $fichier -Leaf)"
}

function Journal($service) {
  if (-not $service) { throw 'usage : .\labo.ps1 journal <elasticsearch|kibana|neo4j|opensearch|opensearch-dashboards>' }
  docker compose --profile opensearch logs --tail 100 $service
}

function Arreter { docker compose --profile opensearch stop; Ok 'conteneurs arrêtés — vos données sont conservées ; .\labo.ps1 demarrer pour reprendre' }

function Reinitialiser {
  Write-Host 'Ceci supprime les conteneurs ET toutes les données du labo (index, graphe, tableaux de bord).' -ForegroundColor Yellow
  $reponse = Read-Host 'Continuer ? (oui/non)'
  if ($reponse -ne 'oui') { Write-Host 'Annulé.'; return }
  docker compose --profile opensearch down -v --remove-orphans
  Ok 'labo remis à zéro — .\labo.ps1 demarrer pour repartir'
}

switch ($Commande) {
  'prerequis'      { Prerequis }
  'demarrer'       { Demarrer $Argument }
  'etat'           { Etat }
  'importer'       { Importer $Argument }
  'charger-graphe' { ChargerGraphe }
  'cypher'         { Cypher $Argument }
  'journal'        { Journal $Argument }
  'arreter'        { Arreter }
  'reinitialiser'  { Reinitialiser }
  default          { Get-Content $PSCommandPath | Select-Object -Skip 1 -First 14; exit 1 }
}
