-- =============================================================================
-- Voxel Truck — Esquema de base de datos
-- PostgreSQL 13+
--
-- CÓMO EJECUTAR EN DBEAVER (consola SQL):
--   1. Pegar TODO este archivo en el editor SQL
--   2. Alt+X  →  "Execute SQL Script"  (ejecuta todo el script)
--      NO uses Ctrl+Enter solo: eso ejecuta UNA línea/comando y falla a medias
--   3. Después correr database/vt_verify.sql con Alt+X para confirmar
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Tabla: vt_camiones
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS vt_camiones (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  numero_viaje         TEXT NOT NULL,
  origen               TEXT NOT NULL,
  destino              TEXT NOT NULL,
  observaciones        TEXT NULL,

  estado               TEXT NOT NULL DEFAULT 'abierto'
                       CONSTRAINT vt_camiones_estado_check
                       CHECK (estado IN ('abierto', 'pendiente', 'cerrado', 'enviado')),

  porcentaje_ocupacion NUMERIC(5, 2) NULL,
  tipo_vehiculo        TEXT NULL,

  cerrado_en           TIMESTAMPTZ NULL,
  enviado_en           TIMESTAMPTZ NULL,

  alerta_email_enviada BOOLEAN NOT NULL DEFAULT FALSE,

  -- Si TRUE, la alerta por falta de optimización ya fue enviada al menos una vez
  -- (no se resetea al reabrir; permite cerrar/enviar sin bloquear de nuevo).

  cantidad_hu          INT NOT NULL DEFAULT 0,
  peso_total_kg        NUMERIC(12, 3) NOT NULL DEFAULT 0,
  volumen_total_m3     NUMERIC(12, 6) NOT NULL DEFAULT 0,

  creado_por           TEXT NULL,
  id_dispositivo       TEXT NULL,

  creado_en            TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT vt_camiones_porcentaje_rango
    CHECK (porcentaje_ocupacion IS NULL OR (porcentaje_ocupacion >= 0 AND porcentaje_ocupacion <= 150)),

  CONSTRAINT vt_camiones_totales_no_negativos
    CHECK (cantidad_hu >= 0 AND peso_total_kg >= 0 AND volumen_total_m3 >= 0),

  CONSTRAINT vt_camiones_enviado_requiere_fecha
    CHECK (estado <> 'enviado' OR enviado_en IS NOT NULL),

  CONSTRAINT vt_camiones_cerrado_requiere_fecha
    CHECK (estado IN ('abierto') OR cerrado_en IS NOT NULL)
);

COMMENT ON TABLE vt_camiones IS 'Viajes / camiones de consolidación Voxel Truck';
COMMENT ON COLUMN vt_camiones.origen IS 'Centro logístico de origen';
COMMENT ON COLUMN vt_camiones.cantidad_hu IS 'Total de escaneos (HUs) cacheado';

-- ---------------------------------------------------------------------------
-- Tabla: vt_bultos_camion
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS vt_bultos_camion (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  id_camion           UUID NOT NULL REFERENCES vt_camiones (id) ON DELETE RESTRICT,

  codigo_hu           TEXT NOT NULL,

  fuente_dimensiones  TEXT NOT NULL
                      CONSTRAINT vt_bultos_fuente_check
                      CHECK (fuente_dimensiones IN ('voxel_cam', 'coresa')),

  cantidad_bultos     INT NOT NULL DEFAULT 1
                      CONSTRAINT vt_bultos_cantidad_positiva CHECK (cantidad_bultos >= 1),

  es_lote             BOOLEAN GENERATED ALWAYS AS (cantidad_bultos > 1) STORED,

  largo_cm            NUMERIC NULL,
  ancho_cm            NUMERIC NULL,
  alto_cm             NUMERIC NULL,

  peso_kg             NUMERIC NOT NULL CONSTRAINT vt_bultos_peso_positivo CHECK (peso_kg >= 0),
  volumen_m3          NUMERIC NOT NULL CONSTRAINT vt_bultos_volumen_positivo CHECK (volumen_m3 >= 0),

  id_registro_origen  TEXT NOT NULL,

  -- Copia del estado del camión (historial)
  estado_camion       TEXT NOT NULL
                      CONSTRAINT vt_bultos_estado_camion_check
                      CHECK (estado_camion IN ('abierto', 'pendiente', 'cerrado', 'enviado')),

  agregado_en         TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT vt_bultos_dimensiones_solo_bulto_unico
    CHECK (
      cantidad_bultos = 1
      OR (largo_cm IS NULL AND ancho_cm IS NULL AND alto_cm IS NULL)
    )
);

