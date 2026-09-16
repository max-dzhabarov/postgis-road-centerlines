CREATE EXTENSION IF NOT EXISTS postgis;

-- Optional but recommended for medial-axis calculation:
-- CREATE EXTENSION IF NOT EXISTS postgis_sfcgal;

DROP SCHEMA IF EXISTS demo_centerlines CASCADE;
CREATE SCHEMA demo_centerlines;

CREATE TABLE demo_centerlines.road_polygons (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text,
    geom geometry(Geometry, 3857) NOT NULL
);

CREATE INDEX road_polygons_geom_gix
    ON demo_centerlines.road_polygons USING gist (geom);

CREATE OR REPLACE FUNCTION demo_centerlines.safe_road_centerline(
    input_geom geometry,
    grid_size double precision DEFAULT 0.01,
    buffer_fallback double precision DEFAULT 0.20,
    simplify_tolerance double precision DEFAULT 1.50
)
RETURNS TABLE(centerline geometry, method text)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    cleaned geometry;
    candidate geometry;
    medial_function text;
BEGIN
    IF input_geom IS NULL OR ST_IsEmpty(input_geom) THEN
        RETURN;
    END IF;

    cleaned := ST_UnaryUnion(
        ST_CollectionExtract(
            ST_MakeValid(
                ST_SnapToGrid(ST_Force2D(input_geom), grid_size)
            ),
            3
        )
    );

    IF cleaned IS NULL OR ST_IsEmpty(cleaned) THEN
        RETURN;
    END IF;

    IF to_regprocedure('cg_approximatemedialaxis(geometry)') IS NOT NULL THEN
        medial_function := 'cg_approximatemedialaxis';
    ELSIF to_regprocedure('st_approximatemedialaxis(geometry)') IS NOT NULL THEN
        medial_function := 'st_approximatemedialaxis';
    END IF;

    IF medial_function IS NOT NULL THEN
        BEGIN
            EXECUTE format('SELECT %s($1)', medial_function)
                INTO candidate
                USING cleaned;
            method := 'medial_axis';
        EXCEPTION WHEN OTHERS THEN
            candidate := NULL;
        END;

        IF candidate IS NULL OR ST_IsEmpty(candidate) THEN
            BEGIN
                EXECUTE format('SELECT %s(ST_Buffer($1, $2))', medial_function)
                    INTO candidate
                    USING cleaned, buffer_fallback;
                method := 'buffered_medial_axis';
            EXCEPTION WHEN OTHERS THEN
                candidate := NULL;
            END;
        END IF;
    END IF;

    IF candidate IS NULL OR ST_IsEmpty(candidate) THEN
        candidate := ST_LongestLine(cleaned, cleaned);
        method := 'longest_line_fallback';
    END IF;

    candidate := ST_LineMerge(
        ST_CollectionExtract(ST_MakeValid(candidate), 2)
    );

    IF candidate IS NULL OR ST_IsEmpty(candidate) THEN
        RETURN;
    END IF;

    centerline := ST_SimplifyPreserveTopology(
        ST_SetSRID(candidate, ST_SRID(input_geom)),
        simplify_tolerance
    );
    RETURN NEXT;
END;
$$;
