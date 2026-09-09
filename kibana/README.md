# Objets Kibana du labo

`tableau-de-bord-trafic.ndjson` contient le tableau de bord « Labo — Trafic du site » et ses 7 dépendances (vue de données `acces*`, 5 visualisations Lens, recherche enregistrée « Erreurs serveur »), exportés depuis Kibana 9.5.3 avec `POST /api/saved_objects/_export` (`{"type":["dashboard"],"includeReferencesDeep":true}`).

Import par l'interface : menu ☰ → « Gestion de la Suite » → « Objets enregistrés » → bouton « Importer » → volet « Importer les objets enregistrés » → « Sélectionner un fichier à importer » → option « Rechercher les objets existants » + « Écraser automatiquement les conflits » → « Importer ».

Import par l'API (idempotent, écrase les objets de même id) : `curl -X POST "http://localhost:5601/api/saved_objects/_import?overwrite=true" -H "kbn-xsrf: true" --form file=@kibana/tableau-de-bord-trafic.ndjson` → attendu `"success":true,"successCount":8`.