COMMENT ON TABLE vt_bultos_camion IS 'HUs escaneados y asignados a un camión';
COMMENT ON COLUMN vt_bultos_camion.estado_camion IS 'Copia de vt_camiones.estado al cambiar; historial, no desbloquea el HU';
COMMENT ON COLUMN vt_bultos_camion.id_registro_origen IS
  'ID del escaneo en la tabla origen: escaneos.id (ej. VL-C1-3) o coresa_hu.id (numérico como texto)';
COMMENT ON COLUMN vt_bultos_camion.fuente_dimensiones IS 'voxel_cam o coresa — indica en qué tabla buscar id_registro_origen';

-- ---------------------------------------------------------------------------
-- Índices
-- ---------------------------------------------------------------------------

-- Un número de viaje único
CREATE UNIQUE INDEX IF NOT EXISTS vt_camiones_numero_viaje_unico
  ON vt_camiones (numero_viaje);

-- Listado por estado (pantalla principal)
CREATE INDEX IF NOT EXISTS vt_camiones_estado_creado
  ON vt_camiones (estado, creado_en DESC);

-- Bultos por camión
CREATE INDEX IF NOT EXISTS vt_bultos_id_camion
  ON vt_bultos_camion (id_camion);

-- Consulta: ¿en qué camión está este HU?
CREATE INDEX IF NOT EXISTS vt_bultos_codigo_hu
  ON vt_bultos_camion (UPPER(TRIM(codigo_hu)));

-- BLOQUEO: un HU queda ocupado mientras exista la fila (incluye camiones enviados).
-- Solo se libera con DELETE (sacar HU de un camión abierto antes de enviar).
CREATE UNIQUE INDEX IF NOT EXISTS vt_hu_ocupado
  ON vt_bultos_camion (UPPER(TRIM(codigo_hu)));

-- Referencia al escaneo en Voxel Cam / CORESA
CREATE INDEX IF NOT EXISTS vt_bultos_registro_origen
  ON vt_bultos_camion (fuente_dimensiones, id_registro_origen);

-- ---------------------------------------------------------------------------
-- Función: actualizar actualizado_en en vt_camiones
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION vt_fn_camiones_actualizado_en()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.actualizado_en := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vt_camiones_actualizado_en ON vt_camiones;
CREATE TRIGGER trg_vt_camiones_actualizado_en
  BEFORE UPDATE ON vt_camiones
  FOR EACH ROW
  EXECUTE PROCEDURE vt_fn_camiones_actualizado_en();

-- ---------------------------------------------------------------------------
-- Función: antes de insertar bulto, validar camión abierto y copiar estado
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION vt_fn_bultos_before_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_estado TEXT;
BEGIN
  SELECT estado INTO v_estado
  FROM vt_camiones
  WHERE id = NEW.id_camion;

  IF v_estado IS NULL THEN
    RAISE EXCEPTION 'Camión % no existe', NEW.id_camion;
  END IF;

  IF v_estado <> 'abierto' THEN
    RAISE EXCEPTION 'Solo se pueden agregar HUs a camiones abiertos (estado actual: %)', v_estado;
  END IF;

  NEW.estado_camion := v_estado;
  NEW.codigo_hu := TRIM(NEW.codigo_hu);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vt_bultos_before_insert ON vt_bultos_camion;
