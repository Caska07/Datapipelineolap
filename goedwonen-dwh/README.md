# GoedWonen Zuid – OLAP schema & ADF pipeline

Onderdeel van de herkansing DIS: OLAP-schema en ADF-pipeline voor betere
rapportages over onderhoudsmeldingen in relatie tot weer.

## Inhoud

- `sql/01_create_olap_schema.sql` – DDL voor het sterretjesmodel (DimDatum,
  DimLocatie, DimObject, DimWerksoort, DimProject, DimMelding, DimWeer, FactWerk)
- `sql/02_load_procedures.sql` – stored procedures die de dimensies en
  FactWerk vullen vanuit staging (`stg.*`), truncate-and-load
- `adf/pipeline/` – pipeline-definities (JSON), zoals ADF ze wegschrijft
  wanneer je de Data Factory aan Git koppelt
  - `PL_Master_Load_DWH.json` – orkestreert de vier sub-pipelines
  - `PL_Load_Staging.json` – kopieert de OLTP-tabellen naar staging
  - `PL_Load_Weer.json` – haalt weerdata per locatie op via een REST API
  - `PL_Load_Dimensions.json` – vult alle dimensietabellen
  - `PL_Load_Fact.json` – vult FactWerk
- `adf/linkedService/LS_AzureSqlDWH.json` – placeholder linked service,
  vul je eigen server/database/IR-naam in

## Nog aan te vullen voor het werkt

1. `stg.*` staging-tabellen aanmaken (zelfde structuur als de OLTP-bron plus
   `stg.WEER` met kolommen POSTCODE4, DATUM, GEM_TEMPERATUUR_C, MIN_TEMPERATUUR_C,
   MAX_TEMPERATUUR_C, NEERSLAG_MM, WINDKRACHT_BFT, MAX_WINDSTOOT_KMH, WEERTYPE)
2. `DimDatum` eenmalig vullen (script of los aanmaken, geen bron-tabel voor)
2. Linked services voor de OLTP-bron en de weer-REST-API toevoegen
3. Datasets `DS_OLTP_*`, `DS_Staging_*` en `DS_Weer_REST` aanmaken en aan de
   juiste linked services + tabellen/endpoints koppelen
4. Connectiegegevens invullen in `LS_AzureSqlDWH.json`

## Naar je eigen repo pushen

```bash
git clone https://github.com/Caska07/<jouw-repo>.git
cp -r goedwonen-dwh/* <jouw-repo>/
cd <jouw-repo>
git add .
git commit -m "OLAP schema en ADF pipeline voor onderhoud/weer rapportage"
git push
```
