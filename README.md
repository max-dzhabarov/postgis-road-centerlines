# Безопасное построение осевых линий дорог в PostGIS

Демонстрационная SQL-реализация построения осевых линий из дорожных полигонов. Основная задача — получить устойчивый результат даже при самопересечениях, составных геометриях и сбоях алгоритма скелетизации.

## Алгоритм

1. Геометрия переводится в 2D и привязывается к координатной сетке.
2. `ST_MakeValid` исправляет невалидный вход, а полигональные компоненты объединяются.
3. Для PostGIS 3.5+ используется `CG_ApproximateMedialAxis`; для более ранних версий — `ST_ApproximateMedialAxis`.
4. При ошибке выполняется повторный расчёт после небольшого буфера.
5. Если скелетизация недоступна или снова завершилась ошибкой, применяется резервная ось `ST_LongestLine`.
6. Результат очищается, объединяется и упрощается для картографического подписывания.

Функции построения медиальной оси требуют расширение `postgis_sfcgal`. Резервный сценарий работает только на PostGIS, но является геометрической эвристикой, а не полноценным скелетом.

## Запуск

```bash
psql -d your_database -f sql/01_setup.sql
psql -d your_database -f sql/02_demo.sql
```

```sql
SELECT road_id, name, method, ST_AsText(centerline)
FROM demo_centerlines.v_road_centerlines;
```

Параметры функции по умолчанию: сетка `0.01`, резервный буфер `0.20`, допуск упрощения `1.50`. Их необходимо подбирать в единицах системы координат набора данных.

Все геометрии в репозитории синтетические; производственный код и данные не публикуются.

---

# Safe road-centerline generation in PostGIS

A reproducible SQL example for deriving labeling centerlines from road polygons. The wrapper repairs invalid input, tries the available medial-axis function, retries after buffering, and falls back to the longest chord when skeletonization is unavailable or fails.

The medial-axis functions require `postgis_sfcgal`. The fallback needs only PostGIS, but it is a geometric heuristic rather than a true polygon skeleton. Run both SQL files in numerical order and tune the grid, buffer, and simplification tolerances to the coordinate units of your dataset.

## License

MIT
