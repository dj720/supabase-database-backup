


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pgsodium";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."can_user_run_calculation"("user_uuid" "uuid") RETURNS TABLE("can_run" boolean, "current_count" integer, "monthly_limit" integer, "remaining_calculations" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    limit_record user_calculation_limits;
BEGIN
    -- Get or create the user's limit record
    limit_record := get_or_create_user_calculation_limit(user_uuid);
    
    -- Return the result
    RETURN QUERY SELECT 
        limit_record.calculation_count < limit_record.monthly_limit as can_run,
        limit_record.calculation_count as current_count,
        limit_record.monthly_limit as monthly_limit,
        GREATEST(0, limit_record.monthly_limit - limit_record.calculation_count) as remaining_calculations;
END;
$$;


ALTER FUNCTION "public"."can_user_run_calculation"("user_uuid" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."convert_param_to_new_format"("old_param" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    new_param JSONB;
    old_unit TEXT;
    old_dimension TEXT;
    units JSONB;
BEGIN
    -- Initialize new parameter structure
    new_param := jsonb_build_object(
        'type', COALESCE(old_param->>'type', 'float'),
        'label', COALESCE(old_param->>'label', ''),
        'symbol', COALESCE(old_param->>'symbol', ''),
        'default_value', old_param->'default',
        'optional', false,
        'precision', jsonb_build_object(
            'dp', 2,
            'sf', null
        ),
        'constraints', jsonb_build_object(
            'min', null,
            'max', null
        ),
        'help_text', COALESCE(old_param->>'description', '')
    );
    
    -- Get old unit and dimension
    old_unit := old_param->>'unit';
    old_dimension := old_param->>'dimension';
    
    -- Initialize units object
    units := jsonb_build_object();
    
    -- Add dimension if present
    IF old_dimension IS NOT NULL AND old_dimension != '' THEN
        units := units || jsonb_build_object('dimension', old_dimension);
    END IF;
    
    -- Map common units to metric/imperial equivalents
    CASE old_unit
        WHEN 'm³' THEN units := units || jsonb_build_object('metric', 'meter**3', 'imperial', 'foot**3');
        WHEN 'm²' THEN units := units || jsonb_build_object('metric', 'meter**2', 'imperial', 'foot**2');
        WHEN 'm' THEN units := units || jsonb_build_object('metric', 'meter', 'imperial', 'foot');
        WHEN 'kg' THEN units := units || jsonb_build_object('metric', 'kilogram', 'imperial', 'pound');
        WHEN 'Pa' THEN units := units || jsonb_build_object('metric', 'pascal', 'imperial', 'pound_per_square_inch');
        WHEN 'W' THEN units := units || jsonb_build_object('metric', 'watt', 'imperial', 'btu_per_hour');
        WHEN '°C' THEN units := units || jsonb_build_object('metric', 'celsius', 'imperial', 'fahrenheit');
        WHEN 'K' THEN units := units || jsonb_build_object('metric', 'kelvin', 'imperial', 'rankine');
        WHEN 'm/s' THEN units := units || jsonb_build_object('metric', 'meter_per_second', 'imperial', 'foot_per_second');
        WHEN 'm³/s' THEN units := units || jsonb_build_object('metric', 'meter**3_per_second', 'imperial', 'foot**3_per_second');
        WHEN 'kg/m³' THEN units := units || jsonb_build_object('metric', 'kilogram_per_meter**3', 'imperial', 'pound_per_foot**3');
        WHEN 'W/m²' THEN units := units || jsonb_build_object('metric', 'watt_per_meter**2', 'imperial', 'btu_per_hour_per_foot**2');
        WHEN 'W/m²K' THEN units := units || jsonb_build_object('metric', 'watt_per_meter**2_kelvin', 'imperial', 'btu_per_hour_per_foot**2_fahrenheit');
        WHEN 'J' THEN units := units || jsonb_build_object('metric', 'joule', 'imperial', 'btu');
        WHEN 'J/kg' THEN units := units || jsonb_build_object('metric', 'joule_per_kilogram', 'imperial', 'btu_per_pound');
        WHEN 'J/kg·K' THEN units := units || jsonb_build_object('metric', 'joule_per_kilogram_kelvin', 'imperial', 'btu_per_pound_fahrenheit');
        WHEN 'W/m·K' THEN units := units || jsonb_build_object('metric', 'watt_per_meter_kelvin', 'imperial', 'btu_per_hour_per_foot_fahrenheit');
        WHEN 'm³/h' THEN units := units || jsonb_build_object('metric', 'meter**3_per_hour', 'imperial', 'foot**3_per_hour');
        WHEN 'L/s' THEN units := units || jsonb_build_object('metric', 'liter_per_second', 'imperial', 'gallon_per_second');
        WHEN 'L/min' THEN units := units || jsonb_build_object('metric', 'liter_per_minute', 'imperial', 'gallon_per_minute');
        WHEN 'bar' THEN units := units || jsonb_build_object('metric', 'bar', 'imperial', 'pound_per_square_inch');
        WHEN 'kPa' THEN units := units || jsonb_build_object('metric', 'kilopascal', 'imperial', 'pound_per_square_inch');
        WHEN 'MPa' THEN units := units || jsonb_build_object('metric', 'megapascal', 'imperial', 'pound_per_square_inch');
        WHEN 'N' THEN units := units || jsonb_build_object('metric', 'newton', 'imperial', 'pound_force');
        WHEN 'kN' THEN units := units || jsonb_build_object('metric', 'kilonewton', 'imperial', 'pound_force');
        WHEN 'Hz' THEN units := units || jsonb_build_object('metric', 'hertz', 'imperial', 'hertz');
        WHEN 'dB' THEN units := units || jsonb_build_object('metric', 'decibel', 'imperial', 'decibel');
        WHEN 'lux' THEN units := units || jsonb_build_object('metric', 'lux', 'imperial', 'foot_candle');
        WHEN 'lm' THEN units := units || jsonb_build_object('metric', 'lumen', 'imperial', 'lumen');
        WHEN 'cd' THEN units := units || jsonb_build_object('metric', 'candela', 'imperial', 'candela');
        WHEN 'V' THEN units := units || jsonb_build_object('metric', 'volt', 'imperial', 'volt');
        WHEN 'A' THEN units := units || jsonb_build_object('metric', 'ampere', 'imperial', 'ampere');
        WHEN 'Ω' THEN units := units || jsonb_build_object('metric', 'ohm', 'imperial', 'ohm');
        WHEN 'F' THEN units := units || jsonb_build_object('metric', 'farad', 'imperial', 'farad');
        WHEN 'H' THEN units := units || jsonb_build_object('metric', 'henry', 'imperial', 'henry');
        WHEN 'T' THEN units := units || jsonb_build_object('metric', 'tesla', 'imperial', 'tesla');
        WHEN 'Wb' THEN units := units || jsonb_build_object('metric', 'weber', 'imperial', 'weber');
        WHEN 'lm/m²' THEN units := units || jsonb_build_object('metric', 'lumen_per_meter**2', 'imperial', 'lumen_per_foot**2');
        WHEN 'cd/m²' THEN units := units || jsonb_build_object('metric', 'candela_per_meter**2', 'imperial', 'candela_per_foot**2');
        ELSE 
            -- Fallback: use the old unit as metric and imperial
            units := units || jsonb_build_object('metric', COALESCE(old_unit, ''), 'imperial', COALESCE(old_unit, ''));
    END CASE;
    
    -- Add units to the new parameter
    new_param := new_param || jsonb_build_object('units', units);
    
    -- Handle validation constraints if present
    IF old_param ? 'validation' AND old_param->'validation' IS NOT NULL THEN
        DECLARE
            validation_rules JSONB;
        BEGIN
            -- Try to parse validation as JSON if it's a string
            IF jsonb_typeof(old_param->'validation') = 'string' THEN
                BEGIN
                    validation_rules := (old_param->>'validation')::jsonb;
                EXCEPTION WHEN OTHERS THEN
                    validation_rules := old_param->'validation';
                END;
            ELSE
                validation_rules := old_param->'validation';
            END IF;
            
            -- Extract min/max constraints
            IF validation_rules ? 'min' THEN
                new_param := jsonb_set(new_param, '{constraints,min}', validation_rules->'min');
            END IF;
            IF validation_rules ? 'max' THEN
                new_param := jsonb_set(new_param, '{constraints,max}', validation_rules->'max');
            END IF;
            
            -- Extract precision settings
            IF validation_rules ? 'decimal_places' THEN
                new_param := jsonb_set(new_param, '{precision,dp}', validation_rules->'decimal_places');
            END IF;
            IF validation_rules ? 'significant_figures' THEN
                new_param := jsonb_set(new_param, '{precision,sf}', validation_rules->'significant_figures');
            END IF;
        END;
    END IF;
    
    RETURN new_param;
END;
$$;


ALTER FUNCTION "public"."convert_param_to_new_format"("old_param" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."convert_param_to_new_format"("old_param" "jsonb") IS 'Converts old ParamSchema format to new format with enhanced unit handling';



CREATE OR REPLACE FUNCTION "public"."convert_schema_to_new_format"("old_schema" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    new_schema JSONB;
    param_key TEXT;
    param_value JSONB;
BEGIN
    new_schema := '{}'::jsonb;
    
    IF old_schema IS NOT NULL THEN
        FOR param_key, param_value IN SELECT * FROM jsonb_each(old_schema)
        LOOP
            new_schema := new_schema || jsonb_build_object(param_key, convert_param_to_new_format(param_value));
        END LOOP;
    END IF;
    
    RETURN new_schema;
END;
$$;


ALTER FUNCTION "public"."convert_schema_to_new_format"("old_schema" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."convert_schema_to_new_format"("old_schema" "jsonb") IS 'Converts entire schema object from old to new format';



CREATE OR REPLACE FUNCTION "public"."fix_param_schema_dimension"("param_schema" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- If no units object, return as-is
    IF NOT (param_schema ? 'units' AND param_schema->'units' IS NOT NULL) THEN
        RETURN param_schema;
    END IF;
    
    -- Fix the units object
    RETURN jsonb_set(
        param_schema,
        '{units}',
        fix_units_dimension(param_schema->'units')
    );
END;
$$;


ALTER FUNCTION "public"."fix_param_schema_dimension"("param_schema" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."fix_param_schema_dimension"("param_schema" "jsonb") IS 'Fixes dimension in parameter schema units';



CREATE OR REPLACE FUNCTION "public"."fix_schema_dimensions"("schema_obj" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    result JSONB;
    param_key TEXT;
    param_value JSONB;
BEGIN
    result := '{}'::jsonb;
    
    IF schema_obj IS NOT NULL THEN
        FOR param_key, param_value IN SELECT * FROM jsonb_each(schema_obj)
        LOOP
            result := result || jsonb_build_object(param_key, fix_param_schema_dimension(param_value));
        END LOOP;
    END IF;
    
    RETURN result;
END;
$$;


ALTER FUNCTION "public"."fix_schema_dimensions"("schema_obj" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."fix_schema_dimensions"("schema_obj" "jsonb") IS 'Fixes dimensions in entire schema objects';



CREATE OR REPLACE FUNCTION "public"."fix_units_dimension"("units_obj" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    metric_unit TEXT;
    dimension TEXT;
    result JSONB;
BEGIN
    -- If already has dimension, return as-is
    IF units_obj ? 'dimension' AND units_obj->>'dimension' IS NOT NULL AND units_obj->>'dimension' != '' THEN
        RETURN units_obj;
    END IF;
    
    -- Get metric unit
    metric_unit := units_obj->>'metric';
    
    IF metric_unit IS NULL OR metric_unit = '' THEN
        RETURN units_obj;
    END IF;
    
    -- Get dimension from unit
    dimension := get_dimension_from_unit(metric_unit);
    
    IF dimension IS NULL THEN
        RETURN units_obj;
    END IF;
    
    -- Add dimension to units object
    result := units_obj || jsonb_build_object('dimension', dimension);
    
    RETURN result;
END;
$$;


ALTER FUNCTION "public"."fix_units_dimension"("units_obj" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."fix_units_dimension"("units_obj" "jsonb") IS 'Adds dimension attribute to units objects';



CREATE OR REPLACE FUNCTION "public"."get_admin_users"() RETURNS TABLE("id" "uuid", "email" "text", "full_name" "text", "is_admin" boolean, "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.email,
    u.raw_user_meta_data->>'full_name' as full_name,
    COALESCE((u.raw_user_meta_data->>'is_admin')::boolean, false) as is_admin,
    u.created_at
  FROM auth.users u
  WHERE COALESCE((u.raw_user_meta_data->>'is_admin')::boolean, false) = true;
END;
$$;


ALTER FUNCTION "public"."get_admin_users"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_dimension_from_unit"("unit" "text") RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Comprehensive mapping of units to dimensions
    CASE LOWER(TRIM(unit))
        -- Length/Distance
        WHEN 'm', 'meter', 'meters', 'mm', 'millimeter', 'millimeters', 
             'cm', 'centimeter', 'centimeters', 'km', 'kilometer', 'kilometers',
             'ft', 'foot', 'feet', 'in', 'inch', 'inches', 'yd', 'yard', 'yards'
        THEN RETURN 'length';
        
        -- Area
        WHEN 'm²', 'meter**2', 'square_meter', 'square_meters',
             'mm²', 'millimeter**2', 'square_millimeter',
             'cm²', 'centimeter**2', 'square_centimeter',
             'km²', 'kilometer**2', 'square_kilometer',
             'ft²', 'foot**2', 'square_foot', 'square_feet',
             'in²', 'inch**2', 'square_inch', 'square_inches'
        THEN RETURN 'area';
        
        -- Volume
        WHEN 'm³', 'meter**3', 'cubic_meter', 'cubic_meters',
             'mm³', 'millimeter**3', 'cubic_millimeter',
             'cm³', 'centimeter**3', 'cubic_centimeter',
             'l', 'liter', 'liters', 'ft³', 'foot**3', 'cubic_foot', 'cubic_feet',
             'in³', 'inch**3', 'cubic_inch', 'cubic_inches',
             'gal', 'gallon', 'gallons'
        THEN RETURN 'volume';
        
        -- Mass
        WHEN 'kg', 'kilogram', 'kilograms', 'g', 'gram', 'grams',
             'mg', 'milligram', 'milligrams', 't', 'tonne', 'tonnes',
             'lb', 'pound', 'pounds', 'oz', 'ounce', 'ounces'
        THEN RETURN 'mass';
        
        -- Time
        WHEN 's', 'second', 'seconds', 'min', 'minute', 'minutes',
             'h', 'hour', 'hours', 'day', 'days', 'week', 'weeks',
             'month', 'months', 'year', 'years'
        THEN RETURN 'time';
        
        -- Frequency
        WHEN 'hz', 'hertz', '1/s', 'per_second', '1/min', 'per_minute',
             '1/h', 'per_hour', 'rpm', 'revolutions_per_minute'
        THEN RETURN 'frequency';
        
        -- Velocity/Speed
        WHEN 'm/s', 'meter_per_second', 'km/h', 'kilometer_per_hour',
             'ft/s', 'foot_per_second', 'mph', 'mile_per_hour'
        THEN RETURN 'velocity';
        
        -- Acceleration
        WHEN 'm/s²', 'meter_per_second**2', 'ft/s²', 'foot_per_second**2'
        THEN RETURN 'acceleration';
        
        -- Force
        WHEN 'n', 'newton', 'newtons', 'kn', 'kilonewton', 'kilonewtons',
             'lbf', 'pound_force', 'pounds_force'
        THEN RETURN 'force';
        
        -- Pressure
        WHEN 'pa', 'pascal', 'pascals', 'kpa', 'kilopascal', 'kilopascals',
             'mpa', 'megapascal', 'megapascals', 'bar', 'bars',
             'psi', 'pound_per_square_inch', 'psf', 'pound_per_square_foot',
             'atm', 'atmosphere', 'atmospheres', 'torr', 'mmhg', 'millimeter_of_mercury',
             'inhg', 'inch_of_mercury'
        THEN RETURN 'pressure';
        
        -- Energy
        WHEN 'j', 'joule', 'joules', 'kj', 'kilojoule', 'kilojoules',
             'mj', 'megajoule', 'megajoules', 'wh', 'watt_hour', 'watt_hours',
             'kwh', 'kilowatt_hour', 'kilowatt_hours', 'mwh', 'megawatt_hour', 'megawatt_hours',
             'btu', 'cal', 'calorie', 'calories', 'kcal', 'kilocalorie', 'kilocalories'
        THEN RETURN 'energy';
        
        -- Power
        WHEN 'w', 'watt', 'watts', 'kw', 'kilowatt', 'kilowatts',
             'mw', 'megawatt', 'megawatts', 'hp', 'horsepower',
             'btu/h', 'btu_per_hour', 'btu/hr'
        THEN RETURN 'power';
        
        -- Temperature
        WHEN 'k', 'kelvin', '°c', 'celsius', '°f', 'fahrenheit', '°r', 'rankine'
        THEN RETURN 'temperature';
        
        -- Flow Rate (Volume per time)
        WHEN 'm³/s', 'meter**3_per_second', 'm³/h', 'meter**3_per_hour',
             'l/s', 'liter_per_second', 'l/min', 'liter_per_minute',
             'l/h', 'liter_per_hour', 'ft³/s', 'foot**3_per_second',
             'ft³/min', 'foot**3_per_minute', 'ft³/h', 'foot**3_per_hour',
             'cfm', 'cubic_feet_per_minute', 'cfh', 'cubic_feet_per_hour',
             'gpm', 'gallon_per_minute', 'gph', 'gallon_per_hour',
             'gps', 'gallon_per_second'
        THEN RETURN 'flow_rate';
        
        -- Mass Flow Rate
        WHEN 'kg/s', 'kilogram_per_second', 'kg/min', 'kilogram_per_minute',
             'kg/h', 'kilogram_per_hour', 'lb/s', 'pound_per_second',
             'lb/min', 'pound_per_minute', 'lb/h', 'pound_per_hour'
        THEN RETURN 'mass_flow_rate';
        
        -- Density
        WHEN 'kg/m³', 'kilogram_per_meter**3', 'g/cm³', 'gram_per_centimeter**3',
             'lb/ft³', 'pound_per_foot**3', 'lb/gal', 'pound_per_gallon'
        THEN RETURN 'density';
        
        -- Specific Volume
        WHEN 'm³/kg', 'meter**3_per_kilogram', 'ft³/lb', 'foot**3_per_pound'
        THEN RETURN 'specific_volume';
        
        -- Dynamic Viscosity
        WHEN 'pa·s', 'pascal_second', 'cp', 'centipoise', 'p', 'poise'
        THEN RETURN 'dynamic_viscosity';
        
        -- Kinematic Viscosity
        WHEN 'm²/s', 'meter**2_per_second', 'cst', 'centistokes', 'st', 'stokes'
        THEN RETURN 'kinematic_viscosity';
        
        -- Thermal Conductivity
        WHEN 'w/(m·k)', 'watt_per_meter_kelvin', 'w/(m·°c)', 'watt_per_meter_celsius',
             'btu/(h·ft·°f)', 'btu_per_hour_per_foot_fahrenheit'
        THEN RETURN 'thermal_conductivity';
        
        -- Heat Transfer Coefficient
        WHEN 'w/(m²·k)', 'watt_per_meter**2_kelvin', 'w/(m²·°c)', 'watt_per_meter**2_celsius',
             'btu/(h·ft²·°f)', 'btu_per_hour_per_foot**2_fahrenheit'
        THEN RETURN 'heat_transfer_coefficient';
        
        -- Specific Heat Capacity
        WHEN 'j/(kg·k)', 'joule_per_kilogram_kelvin', 'j/(kg·°c)', 'joule_per_kilogram_celsius',
             'btu/(lb·°f)', 'btu_per_pound_fahrenheit', 'cal/(g·°c)', 'calorie_per_gram_celsius'
        THEN RETURN 'specific_heat_capacity';
        
        -- Electrical
        WHEN 'a', 'ampere', 'amperes'
        THEN RETURN 'electric_current';
        WHEN 'v', 'volt', 'volts'
        THEN RETURN 'electric_potential';
        WHEN 'ω', 'ohm', 'ohms'
        THEN RETURN 'electric_resistance';
        WHEN 'f', 'farad', 'farads'
        THEN RETURN 'electric_capacitance';
        WHEN 'h', 'henry', 'henries'
        THEN RETURN 'electric_inductance';
        WHEN 'c', 'coulomb', 'coulombs'
        THEN RETURN 'electric_charge';
        
        -- Magnetic
        WHEN 't', 'tesla', 'teslas'
        THEN RETURN 'magnetic_field';
        WHEN 'wb', 'weber', 'webers'
        THEN RETURN 'magnetic_flux';
        
        -- Luminous
        WHEN 'cd', 'candela', 'candelas'
        THEN RETURN 'luminous_intensity';
        WHEN 'lm', 'lumen', 'lumens'
        THEN RETURN 'luminous_flux';
        WHEN 'lx', 'lux', 'fc', 'foot_candle', 'foot_candles'
        THEN RETURN 'illuminance';
        WHEN 'cd/m²', 'candela_per_meter**2', 'cd/ft²', 'candela_per_foot**2'
        THEN RETURN 'luminance';
        
        -- Sound
        WHEN 'db', 'decibel', 'decibels'
        THEN RETURN 'sound_level';
        
        -- Dimensionless
        WHEN '1', 'ratio', 'percent', '%', 'ppm', 'parts_per_million',
             'ppb', 'parts_per_billion'
        THEN RETURN 'dimensionless';
        
        ELSE
            -- Try to infer from patterns
            IF unit LIKE '%per_second%' OR unit LIKE '%/s%' THEN
                IF unit LIKE '%meter**3%' OR unit LIKE '%m³%' THEN
                    RETURN 'flow_rate';
                ELSIF unit LIKE '%kilogram%' OR unit LIKE '%kg%' THEN
                    RETURN 'mass_flow_rate';
                ELSIF unit LIKE '%meter**2%' OR unit LIKE '%m²%' THEN
                    RETURN 'kinematic_viscosity';
                ELSE
                    RETURN 'frequency';
                END IF;
            ELSIF unit LIKE '%per_hour%' OR unit LIKE '%/h%' THEN
                IF unit LIKE '%meter**3%' OR unit LIKE '%m³%' THEN
                    RETURN 'flow_rate';
                ELSIF unit LIKE '%kilogram%' OR unit LIKE '%kg%' THEN
                    RETURN 'mass_flow_rate';
                ELSE
                    RETURN 'frequency';
                END IF;
            ELSIF unit LIKE '%per_minute%' OR unit LIKE '%/min%' THEN
                IF unit LIKE '%meter**3%' OR unit LIKE '%m³%' THEN
                    RETURN 'flow_rate';
                ELSIF unit LIKE '%kilogram%' OR unit LIKE '%kg%' THEN
                    RETURN 'mass_flow_rate';
                ELSE
                    RETURN 'frequency';
                END IF;
            END IF;
            
            RETURN NULL;
    END CASE;
END;
$$;


ALTER FUNCTION "public"."get_dimension_from_unit"("unit" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_dimension_from_unit"("unit" "text") IS 'Maps units to their physical dimensions';


SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."user_calculation_limits" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "month_year" "text" NOT NULL,
    "calculation_count" integer DEFAULT 0 NOT NULL,
    "monthly_limit" integer DEFAULT 100 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_calculation_limits" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_calculation_limits" IS 'Tracks monthly calculation usage limits for users';



COMMENT ON COLUMN "public"."user_calculation_limits"."month_year" IS 'Month in YYYY-MM format for tracking monthly limits';



COMMENT ON COLUMN "public"."user_calculation_limits"."calculation_count" IS 'Number of calculations run this month';



COMMENT ON COLUMN "public"."user_calculation_limits"."monthly_limit" IS 'Maximum number of calculations allowed per month';



CREATE OR REPLACE FUNCTION "public"."get_or_create_user_calculation_limit"("user_uuid" "uuid") RETURNS "public"."user_calculation_limits"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    current_month text;
    limit_record user_calculation_limits;
BEGIN
    -- Get current month in YYYY-MM format
    current_month := to_char(now(), 'YYYY-MM');
    
    -- Try to get existing record
    SELECT * INTO limit_record 
    FROM user_calculation_limits 
    WHERE user_id = user_uuid AND month_year = current_month;
    
    -- If no record exists, create one
    IF limit_record IS NULL THEN
        INSERT INTO user_calculation_limits (user_id, month_year, calculation_count, monthly_limit)
        VALUES (user_uuid, current_month, 0, 100) -- Default limit of 100
        RETURNING * INTO limit_record;
    END IF;
    
    RETURN limit_record;
END;
$$;


ALTER FUNCTION "public"."get_or_create_user_calculation_limit"("user_uuid" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_super_admin_users"() RETURNS TABLE("id" "uuid", "email" "text", "full_name" "text", "is_super_admin" boolean, "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.email,
    u.raw_user_meta_data->>'full_name' as full_name,
    COALESCE(u.is_super_admin, false) as is_super_admin,
    u.created_at
  FROM auth.users u
  WHERE COALESCE(u.is_super_admin, false) = true;
END;
$$;


ALTER FUNCTION "public"."get_super_admin_users"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_calculation_usage_history"("user_uuid" "uuid") RETURNS TABLE("month_year" "text", "calculation_count" integer, "monthly_limit" integer, "usage_percentage" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ucl.month_year,
        ucl.calculation_count,
        ucl.monthly_limit,
        CASE 
            WHEN ucl.monthly_limit > 0 THEN 
                ROUND((ucl.calculation_count::numeric / ucl.monthly_limit::numeric) * 100, 2)
            ELSE 0 
        END as usage_percentage
    FROM user_calculation_limits ucl
    WHERE ucl.user_id = user_uuid
    ORDER BY ucl.month_year DESC
    LIMIT 12;
END;
$$;


ALTER FUNCTION "public"."get_user_calculation_usage_history"("user_uuid" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_user_calculation_count"("user_uuid" "uuid") RETURNS "public"."user_calculation_limits"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    limit_record user_calculation_limits;
BEGIN
    -- Get or create the user's limit record
    limit_record := get_or_create_user_calculation_limit(user_uuid);
    
    -- Increment the count
    UPDATE user_calculation_limits 
    SET calculation_count = calculation_count + 1
    WHERE user_id = user_uuid AND month_year = limit_record.month_year
    RETURNING * INTO limit_record;
    
    RETURN limit_record;
END;
$$;


ALTER FUNCTION "public"."increment_user_calculation_count"("user_uuid" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin"("user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Check if the user has admin role in their user_metadata
  RETURN (
    SELECT COALESCE(
      (user_metadata->>'is_admin')::boolean, 
      false
    )
    FROM auth.users 
    WHERE id = user_id
  );
END;
$$;


ALTER FUNCTION "public"."is_admin"("user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_super_admin"("user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Check if the user has super admin role in the dedicated column
  RETURN (
    SELECT COALESCE(is_super_admin, false)
    FROM auth.users 
    WHERE id = user_id
  );
END;
$$;


ALTER FUNCTION "public"."is_super_admin"("user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reset_user_calculation_count"("user_uuid" "uuid") RETURNS "public"."user_calculation_limits"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    limit_record user_calculation_limits;
    current_month text;
BEGIN
    -- Check if caller is super admin
    IF NOT is_super_admin(auth.uid()) THEN
        RAISE EXCEPTION 'Only super admins can reset calculation counts';
    END IF;
    
    -- Get current month
    current_month := to_char(now(), 'YYYY-MM');
    
    -- Update the count to 0
    UPDATE user_calculation_limits 
    SET calculation_count = 0
    WHERE user_id = user_uuid AND month_year = current_month
    RETURNING * INTO limit_record;
    
    -- If no record was updated, create one
    IF limit_record IS NULL THEN
        INSERT INTO user_calculation_limits (user_id, month_year, calculation_count, monthly_limit)
        VALUES (user_uuid, current_month, 0, 100)
        RETURNING * INTO limit_record;
    END IF;
    
    RETURN limit_record;
END;
$$;


ALTER FUNCTION "public"."reset_user_calculation_count"("user_uuid" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."seed_ventilation_calculations"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    admin_user_id UUID;
BEGIN
    -- Find a user ID to use for system calculations (first user in the system)
    SELECT id INTO admin_user_id FROM auth.users LIMIT 1;
    
    IF admin_user_id IS NULL THEN
        RAISE EXCEPTION 'No users found in the system to associate with ventilation calculations';
    END IF;
    
    -- Only insert if not already present (based on name)
    
    -- ACH from VFR calculation
    INSERT INTO public.calculations (name, description, formula, inputs, outputs, is_shared, type, user_id, project_id)
    SELECT 
        'ACH from Volume Flow Rate', 
        'Calculate the Air Changes Per Hour (ACH) for a room with a given volume flow rate',
        'outputs["ach"] = inputs["volume_flow_rate"] * 3600 / inputs["room_volume"]',
        ARRAY[
            '{"id":"room_volume","name":"Room Volume","description":"Room volume","unit":"m³","type":"number","is_required":true}',
            '{"id":"volume_flow_rate","name":"Volume Flow Rate","description":"Volume flow rate","unit":"m³/s","type":"number","is_required":true}'
        ],
        ARRAY[
            '{"id":"ach","name":"Air Changes per Hour","description":"Calculated air changes per hour","unit":"ACH","type":"number","is_required":true}'
        ],
        TRUE,
        'ventilation',
        admin_user_id,
        (SELECT id FROM projects WHERE user_id = admin_user_id LIMIT 1)
    WHERE NOT EXISTS (
        SELECT 1 FROM public.calculations WHERE name = 'ACH from Volume Flow Rate' AND type = 'ventilation'
    );
    
    -- Continue with other calculations, adding user_id and project_id to each INSERT
    -- VFR from ACH calculation
    INSERT INTO public.calculations (name, description, formula, inputs, outputs, is_shared, type, user_id, project_id)
    SELECT 
        'Volume Flow Rate from ACH', 
        'Calculate the required volume flow rate for a room volume based on a given air changes per hour',
        'outputs["volume_flow_rate"] = inputs["room_volume"] * inputs["air_changes_per_hour"] / 3600',
        ARRAY[
            '{"id":"room_volume","name":"Room Volume","description":"Room volume","unit":"m³","type":"number","is_required":true}',
            '{"id":"air_changes_per_hour","name":"Air Changes per Hour","description":"Required air changes per hour","unit":"ACH","type":"number","is_required":true}'
        ],
        ARRAY[
            '{"id":"volume_flow_rate","name":"Volume Flow Rate","description":"Required volume flow rate","unit":"m³/s","type":"number","is_required":true}'
        ],
        TRUE,
        'ventilation',
        admin_user_id,
        (SELECT id FROM projects WHERE user_id = admin_user_id LIMIT 1)
    WHERE NOT EXISTS (
        SELECT 1 FROM public.calculations WHERE name = 'Volume Flow Rate from ACH' AND type = 'ventilation'
    );
    
    -- OFR calculation
    INSERT INTO public.calculations (name, description, formula, inputs, outputs, is_shared, type, user_id, project_id)
    SELECT 
        'Occupant Flow Rate', 
        'Calculate the required volume flow rate for a room based on a given room occupation',
        'outputs["volume_flow_rate"] = inputs["occupation"] * inputs["air_per_person"] / 1000',
        ARRAY[
            '{"id":"occupation","name":"Occupation","description":"Number of people","unit":"people","type":"number","is_required":true}',
            '{"id":"air_per_person","name":"Air per Person","description":"Required air per person","unit":"l/s","type":"number","is_required":true}'
        ],
        ARRAY[
            '{"id":"volume_flow_rate","name":"Volume Flow Rate","description":"Required volume flow rate","unit":"m³/s","type":"number","is_required":true}'
        ],
        TRUE,
        'ventilation',
        admin_user_id,
        (SELECT id FROM projects WHERE user_id = admin_user_id LIMIT 1)
    WHERE NOT EXISTS (
        SELECT 1 FROM public.calculations WHERE name = 'Occupant Flow Rate' AND type = 'ventilation'
    );
    
    -- Add the remaining calculations with user_id and project_id...
    -- ACH vs OFR calculation
    INSERT INTO public.calculations (name, description, formula, inputs, outputs, is_shared, type, user_id, project_id)
    SELECT 
        'ACH vs OFR Comparison', 
        'Compare the required volume flow rates from ACH and OFR methods and return the most onerous (highest) value',
        'vfr_ach = inputs["room_volume"] * inputs["air_changes_per_hour"] / 3600
vfr_ofr = inputs["occupation"] * inputs["air_per_person"] / 1000
if vfr_ach > vfr_ofr:
    outputs["most_onerous_vfr"] = vfr_ach
    outputs["method"] = "ACH"
else:
    outputs["most_onerous_vfr"] = vfr_ofr
    outputs["method"] = "OFR"',
        ARRAY[
            '{"id":"room_volume","name":"Room Volume","description":"Room volume","unit":"m³","type":"number","is_required":true}',
            '{"id":"air_changes_per_hour","name":"Air Changes per Hour","description":"Required air changes per hour","unit":"ACH","type":"number","is_required":true}',
            '{"id":"occupation","name":"Occupation","description":"Number of people","unit":"people","type":"number","is_required":true}',
            '{"id":"air_per_person","name":"Air per Person","description":"Required air per person","unit":"l/s","type":"number","is_required":true}'
        ],
        ARRAY[
            '{"id":"most_onerous_vfr","name":"Most Onerous VFR","description":"Most onerous (highest) required volume flow rate","unit":"m³/s","type":"number","is_required":true}',
            '{"id":"method","name":"Method","description":"Method that gave the most onerous result","unit":"","type":"text","is_required":true}'
        ],
        TRUE,
        'ventilation',
        admin_user_id,
        (SELECT id FROM projects WHERE user_id = admin_user_id LIMIT 1)
    WHERE NOT EXISTS (
        SELECT 1 FROM public.calculations WHERE name = 'ACH vs OFR Comparison' AND type = 'ventilation'
    );
    
    -- Air Velocity calculation
    INSERT INTO public.calculations (name, description, formula, inputs, outputs, is_shared, type, user_id, project_id)
    SELECT 
        'Air Velocity', 
        'Calculate the air velocity in a duct',
        'if inputs["duct_area"] <= 0:
    outputs["error"] = "Duct area must be greater than zero."
else:
    outputs["velocity"] = inputs["volume_flow_rate"] / inputs["duct_area"]',
        ARRAY[
            '{"id":"volume_flow_rate","name":"Volume Flow Rate","description":"Air volume flow rate","unit":"m³/s","type":"number","is_required":true}',
            '{"id":"duct_area","name":"Duct Area","description":"Duct cross-sectional area","unit":"m²","type":"number","is_required":true}'
        ],
        ARRAY[
            '{"id":"velocity","name":"Air Velocity","description":"Air velocity in duct","unit":"m/s","type":"number","is_required":true}'
        ],
        TRUE,
        'ventilation',
        admin_user_id,
        (SELECT id FROM projects WHERE user_id = admin_user_id LIMIT 1)
    WHERE NOT EXISTS (
        SELECT 1 FROM public.calculations WHERE name = 'Air Velocity' AND type = 'ventilation'
    );
    
    -- VFR from Velocity calculation
    INSERT INTO public.calculations (name, description, formula, inputs, outputs, is_shared, type, user_id, project_id)
    SELECT 
        'VFR from Velocity', 
        'Calculate the maximum volume flow rate in a duct for a specified maximum air velocity',
        'if inputs["duct_area"] <= 0:
    outputs["error"] = "Duct area must be greater than zero."
elif inputs["max_velocity"] < 0:
    outputs["error"] = "Maximum velocity must be non-negative."
else:
    outputs["max_volume_flow_rate"] = inputs["max_velocity"] * inputs["duct_area"]',
        ARRAY[
            '{"id":"max_velocity","name":"Maximum Velocity","description":"Maximum allowable air velocity","unit":"m/s","type":"number","is_required":true,"default_value":3.0}',
            '{"id":"duct_area","name":"Duct Area","description":"Duct cross-sectional area","unit":"m²","type":"number","is_required":true}'
        ],
        ARRAY[
            '{"id":"max_volume_flow_rate","name":"Maximum VFR","description":"Maximum volume flow rate","unit":"m³/s","type":"number","is_required":true}'
        ],
        TRUE,
        'ventilation',
        admin_user_id,
        (SELECT id FROM projects WHERE user_id = admin_user_id LIMIT 1)
    WHERE NOT EXISTS (
        SELECT 1 FROM public.calculations WHERE name = 'VFR from Velocity' AND type = 'ventilation'
    );
    
    -- Louvre Face Velocity
    INSERT INTO public.calculations (name, description, formula, inputs, outputs, is_shared, type, user_id, project_id)
    SELECT 
        'Louvre Face Velocity', 
        'Calculate the face velocity of a louvre based on width, height, free area percentage, and volume flow rate',
        'if inputs["width_mm"] <= 0 or inputs["height_mm"] <= 0:
    outputs["error"] = "Width and height must be greater than zero."
elif not (0 < inputs["free_area"] <= 100):
    outputs["error"] = "Free area percentage must be between 0 and 100."
else:
    gross_area = (inputs["width_mm"] / 1000) * (inputs["height_mm"] / 1000)
    effective_area = gross_area * (inputs["free_area"] / 100)
    if effective_area <= 0:
        outputs["error"] = "Effective free area must be greater than zero."
    else:
        outputs["face_velocity"] = inputs["volume_flow_rate"] / effective_area',
        ARRAY[
            '{"id":"volume_flow_rate","name":"Volume Flow Rate","description":"Air volume flow rate","unit":"m³/s","type":"number","is_required":true}',
            '{"id":"width_mm","name":"Width","description":"Louvre width","unit":"mm","type":"number","is_required":true}',
            '{"id":"height_mm","name":"Height","description":"Louvre height","unit":"mm","type":"number","is_required":true}',
            '{"id":"free_area","name":"Free Area","description":"Free area percentage","unit":"%","type":"number","is_required":true,"default_value":50.0}'
        ],
        ARRAY[
            '{"id":"face_velocity","name":"Face Velocity","description":"Face velocity","unit":"m/s","type":"number","is_required":true}'
        ],
        TRUE,
        'ventilation',
        admin_user_id,
        (SELECT id FROM projects WHERE user_id = admin_user_id LIMIT 1)
    WHERE NOT EXISTS (
        SELECT 1 FROM public.calculations WHERE name = 'Louvre Face Velocity' AND type = 'ventilation'
    );
    
    -- Duct Aspect Ratio
    INSERT INTO public.calculations (name, description, formula, inputs, outputs, is_shared, type, user_id, project_id)
    SELECT 
        'Duct Aspect Ratio', 
        'Calculate the aspect ratio of a rectangular duct',
        'aspect_ratio = inputs["width_mm"] / inputs["height_mm"]
if aspect_ratio < 1:
    aspect_ratio = 1 / aspect_ratio
outputs["aspect_ratio"] = aspect_ratio',
        ARRAY[
            '{"id":"width_mm","name":"Width","description":"Duct width","unit":"mm","type":"number","is_required":true}',
            '{"id":"height_mm","name":"Height","description":"Duct height","unit":"mm","type":"number","is_required":true}'
        ],
        ARRAY[
            '{"id":"aspect_ratio","name":"Aspect Ratio","description":"Duct aspect ratio (always ≥ 1)","unit":"","type":"number","is_required":true}'
        ],
        TRUE,
        'ventilation',
        admin_user_id,
        (SELECT id FROM projects WHERE user_id = admin_user_id LIMIT 1)
    WHERE NOT EXISTS (
        SELECT 1 FROM public.calculations WHERE name = 'Duct Aspect Ratio' AND type = 'ventilation'
    );
    
    -- Rectangular Duct Area
    INSERT INTO public.calculations (name, description, formula, inputs, outputs, is_shared, type, user_id, project_id)
    SELECT 
        'Rectangular Duct Area', 
        'Calculate the area and equivalent diameter of a rectangular duct',
        'import math
height_m = inputs["height_mm"] / 1000
width_m = inputs["width_mm"] / 1000
outputs["area_m2"] = height_m * width_m
outputs["equivalent_diameter_mm"] = math.sqrt(height_m * width_m / math.pi) * 2000',
        ARRAY[
            '{"id":"height_mm","name":"Height","description":"Duct height","unit":"mm","type":"number","is_required":true}',
            '{"id":"width_mm","name":"Width","description":"Duct width","unit":"mm","type":"number","is_required":true}'
        ],
        ARRAY[
            '{"id":"area_m2","name":"Area","description":"Duct cross-sectional area","unit":"m²","type":"number","is_required":true}',
            '{"id":"equivalent_diameter_mm","name":"Equivalent Diameter","description":"Hydraulic diameter","unit":"mm","type":"number","is_required":true}'
        ],
        TRUE,
        'ventilation',
        admin_user_id,
        (SELECT id FROM projects WHERE user_id = admin_user_id LIMIT 1)
    WHERE NOT EXISTS (
        SELECT 1 FROM public.calculations WHERE name = 'Rectangular Duct Area' AND type = 'ventilation'
    );
    
    -- Round Duct Area
    INSERT INTO public.calculations (name, description, formula, inputs, outputs, is_shared, type, user_id, project_id)
    SELECT 
        'Round Duct Area', 
        'Calculate the area of a round duct',
        'import math
outputs["area_m2"] = math.pi * (inputs["diameter_mm"] / 2000) ** 2',
        ARRAY[
            '{"id":"diameter_mm","name":"Diameter","description":"Duct diameter","unit":"mm","type":"number","is_required":true}'
        ],
        ARRAY[
            '{"id":"area_m2","name":"Area","description":"Duct cross-sectional area","unit":"m²","type":"number","is_required":true}'
        ],
        TRUE,
        'ventilation',
        admin_user_id,
        (SELECT id FROM projects WHERE user_id = admin_user_id LIMIT 1)
    WHERE NOT EXISTS (
        SELECT 1 FROM public.calculations WHERE name = 'Round Duct Area' AND type = 'ventilation'
    );
    
    -- Minimum Duct Diameter
    INSERT INTO public.calculations (name, description, formula, inputs, outputs, is_shared, type, user_id, project_id)
    SELECT 
        'Minimum Duct Diameter', 
        'Find the minimum diameter for a round duct',
        'import math
required_area = inputs["air_volume"] / inputs["max_duct_velocity"]
outputs["min_diameter_mm"] = math.ceil(math.sqrt((4 * required_area) / math.pi) * 1000)',
        ARRAY[
            '{"id":"air_volume","name":"Air Volume","description":"Air volume flow rate","unit":"m³/s","type":"number","is_required":true}',
            '{"id":"max_duct_velocity","name":"Max Duct Velocity","description":"Maximum allowed air velocity","unit":"m/s","type":"number","is_required":true}'
        ],
        ARRAY[
            '{"id":"min_diameter_mm","name":"Minimum Diameter","description":"Minimum duct diameter","unit":"mm","type":"number","is_required":true}'
        ],
        TRUE,
        'ventilation',
        admin_user_id,
        (SELECT id FROM projects WHERE user_id = admin_user_id LIMIT 1)
    WHERE NOT EXISTS (
        SELECT 1 FROM public.calculations WHERE name = 'Minimum Duct Diameter' AND type = 'ventilation'
    );
END;
$$;


ALTER FUNCTION "public"."seed_ventilation_calculations"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_admin_status"("user_id" "uuid", "admin_status" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Update the user's metadata to include admin status
  UPDATE auth.users 
  SET user_metadata = COALESCE(user_metadata, '{}'::jsonb) || 
                     jsonb_build_object('is_admin', admin_status)
  WHERE id = user_id;
END;
$$;


ALTER FUNCTION "public"."set_admin_status"("user_id" "uuid", "admin_status" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_super_admin_status"("user_id" "uuid", "super_admin_status" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Update the user's is_super_admin column
  UPDATE auth.users 
  SET is_super_admin = super_admin_status
  WHERE id = user_id;
END;
$$;


ALTER FUNCTION "public"."set_super_admin_status"("user_id" "uuid", "super_admin_status" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_user_monthly_limit"("user_uuid" "uuid", "new_limit" integer) RETURNS "public"."user_calculation_limits"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    limit_record user_calculation_limits;
    current_month text;
BEGIN
    -- Check if caller is super admin
    IF NOT is_super_admin(auth.uid()) THEN
        RAISE EXCEPTION 'Only super admins can modify calculation limits';
    END IF;
    
    -- Get current month
    current_month := to_char(now(), 'YYYY-MM');
    
    -- Update or insert the limit record
    INSERT INTO user_calculation_limits (user_id, month_year, calculation_count, monthly_limit)
    VALUES (user_uuid, current_month, 0, new_limit)
    ON CONFLICT (user_id, month_year) 
    DO UPDATE SET monthly_limit = new_limit
    RETURNING * INTO limit_record;
    
    RETURN limit_record;
END;
$$;


ALTER FUNCTION "public"."set_user_monthly_limit"("user_uuid" "uuid", "new_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_set_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_set_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_calculation_metadata_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_calculation_metadata_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_feedback_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_feedback_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_project_constraints_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_project_constraints_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."calculation_flows" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "nodes" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "edges" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "project_id" "uuid",
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "folder_id" "uuid"
);


ALTER TABLE "public"."calculation_flows" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."calculation_metadata" (
    "calc_id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text" NOT NULL,
    "latex" "text" DEFAULT ''::"text",
    "diagram_path" "text",
    "tags" "text"[] DEFAULT '{}'::"text"[],
    "input_schema" "jsonb" NOT NULL,
    "output_schema" "jsonb" NOT NULL,
    "references" "text"[] DEFAULT '{}'::"text"[],
    "related_calcs" "text"[],
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "uuid" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "category" "text" DEFAULT 'Other'::"text",
    "subcategory" "text",
    "guidance" "text" DEFAULT '''{}''::text[]'::"text",
    "checked" boolean DEFAULT false NOT NULL,
    "input_schema_old" "jsonb",
    "output_schema_old" "jsonb",
    "input_schema_new" "jsonb",
    "output_schema_new" "jsonb"
);


ALTER TABLE "public"."calculation_metadata" OWNER TO "postgres";


COMMENT ON TABLE "public"."calculation_metadata" IS 'Calculation metadata table - updated with new schema format for enhanced unit handling';



COMMENT ON COLUMN "public"."calculation_metadata"."input_schema" IS 'Input parameter definitions with symbol field for mathematical notation';



COMMENT ON COLUMN "public"."calculation_metadata"."output_schema" IS 'Output parameter definitions with symbol field for mathematical notation';



COMMENT ON COLUMN "public"."calculation_metadata"."checked" IS 'Boolean flag indicating if the calculation has been checked/reviewed';



COMMENT ON COLUMN "public"."calculation_metadata"."input_schema_old" IS 'Backup of original input_schema format';



COMMENT ON COLUMN "public"."calculation_metadata"."output_schema_old" IS 'Backup of original output_schema format';



COMMENT ON COLUMN "public"."calculation_metadata"."input_schema_new" IS 'New input_schema format with enhanced unit handling (dimension, metric, imperial)';



COMMENT ON COLUMN "public"."calculation_metadata"."output_schema_new" IS 'New output_schema format with enhanced unit handling (dimension, metric, imperial)';



CREATE TABLE IF NOT EXISTS "public"."calculation_results" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "result_description" "text",
    "project_id" "uuid" NOT NULL,
    "folder_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "inputs" "jsonb" NOT NULL,
    "outputs" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "calculation_metadata_id" "uuid"
);


ALTER TABLE "public"."calculation_results" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."feedback" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "category" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text" NOT NULL,
    "priority" "text" NOT NULL,
    "email" "text",
    "status" "text" DEFAULT 'open'::"text",
    "admin_notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "feedback_category_check" CHECK (("category" = ANY (ARRAY['bug'::"text", 'suggestion'::"text", 'calculation'::"text"]))),
    CONSTRAINT "feedback_priority_check" CHECK (("priority" = ANY (ARRAY['low'::"text", 'medium'::"text", 'high'::"text"]))),
    CONSTRAINT "feedback_status_check" CHECK (("status" = ANY (ARRAY['open'::"text", 'in_progress'::"text", 'resolved'::"text", 'closed'::"text"])))
);


ALTER TABLE "public"."feedback" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."folder_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "folders" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "user_id" "uuid",
    "is_default" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."folder_templates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."folders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "project_id" "uuid" NOT NULL,
    "parent_folder_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."folders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."project_constraints" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "value" numeric NOT NULL,
    "unit" "text" NOT NULL,
    "project_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."project_constraints" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."projects" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "project_number" "text",
    "client" "text",
    "start_date" "date",
    "end_date" "date",
    "is_favorite" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."projects" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_calculation_favorites" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "calculation_id" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_calculation_favorites" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_calculation_favorites" IS 'User-specific calculation favorites - allows each user to favorite calculations independently';



COMMENT ON COLUMN "public"."user_calculation_favorites"."calculation_id" IS 'References calculation_metadata.calc_id (string identifier)';



ALTER TABLE ONLY "public"."calculation_flows"
    ADD CONSTRAINT "calculation_flows_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."calculation_metadata"
    ADD CONSTRAINT "calculation_metadata_calc_id_unique" UNIQUE ("calc_id");



ALTER TABLE ONLY "public"."calculation_metadata"
    ADD CONSTRAINT "calculation_metadata_pkey" PRIMARY KEY ("uuid");



ALTER TABLE ONLY "public"."calculation_metadata"
    ADD CONSTRAINT "calculation_metadata_uuid_unique" UNIQUE ("uuid");



ALTER TABLE ONLY "public"."calculation_results"
    ADD CONSTRAINT "calculation_results_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."feedback"
    ADD CONSTRAINT "feedback_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."folder_templates"
    ADD CONSTRAINT "folder_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."folders"
    ADD CONSTRAINT "folders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."project_constraints"
    ADD CONSTRAINT "project_constraints_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."projects"
    ADD CONSTRAINT "projects_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_calculation_favorites"
    ADD CONSTRAINT "user_calculation_favorites_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_calculation_favorites"
    ADD CONSTRAINT "user_calculation_favorites_user_id_calculation_id_key" UNIQUE ("user_id", "calculation_id");



ALTER TABLE ONLY "public"."user_calculation_limits"
    ADD CONSTRAINT "user_calculation_limits_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_calculation_limits"
    ADD CONSTRAINT "user_calculation_limits_user_id_month_year_key" UNIQUE ("user_id", "month_year");



CREATE INDEX "idx_calculation_flows_created_at" ON "public"."calculation_flows" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_calculation_flows_edges_gin" ON "public"."calculation_flows" USING "gin" ("edges");



CREATE INDEX "idx_calculation_flows_folder_id" ON "public"."calculation_flows" USING "btree" ("folder_id");



CREATE INDEX "idx_calculation_flows_nodes_gin" ON "public"."calculation_flows" USING "gin" ("nodes");



CREATE INDEX "idx_calculation_flows_project_id" ON "public"."calculation_flows" USING "btree" ("project_id");



CREATE INDEX "idx_calculation_flows_updated_at" ON "public"."calculation_flows" USING "btree" ("updated_at" DESC);



CREATE INDEX "idx_calculation_flows_user_id" ON "public"."calculation_flows" USING "btree" ("user_id");



CREATE INDEX "idx_calculation_metadata_category" ON "public"."calculation_metadata" USING "btree" ("category");



CREATE INDEX "idx_calculation_metadata_checked" ON "public"."calculation_metadata" USING "btree" ("checked");



CREATE INDEX "idx_calculation_metadata_created_at" ON "public"."calculation_metadata" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_calculation_metadata_input_schema_gin" ON "public"."calculation_metadata" USING "gin" ("input_schema");



CREATE INDEX "idx_calculation_metadata_output_schema_gin" ON "public"."calculation_metadata" USING "gin" ("output_schema");



CREATE INDEX "idx_calculation_metadata_subcategory" ON "public"."calculation_metadata" USING "btree" ("subcategory");



CREATE INDEX "idx_calculation_metadata_tags" ON "public"."calculation_metadata" USING "gin" ("tags");



CREATE INDEX "idx_calculation_metadata_updated_at" ON "public"."calculation_metadata" USING "btree" ("updated_at" DESC);



CREATE INDEX "idx_calculation_metadata_uuid" ON "public"."calculation_metadata" USING "btree" ("uuid");



CREATE INDEX "idx_calculation_results_calculation_id" ON "public"."calculation_results" USING "btree" ("result_description");



CREATE INDEX "idx_calculation_results_folder_id" ON "public"."calculation_results" USING "btree" ("folder_id");



CREATE INDEX "idx_calculation_results_metadata_id" ON "public"."calculation_results" USING "btree" ("calculation_metadata_id");



CREATE INDEX "idx_calculation_results_project_id" ON "public"."calculation_results" USING "btree" ("project_id");



CREATE INDEX "idx_calculation_results_user_id" ON "public"."calculation_results" USING "btree" ("user_id");



CREATE INDEX "idx_feedback_category" ON "public"."feedback" USING "btree" ("category");



CREATE INDEX "idx_feedback_created_at" ON "public"."feedback" USING "btree" ("created_at");



CREATE INDEX "idx_feedback_status" ON "public"."feedback" USING "btree" ("status");



CREATE INDEX "idx_feedback_user_id" ON "public"."feedback" USING "btree" ("user_id");



CREATE INDEX "idx_folder_templates_created_at" ON "public"."folder_templates" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_folder_templates_is_default" ON "public"."folder_templates" USING "btree" ("is_default");



CREATE INDEX "idx_folder_templates_updated_at" ON "public"."folder_templates" USING "btree" ("updated_at" DESC);



CREATE INDEX "idx_folder_templates_user_id" ON "public"."folder_templates" USING "btree" ("user_id");



CREATE INDEX "idx_project_constraints_created_at" ON "public"."project_constraints" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_project_constraints_project_id" ON "public"."project_constraints" USING "btree" ("project_id");



CREATE INDEX "idx_project_constraints_updated_at" ON "public"."project_constraints" USING "btree" ("updated_at" DESC);



CREATE INDEX "idx_project_constraints_user_id" ON "public"."project_constraints" USING "btree" ("user_id");



CREATE INDEX "idx_projects_favorites_updated" ON "public"."projects" USING "btree" ("is_favorite" DESC, "updated_at" DESC);



CREATE INDEX "idx_projects_is_favorite" ON "public"."projects" USING "btree" ("is_favorite");



CREATE INDEX "idx_user_calculation_favorites_calculation_id" ON "public"."user_calculation_favorites" USING "btree" ("calculation_id");



CREATE INDEX "idx_user_calculation_favorites_created_at" ON "public"."user_calculation_favorites" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_user_calculation_favorites_user_id" ON "public"."user_calculation_favorites" USING "btree" ("user_id");



CREATE INDEX "idx_user_calculation_limits_month_year" ON "public"."user_calculation_limits" USING "btree" ("month_year");



CREATE INDEX "idx_user_calculation_limits_user_id" ON "public"."user_calculation_limits" USING "btree" ("user_id");



CREATE INDEX "idx_user_calculation_limits_user_month" ON "public"."user_calculation_limits" USING "btree" ("user_id", "month_year");



CREATE OR REPLACE TRIGGER "set_timestamp" BEFORE UPDATE ON "public"."calculation_flows" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_set_timestamp"();



CREATE OR REPLACE TRIGGER "set_timestamp" BEFORE UPDATE ON "public"."folders" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_set_timestamp"();



CREATE OR REPLACE TRIGGER "set_timestamp" BEFORE UPDATE ON "public"."projects" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_set_timestamp"();



CREATE OR REPLACE TRIGGER "update_calculation_flows_updated_at" BEFORE UPDATE ON "public"."calculation_flows" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_calculation_metadata_updated_at" BEFORE UPDATE ON "public"."calculation_metadata" FOR EACH ROW EXECUTE FUNCTION "public"."update_calculation_metadata_updated_at"();



CREATE OR REPLACE TRIGGER "update_feedback_updated_at" BEFORE UPDATE ON "public"."feedback" FOR EACH ROW EXECUTE FUNCTION "public"."update_feedback_updated_at"();



CREATE OR REPLACE TRIGGER "update_folder_templates_updated_at" BEFORE UPDATE ON "public"."folder_templates" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_project_constraints_updated_at" BEFORE UPDATE ON "public"."project_constraints" FOR EACH ROW EXECUTE FUNCTION "public"."update_project_constraints_updated_at"();



CREATE OR REPLACE TRIGGER "update_user_calculation_favorites_updated_at" BEFORE UPDATE ON "public"."user_calculation_favorites" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_user_calculation_limits_updated_at" BEFORE UPDATE ON "public"."user_calculation_limits" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."calculation_flows"
    ADD CONSTRAINT "calculation_flows_folder_id_fkey" FOREIGN KEY ("folder_id") REFERENCES "public"."folders"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."calculation_flows"
    ADD CONSTRAINT "calculation_flows_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."calculation_flows"
    ADD CONSTRAINT "calculation_flows_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."calculation_results"
    ADD CONSTRAINT "calculation_results_folder_id_fkey" FOREIGN KEY ("folder_id") REFERENCES "public"."folders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."calculation_results"
    ADD CONSTRAINT "calculation_results_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."calculation_results"
    ADD CONSTRAINT "calculation_results_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feedback"
    ADD CONSTRAINT "feedback_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."calculation_results"
    ADD CONSTRAINT "fk_calculation_results_metadata_id" FOREIGN KEY ("calculation_metadata_id") REFERENCES "public"."calculation_metadata"("uuid") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."folder_templates"
    ADD CONSTRAINT "folder_templates_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."folders"
    ADD CONSTRAINT "folders_parent_folder_id_fkey" FOREIGN KEY ("parent_folder_id") REFERENCES "public"."folders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."folders"
    ADD CONSTRAINT "folders_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."project_constraints"
    ADD CONSTRAINT "project_constraints_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."project_constraints"
    ADD CONSTRAINT "project_constraints_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projects"
    ADD CONSTRAINT "projects_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_calculation_favorites"
    ADD CONSTRAINT "user_calculation_favorites_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_calculation_limits"
    ADD CONSTRAINT "user_calculation_limits_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Admins can insert feedback" ON "public"."feedback" FOR INSERT WITH CHECK ((((("auth"."jwt"() ->> 'user_metadata'::"text"))::"jsonb" ->> 'role'::"text") = 'admin'::"text"));



CREATE POLICY "Admins can manage all folder templates" ON "public"."folder_templates" USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "Admins can modify calculation metadata" ON "public"."calculation_metadata" USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "Admins can update all feedback" ON "public"."feedback" FOR UPDATE USING ((((("auth"."jwt"() ->> 'user_metadata'::"text"))::"jsonb" ->> 'role'::"text") = 'admin'::"text"));



CREATE POLICY "Admins can view all calculation flows" ON "public"."calculation_flows" FOR SELECT USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "Admins can view all calculation results" ON "public"."calculation_results" FOR SELECT USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "Admins can view all feedback" ON "public"."feedback" FOR SELECT USING ((((("auth"."jwt"() ->> 'user_metadata'::"text"))::"jsonb" ->> 'role'::"text") = 'admin'::"text"));



CREATE POLICY "Admins can view all folders" ON "public"."folders" FOR SELECT USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "Admins can view all projects" ON "public"."projects" FOR SELECT USING ("public"."is_admin"("auth"."uid"()));



CREATE POLICY "Anyone can view calculation metadata" ON "public"."calculation_metadata" FOR SELECT USING (true);



CREATE POLICY "Authenticated users can create calculation metadata" ON "public"."calculation_metadata" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Authenticated users can update calculation metadata" ON "public"."calculation_metadata" FOR UPDATE USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Super admins can manage all folder templates" ON "public"."folder_templates" USING ("public"."is_super_admin"("auth"."uid"()));



CREATE POLICY "Super admins can manage all folders" ON "public"."folders" USING ("public"."is_super_admin"("auth"."uid"()));



CREATE POLICY "Super admins can perform all operations on calculation metadata" ON "public"."calculation_metadata" USING ("public"."is_super_admin"("auth"."uid"()));



CREATE POLICY "Super admins can update all calculation limits" ON "public"."user_calculation_limits" FOR UPDATE USING ("public"."is_super_admin"("auth"."uid"()));



CREATE POLICY "Super admins can update checked field" ON "public"."calculation_metadata" FOR UPDATE USING ((("auth"."role"() = 'authenticated'::"text") AND "public"."is_super_admin"("auth"."uid"()))) WITH CHECK ((("auth"."role"() = 'authenticated'::"text") AND "public"."is_super_admin"("auth"."uid"())));



CREATE POLICY "Super admins can view all calculation flows" ON "public"."calculation_flows" FOR SELECT USING ("public"."is_super_admin"("auth"."uid"()));



CREATE POLICY "Super admins can view all calculation limits" ON "public"."user_calculation_limits" FOR SELECT USING ("public"."is_super_admin"("auth"."uid"()));



CREATE POLICY "Super admins can view all calculation results" ON "public"."calculation_results" FOR SELECT USING ("public"."is_super_admin"("auth"."uid"()));



CREATE POLICY "Super admins can view all folders" ON "public"."folders" FOR SELECT USING ("public"."is_super_admin"("auth"."uid"()));



CREATE POLICY "Super admins can view all projects" ON "public"."projects" FOR SELECT USING ("public"."is_super_admin"("auth"."uid"()));



CREATE POLICY "System can insert calculation limits" ON "public"."user_calculation_limits" FOR INSERT WITH CHECK (true);



CREATE POLICY "Users can create constraints for their projects" ON "public"."project_constraints" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can create folders in their projects" ON "public"."folders" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."projects"
  WHERE (("projects"."id" = "folders"."project_id") AND ("projects"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can create their own calculation flows" ON "public"."calculation_flows" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can create their own calculation results" ON "public"."calculation_results" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can create their own folder templates" ON "public"."folder_templates" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can create their own projects" ON "public"."projects" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete constraints for their projects" ON "public"."project_constraints" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete folders in their projects" ON "public"."folders" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."projects"
  WHERE (("projects"."id" = "folders"."project_id") AND ("projects"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can delete their own calculation favorites" ON "public"."user_calculation_favorites" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete their own calculation flows" ON "public"."calculation_flows" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete their own calculation results" ON "public"."calculation_results" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete their own folder templates" ON "public"."folder_templates" FOR DELETE USING ((("auth"."uid"() = "user_id") AND ("is_default" = false)));



CREATE POLICY "Users can delete their own projects" ON "public"."projects" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own feedback" ON "public"."feedback" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert their own calculation favorites" ON "public"."user_calculation_favorites" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update constraints for their projects" ON "public"."project_constraints" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update folders in their projects" ON "public"."folders" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."projects"
  WHERE (("projects"."id" = "folders"."project_id") AND ("projects"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can update own open feedback" ON "public"."feedback" FOR UPDATE USING ((("auth"."uid"() = "user_id") AND ("status" = 'open'::"text")));



CREATE POLICY "Users can update their own calculation flows" ON "public"."calculation_flows" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update their own calculation limits" ON "public"."user_calculation_limits" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update their own calculation results" ON "public"."calculation_results" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update their own folder templates" ON "public"."folder_templates" FOR UPDATE USING ((("auth"."uid"() = "user_id") AND ("is_default" = false)));



CREATE POLICY "Users can update their own projects" ON "public"."projects" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view constraints for their projects" ON "public"."project_constraints" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view folders in their projects" ON "public"."folders" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."projects"
  WHERE (("projects"."id" = "folders"."project_id") AND ("projects"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can view folders of their projects" ON "public"."folders" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."projects"
  WHERE (("projects"."id" = "folders"."project_id") AND ("projects"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can view own feedback" ON "public"."feedback" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view projects with valid session" ON "public"."projects" FOR SELECT USING (((("auth"."uid"() IS NOT NULL) AND ("user_id" = "auth"."uid"())) OR ("auth"."role"() = 'authenticated'::"text")));



CREATE POLICY "Users can view their own calculation favorites" ON "public"."user_calculation_favorites" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their own calculation flows" ON "public"."calculation_flows" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their own calculation limits" ON "public"."user_calculation_limits" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their own calculation results" ON "public"."calculation_results" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their own folder templates" ON "public"."folder_templates" FOR SELECT USING ((("auth"."uid"() = "user_id") OR ("is_default" = true)));



CREATE POLICY "Users can view their own projects" ON "public"."projects" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."calculation_flows" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."calculation_metadata" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."calculation_results" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."feedback" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."folder_templates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."folders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."project_constraints" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."projects" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_calculation_favorites" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_calculation_limits" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";




















































































































































































GRANT ALL ON FUNCTION "public"."can_user_run_calculation"("user_uuid" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_user_run_calculation"("user_uuid" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_user_run_calculation"("user_uuid" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."convert_param_to_new_format"("old_param" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."convert_param_to_new_format"("old_param" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."convert_param_to_new_format"("old_param" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."convert_schema_to_new_format"("old_schema" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."convert_schema_to_new_format"("old_schema" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."convert_schema_to_new_format"("old_schema" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."fix_param_schema_dimension"("param_schema" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."fix_param_schema_dimension"("param_schema" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fix_param_schema_dimension"("param_schema" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."fix_schema_dimensions"("schema_obj" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."fix_schema_dimensions"("schema_obj" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fix_schema_dimensions"("schema_obj" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."fix_units_dimension"("units_obj" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."fix_units_dimension"("units_obj" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fix_units_dimension"("units_obj" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_admin_users"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_admin_users"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_admin_users"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_dimension_from_unit"("unit" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_dimension_from_unit"("unit" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_dimension_from_unit"("unit" "text") TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_calculation_limits" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_calculation_limits" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_calculation_limits" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_or_create_user_calculation_limit"("user_uuid" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_or_create_user_calculation_limit"("user_uuid" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_or_create_user_calculation_limit"("user_uuid" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_super_admin_users"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_super_admin_users"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_super_admin_users"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_calculation_usage_history"("user_uuid" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_calculation_usage_history"("user_uuid" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_calculation_usage_history"("user_uuid" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_user_calculation_count"("user_uuid" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."increment_user_calculation_count"("user_uuid" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_user_calculation_count"("user_uuid" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_admin"("user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_admin"("user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_admin"("user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_super_admin"("user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_super_admin"("user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_super_admin"("user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."reset_user_calculation_count"("user_uuid" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."reset_user_calculation_count"("user_uuid" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."reset_user_calculation_count"("user_uuid" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."seed_ventilation_calculations"() TO "anon";
GRANT ALL ON FUNCTION "public"."seed_ventilation_calculations"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."seed_ventilation_calculations"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_admin_status"("user_id" "uuid", "admin_status" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."set_admin_status"("user_id" "uuid", "admin_status" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_admin_status"("user_id" "uuid", "admin_status" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_super_admin_status"("user_id" "uuid", "super_admin_status" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."set_super_admin_status"("user_id" "uuid", "super_admin_status" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_super_admin_status"("user_id" "uuid", "super_admin_status" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_user_monthly_limit"("user_uuid" "uuid", "new_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."set_user_monthly_limit"("user_uuid" "uuid", "new_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_user_monthly_limit"("user_uuid" "uuid", "new_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_set_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_set_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_set_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_calculation_metadata_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_calculation_metadata_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_calculation_metadata_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_feedback_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_feedback_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_feedback_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_project_constraints_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_project_constraints_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_project_constraints_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";


















GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."calculation_flows" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."calculation_flows" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."calculation_flows" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."calculation_metadata" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."calculation_metadata" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."calculation_metadata" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."calculation_results" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."calculation_results" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."calculation_results" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."feedback" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."feedback" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."feedback" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."folder_templates" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."folder_templates" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."folder_templates" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."folders" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."folders" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."folders" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."project_constraints" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."project_constraints" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."project_constraints" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projects" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projects" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."projects" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_calculation_favorites" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_calculation_favorites" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_calculation_favorites" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "service_role";































RESET ALL;
