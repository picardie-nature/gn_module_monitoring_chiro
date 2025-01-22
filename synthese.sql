
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
CREATE OR REPLACE VIEW gn_monitoring.v_synthese_:module_code; AS
WITH src AS (
    SELECT t_sources.id_source
    FROM gn_synthese.t_sources
    WHERE t_sources.name_source = concat('MONITORING_GN_MODULE_MONITORING_', upper(':module_code;'))
    LIMIT 1
),
sites AS (
     SELECT s_1.id_base_site,
        s_1.base_site_code,
        s_1.geom AS the_geom_4326,
        st_centroid(s_1.geom) AS the_geom_point,
        s_1.geom_local,
        s_1.altitude_min,
        s_1.altitude_max,
        c.data,
        s_1.meta_update_date
    FROM gn_monitoring.t_base_sites s_1
    LEFT JOIN gn_monitoring.t_site_complements c USING (id_base_site)
),
visits AS (
    SELECT
        v_1.id_base_visit,
        v_1.uuid_base_visit,
        v_1.id_module,
        v_1.id_base_site,
        v_1.id_dataset,
        v_1.id_digitiser,
        v_1.visit_date_min AS date_min,
        COALESCE(v_1.visit_date_max, v_1.visit_date_min) AS date_max,
        v_1.comments,
        v_1.id_nomenclature_tech_collect_campanule AS id_nomenclature_obs_technique,
        v_1.id_nomenclature_grp_typ,
        c.data,
        v_1.meta_update_date
    FROM gn_monitoring.t_base_visits v_1
    LEFT JOIN gn_monitoring.t_visit_complements c USING (id_base_visit)
),
observers AS (
    SELECT
        array_agg(r.id_role) AS ids_observers,
        string_agg(concat(r.nom_role, ' ', r.prenom_role), ', ') AS observers,
        cvo.id_base_visit
    FROM gn_monitoring.cor_visit_observer cvo
    JOIN utilisateurs.t_roles r ON r.id_role = cvo.id_role
    GROUP BY cvo.id_base_visit
)
SELECT
    -- UUIDs de l'observation / du relevé
    o.uuid_observation AS unique_id_sinp,
    v.uuid_base_visit AS unique_id_sinp_grp,
    -- Source
    src.id_source,
    v.id_module,
    -- Métadonnées
    o.id_observation AS entity_source_pk_value,
    v.id_dataset,
    -- Nature d'objet géographique = 'Stationnel'
    ref_nomenclatures.get_id_nomenclature('NAT_OBJ_GEO', 'St') AS id_nomenclature_geo_object_nature,
    -- Type de regroupement (de la visite) = Passage
    v.id_nomenclature_grp_typ,
    -- Méthode d'observation = Vu
