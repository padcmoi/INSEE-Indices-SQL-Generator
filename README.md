# INSEE Indices SQL Generator

Ce projet permet de générer automatiquement des fichiers SQL contenant les indices officiels de l'INSEE :

- IRL : Indice de Référence des Loyers
- ILC : Indice des Loyers Commerciaux
- ILAT : Indice des Loyers des Activités Tertiaires

Les données sont extraites directement depuis l'API SDMX de l'INSEE, au format XML (SDMX 2.1).

---

## Prérequis debian/ubuntu

Avant toute utilisation, installer les packages nécessaires :

```bash
sudo apt update
sudo apt install -y curl libxml2-utils
```

## Prérequis base de données (exemple PostgreSQL)

```sql
CREATE TABLE ref_indice_loyer (
   indice_loyer_Id SERIAL PRIMARY KEY,
   indice_revision VARCHAR(64) NOT NULL,
   annee SMALLINT NOT NULL,
   trimestre SMALLINT NOT NULL CHECK(trimestre BETWEEN 1 AND 4),
   valeur NUMERIC(10,3) NOT NULL,
   variation_annee NUMERIC(6,2),
   published_at DATE,
   UNIQUE(indice_revision, annee, trimestre)
);
```

## Structure

```
ROOT/
├── fetch.sh
├── get_insee_indices.sh
├── export/
│ ├── insert_irl.sql
│ ├── insert_ilc.sql
│ └── insert_ilat.sql
├── README.md
└── LICENSE

```

## Auteur

Julien JEAN
Licence MIT
