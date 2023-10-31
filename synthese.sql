
-- Vue générique pour alimenter la synthèse dans le cadre d'un protocole site-visite-observation
-- 
-- Ce fichier peut être copié dans le dossier du sous-module et renommé en synthese.sql (et au besoin personnalisé)
-- le fichier sera joué à l'installation avec la valeur de module_code qui sera attribué automatiquement
--
--
-- Personalisations possibles
--
--  - ajouter des champs specifiques qui peuvent alimenter la synthese
--      jointure avec les table de complement
--
--  - choisir les valeurs de champs de nomenclatures qui seront propres au modules


-- ce fichier contient une variable :module_code (ou :'module_code')
-- utiliser psql avec l'option -v module_code=<module_code

-- ne pas remplacer cette variable, elle est indispensable pour les scripts d'installations
-- le module pouvant être installé avec un code différent de l'original

DROP VIEW IF EXISTS gn_monitoring.v_synthese_:module_code;
CREATE VIEW gn_monitoring.v_synthese_:module_code AS

WITH source AS (

	SELECT

        id_source

    FROM gn_synthese.t_sources
	WHERE name_source = CONCAT('MONITORING_GN_MODULE_MONITORING_', UPPER(:'module_code'))
	LIMIT 1

),
sites AS (
    SELECT
        s.id_base_site,
        s.base_site_code,
        geom AS the_geom_4326,
	    ST_CENTROID(geom) AS the_geom_point,
	    geom_local as geom_local,
	    altitude_min,
	    altitude_max,
	    c."data",
	    s_1.meta_update_date
        FROM gn_monitoring.t_base_sites s
        LEFT JOIN gn_monitoring.t_site_complements c USING (id_base_site)
), visits AS (
	SELECT
		v.id_base_visit,
		uuid_base_visit,
		id_module,
		id_base_site,
		id_dataset,
		id_digitiser,
		visit_date_min AS date_min,
		COALESCE (visit_date_max, visit_date_min) AS date_max,
		comments,
		id_nomenclature_tech_collect_campanule AS id_nomenclature_obs_technique,
		id_nomenclature_grp_typ,
		c."data",
		meta_update_date
	FROM gn_monitoring.t_base_visits v
	LEFT JOIN gn_monitoring.t_visit_complements c USING (id_base_visit)
),
observers AS (
	SELECT
		array_agg(r.id_role) AS ids_observers,
		STRING_AGG(CONCAT(r.nom_role, ' ', prenom_role), ', ') AS observers,
		id_base_visit
	FROM gn_monitoring.cor_visit_observer cvo
	JOIN utilisateurs.t_roles r ON r.id_role = cvo.id_role
	GROUP BY id_base_visit
)
SELECT
	o.uuid_observation AS unique_id_sinp,
	v.uuid_base_visit AS unique_id_sinp_grp,
	src.id_source,
	v.id_module,
	o.id_observation AS entity_source_pk_value,
	v.id_dataset,
    ref_nomenclatures.get_id_nomenclature('NAT_OBJ_GEO', 'St') AS id_nomenclature_geo_object_nature,
    v.id_nomenclature_grp_typ,
    -- grp_method,
	ref_nomenclatures.get_id_nomenclature('METH_OBS', '0') AS id_nomenclature_obs_technique, -- Vu
	CASE
		WHEN (oc."data" ->> 'id_nomenclature_bio_status'::text)::integer IS NOT NULL THEN (oc."data" ->> 'id_nomenclature_bio_status'::text)::integer
		WHEN ref_nomenclatures.get_cd_nomenclature((oc."data" ->> 'chiro_activity')::integer) IN ('Accouplement', 'Swarming') THEN ref_nomenclatures.get_id_nomenclature('STATUT_BIO', '3') -- Reproduction
		WHEN ref_nomenclatures.get_cd_nomenclature((oc."data" ->> 'chiro_activity')::integer) IN ('Hibernation') THEN ref_nomenclatures.get_id_nomenclature('STATUT_BIO', '4') -- Hibernation
				WHEN ref_nomenclatures.get_cd_nomenclature((oc."data" ->> 'chiro_activity')::integer) IN ('Estivage', 'Maternité', 'Maternité ?') THEN ref_nomenclatures.get_id_nomenclature('STATUT_BIO', '5') -- Estivation
		ELSE ref_nomenclatures.get_id_nomenclature('STATUT_BIO', '9') -- Pas de reproduction (transit, ...)
	END AS id_nomenclature_bio_status,
	--	gn_synthese.get_default_nomenclature_value('ETA_BIO'::character varying) AS id_nomenclature_bio_condition,
	--	gn_synthese.get_default_nomenclature_value('NATURALITE'::character varying) AS id_nomenclature_naturalness,
	--	gn_synthese.get_default_nomenclature_value('PREUVE_EXIST'::character varying) AS id_nomenclature_exist_proof,
	--  id_nomenclature_valid_status,  --STATUT_VALID
	--id_nomenclature_diffusion_level, -- NIV_PRECIS
	COALESCE((oc."data" ->> 'id_nomenclature_life_stage'::text)::integer, gn_synthese.get_default_nomenclature_value('STADE_VIE'::character varying)) AS id_nomenclature_life_stage,
	--id_nomenclature_sex, -- SEXE
	ref_nomenclatures.get_id_nomenclature('OBJ_DENBR', 'IND') AS id_nomenclature_obj_count,
	ref_nomenclatures.get_id_nomenclature('TYP_DENBR', 'Es') AS id_nomenclature_type_count,
	-- id_nomenclature_sensitivity, --SENSIBILITE : À la maille 10km, code 2
	  COALESCE((oc."data" ->> 'id_nomenclature_observation_status'::text)::integer, gn_synthese.get_default_nomenclature_value('STATUT_OBS'::character varying)) AS id_nomenclature_observation_status,
	-- id_nomenclature_blurring, -- DEE_FLOU
	ref_nomenclatures.get_id_nomenclature('STATUT_SOURCE', 'Te') AS id_nomenclature_source_status,
	ref_nomenclatures.get_id_nomenclature('TYP_INF_GEO', '1') AS id_nomenclature_info_geo_type,
    -- id_nomenclature_behaviour, -- OCC_COMPORTEMENT
	-- id_nomenclature_biogeo_status,
	-- reference_biblio
	(oc."data" ->> 'count'::text)::integer AS count_min,
    (oc."data" ->> 'count'::text)::integer AS count_max,
	o.cd_nom,
	-- cd_hab,
	t.lb_nom AS nom_cite,
	--meta_v_taxref,
	--sample_number_proof,
	--digital_proof,
	--non_digital_proof,
	s.altitude_min,
	s.altitude_max,
	-- depth_min,
	-- depth_max,
	s.base_site_code AS place_name,
	s.the_geom_4326,
	s.the_geom_point,
	s.geom_local as the_geom_local,
	5 AS precision, -- 5 mètres (précision GPS)
	-- id_area_attachment
	v.date_min,
	v.date_max,
	--validator
	--validation_comment
	obs.observers,
	--determiner
	v.id_digitiser,
	--id_nomenclature_determination_method
	v.comments AS comment_context,
	o.comments AS comment_description,
	oc."data" AS additional_data
	--meta_validation_date
	--meta_create_date,
	--meta_update_date,
	--last_action
    	greatest(v.meta_update_date, s.meta_update_date) AS meta_update_date
FROM gn_monitoring.t_observations o
LEFT JOIN gn_monitoring.t_observation_complements oc USING (id_observation)
JOIN visits v ON v.id_base_visit = o.id_base_visit
JOIN sites s ON s.id_base_site = v.id_base_site
JOIN gn_commons.t_modules m ON m.id_module = v.id_module
JOIN taxonomie.taxref t ON t.cd_nom = o.cd_nom
JOIN src ON TRUE
JOIN observers obs ON obs.id_base_visit = v.id_base_visit
WHERE m.module_code = :'module_code';

SELECT * FROM gn_monitoring.v_synthese_:module_code
