-- Migration: Enable PostGIS and add spatial geometry to in_kind_donations

-- 1. Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Add geometry column (Point, WGS84 SRID 4326)
ALTER TABLE public.in_kind_donations
ADD COLUMN IF NOT EXISTS geom GEOMETRY(Point, 4326);

-- 3. Backfill geometry from existing latitude/longitude
UPDATE public.in_kind_donations
SET geom = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- 4. Create Spatial Index (GIST) for high-performance distance queries
CREATE INDEX IF NOT EXISTS idx_in_kind_donations_geom ON public.in_kind_donations USING GIST(geom);