CREATE TRIGGER trg_vt_bultos_before_insert
  BEFORE INSERT ON vt_bultos_camion
  FOR EACH ROW
  EXECUTE PROCEDURE vt_fn_bultos_before_insert();

-- ---------------------------------------------------------------------------
-- Función: después de insertar bulto, actualizar totales del camión
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION vt_fn_bultos_after_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE vt_camiones
  SET
    cantidad_hu       = cantidad_hu + 1,
    peso_total_kg     = peso_total_kg + NEW.peso_kg,
    volumen_total_m3  = volumen_total_m3 + NEW.volumen_m3,
    actualizado_en    = now()
  WHERE id = NEW.id_camion;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vt_bultos_after_insert ON vt_bultos_camion;
CREATE TRIGGER trg_vt_bultos_after_insert
  AFTER INSERT ON vt_bultos_camion
  FOR EACH ROW
  EXECUTE PROCEDURE vt_fn_bultos_after_insert();

-- ---------------------------------------------------------------------------
-- Función: al eliminar bulto, restar totales del camión
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION vt_fn_bultos_after_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE vt_camiones
  SET
    cantidad_hu       = GREATEST(0, cantidad_hu - 1),
    peso_total_kg     = GREATEST(0, peso_total_kg - OLD.peso_kg),
    volumen_total_m3  = GREATEST(0, volumen_total_m3 - OLD.volumen_m3),
    actualizado_en    = now()
  WHERE id = OLD.id_camion;

  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_vt_bultos_after_delete ON vt_bultos_camion;
CREATE TRIGGER trg_vt_bultos_after_delete
  AFTER DELETE ON vt_bultos_camion
  FOR EACH ROW
  EXECUTE PROCEDURE vt_fn_bultos_after_delete();

-- ---------------------------------------------------------------------------
-- Función: al cambiar estado del camión, sincronizar bultos
--   - Los HUs siguen bloqueados al enviar (no se desbloquean)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION vt_fn_camiones_sync_estado_bultos()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.estado IS DISTINCT FROM OLD.estado THEN
    UPDATE vt_bultos_camion
    SET estado_camion = NEW.estado
    WHERE id_camion = NEW.id;

    IF NEW.estado = 'enviado' AND NEW.enviado_en IS NULL THEN
      NEW.enviado_en := now();
    END IF;

    IF NEW.estado IN ('pendiente', 'cerrado', 'enviado') AND NEW.cerrado_en IS NULL THEN
      NEW.cerrado_en := now();
    END IF;

    IF NEW.estado = 'abierto' THEN
      NEW.cerrado_en := NULL;
      NEW.enviado_en := NULL;
      NEW.porcentaje_ocupacion := NULL;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vt_camiones_sync_estado_bultos ON vt_camiones;
CREATE TRIGGER trg_vt_camiones_sync_estado_bultos
  BEFORE UPDATE OF estado ON vt_camiones
  FOR EACH ROW
  EXECUTE PROCEDURE vt_fn_camiones_sync_estado_bultos();

-- =============================================================================
-- Consultas útiles (no ejecutar como parte del schema)
-- =============================================================================
--
-- ¿Está libre un HU?
-- SELECT NOT EXISTS (
--   SELECT 1 FROM vt_bultos_camion
--   WHERE UPPER(TRIM(codigo_hu)) = UPPER(TRIM('HU-884521'))
-- );
--
-- ¿En qué camión está un HU?
-- SELECT c.numero_viaje, c.estado, bc.codigo_hu, bc.estado_camion
-- FROM vt_bultos_camion bc
-- JOIN vt_camiones c ON c.id = bc.id_camion
-- WHERE UPPER(TRIM(bc.codigo_hu)) = UPPER(TRIM('HU-884521'));
