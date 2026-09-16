TRUNCATE TABLE demo_centerlines.road_polygons RESTART IDENTITY;

INSERT INTO demo_centerlines.road_polygons (name, geom)
VALUES
    (
        'Прямой участок',
        ST_GeomFromText('POLYGON((0 0, 120 0, 120 18, 0 18, 0 0))', 3857)
    ),
    (
        'Поворот',
        ST_GeomFromText(
            'POLYGON((0 40, 100 40, 100 100, 82 100, 82 58, 0 58, 0 40))',
            3857
        )
    ),
    (
        'Невалидный тестовый полигон',
        ST_GeomFromText('POLYGON((140 0, 210 50, 140 50, 210 0, 140 0))', 3857)
    );

CREATE OR REPLACE VIEW demo_centerlines.v_road_centerlines AS
SELECT
    r.id AS road_id,
    r.name,
    c.method,
    c.centerline
FROM demo_centerlines.road_polygons AS r
CROSS JOIN LATERAL demo_centerlines.safe_road_centerline(r.geom) AS c
WHERE NULLIF(btrim(r.name), '') IS NOT NULL;