--    ref_nomenclatures.get_id_nomenclature('METH_OBS', '0') AS id_nomenclature_obs_technique,
    -- Traduction Activité chiro -> Statut biologique
    case
	    -- Statut bio renseigné
        WHEN ((oc.data ->> 'id_nomenclature_bio_status')) IS NOT NULL THEN (oc.data ->> 'id_nomenclature_bio_status')::integer
        -- Reproduction
        WHEN ref_nomenclatures.get_cd_nomenclature((oc.data ->> 'chiro_activity')::integer) = ANY (ARRAY['Accouplement', 'Swarming', 'Maternité', 'Maternité ?']) THEN ref_nomenclatures.get_id_nomenclature('STATUT_BIO', '3')
        -- Hibernation
        WHEN ref_nomenclatures.get_cd_nomenclature((oc.data ->> 'chiro_activity')::integer) = 'Hibernation' THEN ref_nomenclatures.get_id_nomenclature('STATUT_BIO', '4')
        -- Estivage
        WHEN ref_nomenclatures.get_cd_nomenclature((oc.data ->> 'chiro_activity')::integer) = 'Estivage' THEN ref_nomenclatures.get_id_nomenclature('STATUT_BIO', '5')
        -- Autres cas : Non renseigné
        ELSE ref_nomenclatures.get_id_nomenclature('STATUT_BIO', '1')
    END AS id_nomenclature_bio_status,
    -- Méthode d'observation : déduite du type de visite
    CASE
        -- Prospection / Capture = Vu
        WHEN ref_nomenclatures.get_cd_nomenclature((v.data ->> 'visit_type')::integer) = any(array['Prospection', 'Capture']) THEN ref_nomenclatures.get_id_nomenclature('METH_OBS', '0')
        -- Non renseigné / null = Inconnu (Vu aussi ?)
        ELSE ref_nomenclatures.get_id_nomenclature('METH_OBS', '21')
    END as id_nomenclature_obs_technique,
    -- Technique d'observation (CAMPANULE) : déduite du type de visite
    -- ATTENTION ne sera pas reprise dans la synthèse
    CASE
        -- Prospection = Prospection active dans l'habitat naturel
        WHEN ref_nomenclatures.get_cd_nomenclature((v.data ->> 'visit_type')::integer) = 'Prospection' THEN ref_nomenclatures.get_id_nomenclature('TECHNIQUE_OBS', '131')
        -- Capture = Capture au filet japonais
        WHEN ref_nomenclatures.get_cd_nomenclature((v.data ->> 'visit_type')::integer) = 'Capture' THEN ref_nomenclatures.get_id_nomenclature('TECHNIQUE_OBS', '11')
        -- Non renseigné
        ELSE ref_nomenclatures.get_id_nomenclature('TECHNIQUE_OBS', '133')
	end as id_nomenclature_tech_collecte_campanule,
    -- Méthode de détermination : déduite du type de visite
    CASE
        -- Prospection = Examen visuel à distance
        WHEN ref_nomenclatures.get_cd_nomenclature((v.data ->> 'visit_type')::integer) = 'Prospection' THEN ref_nomenclatures.get_id_nomenclature('METH_DETERMIN', '18')
        -- Capture = Examen biométrique
        WHEN ref_nomenclatures.get_cd_nomenclature((v.data ->> 'visit_type')::integer) = 'Capture' THEN ref_nomenclatures.get_id_nomenclature('METH_DETERMIN', '8')
        -- Non renseigné
        ELSE ref_nomenclatures.get_id_nomenclature('METH_DETERMIN', '1')
    end as id_nomenclature_determination_method,
    -- Stade de vie (Inconnu par défaut)
    COALESCE(
        (oc.data ->> 'id_nomenclature_life_stage')::integer,
        gn_synthese.get_default_nomenclature_value('STADE_VIE')
    ) AS id_nomenclature_life_stage,
    -- Objet dénombremenbt = Individus
    ref_nomenclatures.get_id_nomenclature('OBJ_DENBR', 'IND') AS id_nomenclature_obj_count,
    -- Type de dénombrement = Estimé (??)
    ref_nomenclatures.get_id_nomenclature('TYP_DENBR', 'Es') AS id_nomenclature_type_count,
    -- Statut d'observation (présent par défaut)
    COALESCE(
        (oc.data ->> 'id_nomenclature_observation_status')::integer,
        gn_synthese.get_default_nomenclature_value('STATUT_OBS')
    ) AS id_nomenclature_observation_status,
    -- Source = Terrain
    ref_nomenclatures.get_id_nomenclature('STATUT_SOURCE', 'Te') AS id_nomenclature_source_status,
    -- Type d'information géographique = Géoréférencement
    ref_nomenclatures.get_id_nomenclature('TYP_INF_GEO', '1') AS id_nomenclature_info_geo_type,
    -- Dénombrement min / max
    (oc.data ->> 'count')::integer AS count_min,
    (oc.data ->> 'count')::integer AS count_max,
    -- Taxonomie
    o.cd_nom,
    t.lb_nom AS nom_cite,
    -- Localisation (du gîte)
    s.altitude_min,
    s.altitude_max,
    s.base_site_code AS place_name,
    s.the_geom_4326,
    s.the_geom_point,
    s.geom_local AS the_geom_local,
    5 AS "precision",
    -- Date (de la visite)
    v.date_min,
    v.date_max,
    -- Observateurs (de la visite)
    obs.observers,
    v.id_digitiser,
    -- Commentaires
    v.comments AS comment_context,
    o.comments AS comment_description,
    oc.data AS additional_data,
    GREATEST(v.meta_update_date, s.meta_update_date) AS meta_update_date
FROM gn_monitoring.t_observations o
LEFT JOIN gn_monitoring.t_observation_complements oc USING (id_observation)
JOIN visits v ON v.id_base_visit = o.id_base_visit
JOIN sites s ON s.id_base_site = v.id_base_site
JOIN gn_commons.t_modules m ON m.id_module = v.id_module
JOIN taxonomie.taxref t ON t.cd_nom = o.cd_nom
JOIN src ON true
JOIN observers obs ON obs.id_base_visit = v.id_base_visit
WHERE m.module_code = 'gn_module_monitoring_:module_code;';

SELECT * FROM gn_monitoring.v_synthese_:module_code
