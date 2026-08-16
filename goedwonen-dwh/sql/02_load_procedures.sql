-- =====================================================================
-- Load-procedures: full truncate-and-load vanuit staging (stg schema)
-- Aan te roepen vanuit ADF Stored Procedure Activities
-- =====================================================================

CREATE OR ALTER PROCEDURE dbo.usp_Load_DimLocatie
AS
BEGIN
    TRUNCATE TABLE dbo.DimLocatie;
    INSERT INTO dbo.DimLocatie (Postcode4, Woonplaats)
    SELECT DISTINCT LEFT(POSTCODE, 4), WOONPLAATS
    FROM stg.ADRES
    WHERE POSTCODE IS NOT NULL;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_Load_DimObject
AS
BEGIN
    TRUNCATE TABLE dbo.DimObject;
    INSERT INTO dbo.DimObject
        (BOT_ID, Naam, ObjectType, Daeb_YN, Etage, Gang, Subcomplex, ComplexStatus, Straatnaam, Huisnummer, LocatieKey)
    SELECT
        o.BOT_ID, o.NAAM, o.OBJECT_TYPE, o.DAEB_YN,
        c.ETAGE, c.GANG, c.SUBCOMPLEX, c.COMPLEX_STATUS,
        a.STRAATNAAM, a.HUISNUMMER,
        l.LocatieKey
    FROM stg.OBJECTEN o
    LEFT JOIN stg.COMPLEX c ON c.BOT_ID = o.BOT_ID
    LEFT JOIN stg.ADRES a ON a.ADRES_ID = o.ADRES_ID
    LEFT JOIN dbo.DimLocatie l ON l.Postcode4 = LEFT(a.POSTCODE, 4) AND l.Woonplaats = a.WOONPLAATS;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_Load_DimWerksoort
AS
BEGIN
    TRUNCATE TABLE dbo.DimWerksoort;
    INSERT INTO dbo.DimWerksoort (SOORT_ID, Code, Omschrijving)
    SELECT SOORT_ID, CODE, OMSCHRIJVING FROM stg.WERKSOORT;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_Load_DimProject
AS
BEGIN
    TRUNCATE TABLE dbo.DimProject;
    INSERT INTO dbo.DimProject (PROJECT_ID, Omschrijving, Startdatum, Einddatum, BegroteBedragBTW)
    SELECT PROJECT_ID, OMSCHRIJVING, TRY_CAST(STARTDATUM AS DATE), TRY_CAST(EINDDATUM AS DATE), BEGROTEBEDRAGBTW
    FROM stg.PROJECT;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_Load_DimMelding
AS
BEGIN
    TRUNCATE TABLE dbo.DimMelding;
    INSERT INTO dbo.DimMelding (WERKVERZOEK_ID, Omschrijving, BonJaar, BonNmmr)
    SELECT WERKVERZOEK_ID, OMSCHRIJVING, BONJAAR, BONNMMR FROM stg.WERKVERZOEK;
END
GO

-- DimWeer: koppelt de opgehaalde weerdata (stg.WEER) aan Locatie + Datum
CREATE OR ALTER PROCEDURE dbo.usp_Load_DimWeer
AS
BEGIN
    TRUNCATE TABLE dbo.DimWeer;
    INSERT INTO dbo.DimWeer
        (LocatieKey, DatumKey, GemTemperatuurC, MinTemperatuurC, MaxTemperatuurC,
         NeerslagMM, WindkrachtBft, MaxWindstootKmh, VorstYN, StormYN, Weertype)
    SELECT
        l.LocatieKey,
        d.DatumKey,
        w.GEM_TEMPERATUUR_C, w.MIN_TEMPERATUUR_C, w.MAX_TEMPERATUUR_C,
        w.NEERSLAG_MM, w.WINDKRACHT_BFT, w.MAX_WINDSTOOT_KMH,
        CASE WHEN w.MIN_TEMPERATUUR_C < 0 THEN 1 ELSE 0 END,
        CASE WHEN w.WINDKRACHT_BFT >= 9 THEN 1 ELSE 0 END,
        w.WEERTYPE
    FROM stg.WEER w
    JOIN dbo.DimLocatie l ON l.Postcode4 = w.POSTCODE4
    JOIN dbo.DimDatum d ON d.Datum = TRY_CAST(w.DATUM AS DATE);
END
GO

-- FactWerk: 1 rij per werkopdracht, met surrogate-key lookups en afgeleide meetwaarden
CREATE OR ALTER PROCEDURE dbo.usp_Load_FactWerk
AS
BEGIN
    TRUNCATE TABLE dbo.FactWerk;

    INSERT INTO dbo.FactWerk
        (OPDRACHT_ID, MeldingKey, ObjectKey, WerksoortKey, ProjectKey,
         MelddatumKey, OpdrachtdatumKey, StartdatumKey, EinddatumKey,
         WeerOpMeldingKey, AantalMeldingen, DoorlooptijdDagen, IsAfgerond, BegroteKosten)
    SELECT
        wo.OPDRACHT_ID,
        m.MeldingKey,
        obj.ObjectKey,
        ws.WerksoortKey,
        pr.ProjectKey,
        dMeld.DatumKey,
        dOpdr.DatumKey,
        dStart.DatumKey,
        dEind.DatumKey,
        weer.WeerKey,
        1,
        DATEDIFF(DAY, TRY_CAST(wv.MELDDATUM AS DATE), TRY_CAST(wo.EINDDATUM AS DATE)),
        CASE WHEN wo.AFGEROND = 'J' THEN 1 ELSE 0 END,
        prg.BEGROTEBEDRAG
    FROM stg.WERKOPDRACHT wo
    JOIN stg.WERKVERZOEK wv   ON wv.WERKVERZOEK_ID = wo.WERKVERZOEK_ID
    JOIN dbo.DimMelding m     ON m.WERKVERZOEK_ID = wv.WERKVERZOEK_ID
    JOIN dbo.DimObject obj    ON obj.BOT_ID = wv.BOT_ID
    JOIN dbo.DimWerksoort ws  ON ws.SOORT_ID = wo.SOORT_ID
    LEFT JOIN dbo.DimProject pr ON pr.PROJECT_ID = wv.PROJECT_ID
    LEFT JOIN stg.PROJECTREGEL prg ON prg.BOT_ID = wv.BOT_ID AND prg.PROJECT_ID = wv.PROJECT_ID
    LEFT JOIN dbo.DimDatum dMeld  ON dMeld.Datum  = TRY_CAST(wv.MELDDATUM AS DATE)
    LEFT JOIN dbo.DimDatum dOpdr  ON dOpdr.Datum  = TRY_CAST(wo.OPDRACHTDATUM AS DATE)
    LEFT JOIN dbo.DimDatum dStart ON dStart.Datum = TRY_CAST(wo.STARTDATUM AS DATE)
    LEFT JOIN dbo.DimDatum dEind  ON dEind.Datum  = TRY_CAST(wo.EINDDATUM AS DATE)
    LEFT JOIN dbo.DimObject dobj  ON dobj.ObjectKey = obj.ObjectKey
    LEFT JOIN dbo.DimWeer weer    ON weer.LocatieKey = obj.LocatieKey AND weer.DatumKey = dMeld.DatumKey;
END
GO
