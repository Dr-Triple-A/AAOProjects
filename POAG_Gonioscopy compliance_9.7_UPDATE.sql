--UPDATE from POAG_Gonioscopy compliance_4.14 code, using Madrid2 updated database vs. Madrid1 and date upto Dec 31, 2018 (vs. Jun 30, 2018)
--Step 1 - patients with POAG (no date resitriction) https://www.icd10data.com
--POAG pt in IRIS:
drop table if exists POAG_1a;

create TEMPORARY table POAG_1a as
select a.patient_guid, a.vh_patient_problem_uid, a.problem_code, date(a.documentation_date) as doc_dt, date(a.problem_onset_date) as dig_onset_dt
from madrid2.patient_problem a
where (a.problem_code ilike '365.10%' 
or a.problem_code ilike '365.11%' 
or a.problem_code ilike '365.12%'
or a.problem_code ilike '365.15%' 
or a.problem_code ilike 'H40.10%' 
or a.problem_code ilike 'H40.11%'
or a.problem_code ilike 'H40.12%'
or a.problem_code ilike 'H40.15%') 
and (doc_dt is NOT NULL OR dig_onset_dt is NOT NULL); --4382424 vs. 5041878 (vs 4568416), no date restrictions 

SELECT count(DISTINCT patient_guid) from POAG_1a;
/*
--Step 2/3 - patients with POAG between 2000-01-01 and 2018-12-31 and recoding diagnosis_date by (cased as index_date)
drop table if exists POAG_2a;
create TEMPORARY table POAG_2a as 
select a.patient_guid, date(b.documentation_date) as doc_dt, date(b.problem_onset_date) as dig_onset_dt
from POAG_1a a
inner join madrid2.patient_diagnosis_history b 
on a.patient_diagnosis_id = b.patient_diagnosis_id
where (doc_dt is NOT NULL OR dig_onset_dt is NOT NULL); --this removed records with no reported dates for either doc_dt or dig_onset_dt, leaving 4853914 with either doc_dt and/or dig_onset_dt (no date restriction).
*/

--minimum dates for both diagnosis_onset_date and documentation_date (all types of gluacoma)
drop table if exists POAG_1a_min_dt;
CREATE TEMPORARY table POAG_1a_min_dt as 
select a.patient_guid, min(a.doc_dt) as doc_dt, min(a.dig_onset_dt) as dig_onset_dt
from POAG_1a a
where doc_dt between '2000-01-01' and '2018-12-31' OR dig_onset_dt between '2000-01-01' and '2018-12-31' group by a.patient_guid; -- 4070753 (vs 3879681) - takes POAG_1a and ensures only 1 px_diag_date is taken and eithr dig_onset_dt or doc_dt are set to minimum

drop table if exists min_dateA;  --same as POAG_1_min_dt but for IRIS date from 2013
create temporary table min_dateA as 
select a.patient_guid, a.doc_dt, a.dig_onset_dt,
case when a.dig_onset_dt is not null AND a.dig_onset_dt < a.doc_dt then a.dig_onset_dt
	 else a.doc_dt end as min_index_date
from POAG_1a_min_dt a
where min_index_date between '2013-01-01' and '2018-12-31'; --3021676 (vs 2891107), less than POAG_1_min_dt becuase restricted min_index_date doesnt account for after 2018-12-31
 
--	Then from year of birth variable in madrid.patient_demographic table, calculate age at the 
--earliest index date (early_index_dt) based on year of index date and year birth. Restrict to patients 18 and above.

drop table if EXISTS POAG_ageA;   ----MIN dates with age restriction 
create TEMPORARY table POAG_ageA as 
select a.patient_guid, b.year_of_birth, a.min_index_date, a.min_index_date + 365 as one_yr_dt, (datepart(year, a.min_index_date) - b.year_of_birth) as birth_age
from min_dateA a   
inner join madrid2.patient_demographic b 
on a.patient_guid = b.patient_guid
where birth_age >= 18 and birth_age < 115; --2800982 vs 3285738 (vs 2847932) - removes patients <18 AND with NULL birth_age, and creates a new variable of 1 year after min date.

SELECT count(DISTINCT patient_guid) FROM POAG_ageA;
----------------------------------------------------------------------------------------------
--Max Year for follow-up analysis
--Step 1/2:
drop table if exists poag_cohort_followupA;
create TEMPORARY table poag_cohort_followupA as 
    select patient_guid, max(last_dt) as last_dt
    from (
        select b.patient_guid,  max(date(b.last_time_provider_seen)) as last_dt
			from madrid2.patient_provider b  			
			where b.last_time_provider_seen BETWEEN '2013-01-01' AND '2019-06-30'
			AND patient_guid in (select patient_guid from POAG_ageA) group by b.patient_guid   --require patient_guid to be in the patient_provider table.
		union
        select c.patient_guid,  max(date(c.visit_start_date)) as last_dt
			from madrid2.patient_visit c     	 											   
			where c.visit_start_date BETWEEN '2013-01-01' AND '2019-06-30' 
			group by c.patient_guid
		union
        select patient_guid, max(dt) as last_dt from              
            (select patient_guid, 
                case when problem_onset_date is not null 
                    and problem_onset_date between '2013-01-01' and '2018-12-31'     		--changed date from 2000 to 2013
                    then problem_onset_date 
                when documentation_date is not null 
                    and documentation_date between '2013-01-01' and '2018-12-31'			--changed date from 2000 to 2013
                    then documentation_date
                else NULL
                end as dt
             from madrid2.patient_problem)                       -- replaced madrid.patient_diagnosis INNER JOINING madrid.patient_diagnosis_history with just madrid2.patient_problem  
        where dt <= '2018-12-31' 						 
        and patient_guid in (select patient_guid from POAG_ageA)
        group by patient_guid
    )
group by patient_guid;     

--Step 3: KEEP
drop table if EXISTS poag_follow_upA;
create TEMPORARY table poag_follow_upA as 
select a.patient_guid, a.birth_age, a.min_index_date, a.one_yr_dt, b.last_dt, (b.last_dt-a.min_index_date) as day_diff 
from POAG_ageA a                      
inner join  poag_cohort_followupA b   
on a.patient_guid=b.patient_guid;  --3012965 patients

drop table if exists POAG_one_yr_dtA;
create TEMPORARY table POAG_one_yr_dtA as
select * from poag_follow_upA
where last_dt >= one_yr_dt; 
 
select count(DISTINCT patient_guid) from POAG_one_yr_dtA ; -- 1967087 v 2133607 (vs 2039432) is the total cohort, having at last date greater or equal to 365 days from index earliest date

--cohort total 1967087 vs 2133607 (vs 2039432) patients
----------------------------------------------------------------------------
--Identifying gonioscopy usage

--Step 1 gonioscopy must have at least one follow-up visit
Drop TABLE if EXISTS goni_useA;
create TEMPORARY table goni_useA as
select patient_guid, min(date(procedure_date)) as min_effective_date, 1 as goni_indicator  --procedure_date (vs madrid1's patient_procedure.effective_date)  is when they had goni
from madrid2.patient_procedure a
where procedure_code ilike '92020%'
and patient_guid in (select distinct patient_guid from POAG_one_yr_dtA)
group by a.patient_guid; --identifies all 830280 (vs 800209) gonioscopy patients (whether or not they had goni within 1 yr, or after 1 yr, and/or multiple goni)
 
drop table if exists goni_complianceA; --at least one year follow-up, only looking for goni within 1 yr.
create TEMPORARY table goni_complianceA as
select a.*, b.goni_indicator, b.min_effective_date, coalesce(b.goni_indicator,0) as goni_compliant
from POAG_one_yr_dtA a
left join goni_useA b  --retaining everyone in poag_one_yr_dtA cohort whether or not they had goni (2129654)
on a.patient_guid = b.patient_guid
and (b.min_effective_date - a.min_index_date) BETWEEN 0 and 364;  --had goni between min_index_date and effective date (procedure date)

select count(DISTINCT patient_guid) from goni_complianceA gc; -- 1967087 vs 2133607 (vs 2039432) had or did not have goni.
select count(DISTINCT patient_guid) from goni_complianceA where goni_compliant = 1; -- 414489 v 441658 (vs 419151) had goni 
select count(DISTINCT patient_guid) from goni_complianceA where goni_compliant = 0; -- 1552598 v 1691949 (vs 1620281) no goni

--Step 2
--Patients from original cohort who had a gonioscopy within the year assumption 
drop table if exists goni_cohortA;
create TEMPORARY table goni_cohortA as
select patient_guid, birth_age, min_index_date, min_effective_date, (min_effective_date-min_index_date) as dt_to_1st_goni, one_yr_dt, last_dt
from goni_complianceA where goni_compliant = 1; -- 414489 v 441658 (vs 419151)

/*-------------------
 * 
 * Demographic, Region, Insurance, IOP coding
 * ------------------*/

--Dani's new code for demographic data
drop table if exists POAG_demog_process;
create temporary table POAG_demog_process as
select distinct patient_guid, year_of_birth as yob, gender,
case when ethnicity = 'Hispanic or Latino' then 'Hispanic'
            when (ethnicity = 'Hispanic or Latino' and race = 'Declined to Answer') then 'Hispanic'
            when race = 'Caucasian' then 'White'
            when race = '2 or more races' then 'Multi'
			when race = 'Declined to answer' then 'Unknown'
			else race end as race
from madrid2.patient_demographic
where patient_guid in (select patient_guid from goni_complianceA);

--region (ok prepare yourself, this is going to be bad)                                           --(it will update poag_region_process2)
--the issue with IRIS 1.0 is that the diagnosis table has no physician_id, which is used to determine region
--so we first populate physician_id, then can get region

-- Get just patient_guids and documentation_dates in a single table

drop table if exists poag_pt_dt;
create temporary table poag_pt_dt as
select distinct patient_guid, min_index_date
from goni_complianceA;

-- Join to visits, get closest visit date to each diagnosis

drop table if exists poag_dx_join_v;
create temporary table poag_dx_join_v as
select
    patient_guid,
    min_index_date,
    npi														-- replaced provider id with npi
from (
    select
        patient_guid,
        npi,												-- replaced provider id with npi
        min_index_date,
        visit_start_date,
        row_number() over(
            partition by patient_guid, min_index_date
            order by days_between asc
        ) as "row"
    from (
        select
            d.patient_guid,
            v.npi,											-- replaced v.provider_id with v.npi
            d.min_index_date,
            v.visit_start_date,								-- replaced v.visit_date with v.visit_start_date
            abs(d.min_index_date - v.visit_start_date) as days_between         -- replaced v.visit_date with v.visit_start_date
        from poag_pt_dt d
        left join (
            select patient_guid, visit_start_date, npi		                                -- replaced visit_date with visit_start_date; replaced rendering_provider_id (provider_id) with NPI
            from madrid2.patient_visit												        -- replaced madrid.patient_visit with madrid2.patient_visit 
            where npi is not null
        ) v on d.patient_guid = v.patient_guid
    ) r1
    where days_between <= 180  -- 6 month restriction
) r2
where "row" = 1
;

-- Of diagnoses that still don't have a provider, attempt to get from procedures 

drop table if exists poag_dx_join_p;				--Replaced provider_id with npi; replaced effective_date with procedure_date
create temporary table poag_dx_join_p as
select
    patient_guid,
    min_index_date,
    npi
from (
    select
        patient_guid,
        npi,
        min_index_date,
        procedure_date,
        row_number() over(
            partition by npi, min_index_date
            order by days_between asc
        ) as "row"
    from (
        select
            d.patient_guid,
            p.npi,
            d.min_index_date,
            p.procedure_date,
            abs(d.min_index_date - p.procedure_date) as days_between
        from poag_dx_join_v d
        left join (
            select patient_guid, procedure_date, npi
            from madrid2.patient_procedure
            where npi is not null
        ) p on d.patient_guid = p.patient_guid
    ) r1
    where days_between <= 180  -- 6 month restriction
) r2
where "row" = 1
;

-- Append provider_ids (UPDATED provider_id AS NPI) to poag_pt_dt from the previous two tables if NULL

drop table if exists poag_pt_dt_prov;
create temporary table poag_pt_dt_prov as
select distinct
    u.patient_guid,
    u.min_index_date,
    coalesce(pv.npi, pp.npi) as npi
from poag_pt_dt u
left join poag_dx_join_v pv
on (u.patient_guid = pv.patient_guid and u.min_index_date = pv.min_index_date)
left join poag_dx_join_p pp
on (u.patient_guid = pp.patient_guid and u.min_index_date = pp.min_index_date)
;

-- Of diagnoses that still don't have a provider, attempt to get from patient_provider

drop table if exists poag_pt_pprov;
create temporary table poag_pt_pprov as
select
    r1.patient_guid,
    r1.min_index_date,
    p.npi
from (
    select distinct patient_guid, min_index_date
    from poag_pt_dt_prov
    where npi is null
) r1
left join madrid2.patient_provider p on (                      --replaced madrid.patient_provider with madrid2....
    r1.patient_guid = p.patient_guid and
    r1.min_index_date between p.first_time_provider_seen and p.last_time_provider_seen
)
;

-- Take mode of provider_id (UPDATED provider_id AS NPI) for each patient_guid-min_index_date combination

drop table if exists poag_pt_pprov_mode;
create temporary table poag_pt_pprov_mode as
select patient_guid, min_index_date, NPI
from (
    select
        patient_guid,
        min_index_date,
        NPI,
        row_number() over (
            partition by patient_guid, min_index_date
            order by count(*) desc
        ) as "row"
    from poag_pt_pprov
    group by patient_guid, min_index_date, NPI
) as r1
where "row" = 1
;

-- Coalesce provider_id replace for all sources (UPDATED provider_id AS NPI)

drop table if exists poag_diag_provid;
create table poag_diag_provid as
select
    c.patient_guid,
    c.min_index_date,
    coalesce(p.npi, pm.npi) as npi									  
from goni_complianceA c                                               --reflects updated goin_compliance table (goni_complianceA)
left join poag_pt_dt_prov p on (
    c.patient_guid = p.patient_guid and
    c.min_index_date = p.min_index_date
)
left join poag_pt_pprov_mode pm on (
    c.patient_guid = pm.patient_guid and
    c.min_index_date = pm.min_index_date
)
;

-- Now that we have physician_id, we can process region           

drop table if exists poag_location_process;
create table poag_location_process as 
select distinct npi, state,                       --replaced provider_id with npi from madrid2?
CASE
    when state = 'AK' then 'West'
    when state = 'CA' then 'West'
    when state = 'HI' then 'West'
    when state = 'OR' then 'West'
    when state = 'WA' then 'West'
    when state = 'AZ' then 'West'
    when state = 'CO' then 'West'
    when state = 'ID' then 'West'
    when state = 'NM' then 'West'
    when state = 'MT' then 'West'
    when state = 'UT' then 'West'
    when state = 'NV' then 'West'
    when state = 'WY' then 'West'
    when state = 'DE' then 'South'
    when state = 'DC' then 'South'
    when state = 'FL' then 'South'
    when state = 'GA' then 'South'
    when state = 'MD' then 'South'
    when state = 'NC' then 'South'
    when state = 'SC' then 'South'
    when state = 'VA' then 'South'
    when state = 'WV' then 'South'
    when state = 'AL' then 'South'
    when state = 'KY' then 'South'
    when state = 'MS' then 'South'
    when state = 'TN' then 'South'
    when state = 'AR' then 'South'
    when state = 'LA' then 'South'
    when state = 'OK' then 'South'
    when state = 'TX' then 'South'
    when state = 'IN' then 'Midwest'
    when state = 'IL' then 'Midwest'
    when state = 'MI' then 'Midwest'
    when state = 'OH' then 'Midwest'
    when state = 'WI' then 'Midwest'
    when state = 'IA' then 'Midwest'
    when state = 'KS' then 'Midwest'
    when state = 'MN' then 'Midwest'
    when state = 'MO' then 'Midwest'
    when state = 'NE' then 'Midwest'
    when state = 'ND' then 'Midwest'
    when state = 'SD' then 'Midwest'
    when state = 'CT' then 'Northeast'
    when state = 'ME' then 'Northeast'
    when state = 'MA' then 'Northeast'
    when state = 'NH' then 'Northeast'
    when state = 'RI' then 'Northeast'
    when state = 'VT' then 'Northeast'
    when state = 'NJ' then 'Northeast'
    when state = 'NY' then 'Northeast'
    when state = 'PA' then 'Northeast'
    else null end as region
from (select distinct npi, state											--removed provider_id
from madrid2.provider_directory 											--replaced madrid.provider_directory with madrid2...
where npi in (select distinct npi from poag_diag_provid))  					--replaced provider_id with npi from madrid2 			
where state is not null;
/*UNION
select distinct a.npi, b.state,												--removed a.provider_id
CASE
    when b.state = 'AK' then 'West'
    when b.state = 'CA' then 'West'
    when b.state = 'HI' then 'West'
    when b.state = 'OR' then 'West'
    when b.state = 'WA' then 'West'
    when b.state = 'AZ' then 'West'
    when b.state = 'CO' then 'West'
    when b.state = 'ID' then 'West'
    when b.state = 'NM' then 'West'
    when b.state = 'MT' then 'West'
    when b.state = 'UT' then 'West'
    when b.state = 'NV' then 'West'
    when b.state = 'WY' then 'West'
    when b.state = 'DE' then 'South'
    when b.state = 'DC' then 'South'
    when b.state = 'FL' then 'South'
    when b.state = 'GA' then 'South'
    when b.state = 'MD' then 'South'
    when b.state = 'NC' then 'South'
    when b.state = 'SC' then 'South'
    when b.state = 'VA' then 'South'
    when b.state = 'WV' then 'South'
    when b.state = 'AL' then 'South'
    when b.state = 'KY' then 'South'
    when b.state = 'MS' then 'South'
    when b.state = 'TN' then 'South'
    when b.state = 'AR' then 'South'
    when b.state = 'LA' then 'South'
    when b.state = 'OK' then 'South'
    when b.state = 'TX' then 'South'
    when b.state = 'IN' then 'Midwest'
    when b.state = 'IL' then 'Midwest'
    when b.state = 'MI' then 'Midwest'
    when b.state = 'OH' then 'Midwest'
    when b.state = 'WI' then 'Midwest'
    when b.state = 'IA' then 'Midwest'
    when b.state = 'KS' then 'Midwest'
    when b.state = 'MN' then 'Midwest'
    when b.state = 'MO' then 'Midwest'
    when b.state = 'NE' then 'Midwest'
    when b.state = 'ND' then 'Midwest'
    when b.state = 'SD' then 'Midwest'
    when b.state = 'CT' then 'Northeast'
    when b.state = 'ME' then 'Northeast'
    when b.state = 'MA' then 'Northeast'
    when b.state = 'NH' then 'Northeast'
    when b.state = 'RI' then 'Northeast'
    when b.state = 'VT' then 'Northeast'
    when b.state = 'NJ' then 'Northeast'
    when b.state = 'NY' then 'Northeast'
    when b.state = 'PA' then 'Northeast'
    else null end as region
from (select distinct npi, state											--removed provider_id
from madrid2.provider_directory                                    			--replaced madrid.provider_directory with madrid2...
where npi in (select distinct npi from poag_diag_provid)) as a 				--replaced provider_id with npi from madrid2
inner join aao_team.aao_npi_2019_06 as b
on a.npi=b.physician_npi
where a.state is null; */

--take mode

drop table if exists poag_region_process;
create temporary table poag_region_process as
select distinct a.patient_guid, a.min_index_date, a.npi, b.region
from poag_diag_provid as a
inner join 
(select npi, region
from (
    select
        npi,
        region,
        row_number() over (partition by npi order by count(*) desc) as "row"
    from (
        select npi, region
        from poag_location_process)
     as y1
    group by npi, region
) as y2
where "row" = 1) as b
on a.npi=b.npi;

/*some provider_ids have equally as frequent regions, pick one*/

DROP TABLE if exists poag_region_process2;
CREATE temp TABLE poag_region_process2 as
WITH reg_summary AS (
    SELECT p.*,
           ROW_NUMBER() OVER(PARTITION BY p.patient_guid
                                 ORDER BY p.npi, p.region ASC) AS rk
      FROM poag_region_process p)
SELECT s.*
FROM reg_summary s
WHERE s.rk = 1;

--Updated insurance using Madrid2/Kat's CPT code 

drop table if exists poag_ins_process1;
create TEMPORARY table poag_ins_process1 as
select distinct patient_guid, insurance_type,
case when insurance_type ilike '%No Insurance%' then 1 else 0 end as npl,
case when insurance_type ilike '%Misc%' then 1 else 0 end as misc,
case when insurance_type ilike 'Medicare' then 1 else 0 end as mc_ffs,  
case when insurance_type ilike 'Medicare Advantage' then 1 else 0 end as mc_mngd,
case when insurance_type ilike '%Military%' then 1 else 0 end as mil,
case when insurance_type ilike '%Govt%' then 1 else 0 end as govt,
case when insurance_type ilike '%Medicaid%' then 1 else 0 end as medicaid,
case when insurance_type ilike '%Commercial%' then 1 else 0 end as private,
case when (insurance_type ilike '%Unknown%' or insurance_type is NULL)
then 1 else 0 end as unkwn
from madrid2.patient_insurance;

-- sum the indicators

drop table if exists poag_ins_process2;
create TEMPORARY table poag_ins_process2 as
select distinct patient_guid, sum(npl) as npl_sum, sum(misc) as misc_sum, sum(mc_ffs) as mc_ffs_sum,
sum(mc_mngd) as mc_mngd_sum, sum(mil) as mil_sum, sum(govt) as govt_sum, sum(medicaid) as medicaid_sum,
sum(private) as private_sum, sum(unkwn) as unkwn_sum
from poag_ins_process1
group by patient_guid;

-- denote categories

DROP TABLE IF EXISTS poag_ins_process_final;
CREATE TEMPORARY TABLE poag_ins_process_final as 
SELECT DISTINCT
   patient_guid,
	CASE WHEN mc_ffs_sum > 0 THEN
		'Medicare FFS'
	WHEN mc_mngd_sum > 0 THEN
		'Medicare Managed'
	WHEN medicaid_sum > 0 THEN
		'Medicaid'
	WHEN mil_sum > 0 THEN
		'Military'
	WHEN govt_sum > 0 THEN
		'Govt'
	WHEN private_sum > 0 THEN
		'Private'
	WHEN misc_sum > 0 THEN
		'Private'
	WHEN (
		unkwn_sum > 0
		OR npl_sum > 0) THEN
		'Unknown'
	ELSE
		'Unknown'
	END AS ins_final
FROM
	poag_ins_process2; 

--iop updated with madrid2.patient_result_iop vs. madrid.patient_result_iop; it's also pulling from goni_complianceA table

/*pull cohort IOPs*/

drop table if exists poag_iop;
create TEMPORARY table poag_iop as 
select distinct patient_guid, result_date, iop
from madrid2.patient_result_iop															--updated with madrid2 vs. madrid.patient_result_iop
where patient_guid in (select distinct patient_guid from goni_complianceA)
UNION
select distinct patient_guid, result_date, iop
from madrid2.patient_result_iop
where patient_guid in (select distinct patient_guid from goni_complianceA)
UNION
select distinct patient_guid, result_date, iop
from madrid2.patient_result_iop
where patient_guid in (select distinct patient_guid from goni_complianceA);

--average by day in case multiple values per day

drop table if exists poag_iop_avg;
create TEMPORARY table poag_iop_avg as 
select a.*, b.result_date, b.iop_avg 
from goni_complianceA as a                                                             --replaced with goni_complianceA
inner join 
(select distinct patient_guid, result_date, avg(iop) as iop_avg
from poag_iop
where (iop <> 999 and iop is not null and iop >=0 and iop <=80)
group by patient_guid, result_date) as b 
on a.patient_guid=b.patient_guid;

--take IOP closest to earliest poag date per patient eye, +/- 3 mo windows

DROP TABLE if exists poag_iop_bl;
CREATE TEMPORARY TABLE poag_iop_bl as
WITH iop2sum AS (
    SELECT p.patient_guid, 
           p.iop_avg, 
           p.result_date,
           p.min_index_date,
           abs(p.result_date - p.min_index_date) as index_diff,
           ROW_NUMBER() OVER(PARTITION BY p.patient_guid
                                 ORDER BY abs(p.result_date - p.min_index_date) ASC) AS rk
      FROM poag_iop_avg as p 
      WHERE abs(p.result_date - p.min_index_date) between 0 and 90)
SELECT s.*
FROM iop2sum s
WHERE s.rk = 1;

--take IOP closest to one year months date, +/- 3 mo windows

DROP TABLE if exists poag_iop_1yr;
CREATE TEMPORARY TABLE poag_iop_1yr as
WITH iop3sum AS (
    SELECT p.patient_guid, 
           p.iop_avg, 
           p.result_date,
           p.one_yr_dt,
           abs(p.result_date - p.one_yr_dt) as one_yr_diff,
           ROW_NUMBER() OVER(PARTITION BY p.patient_guid
                                 ORDER BY abs(p.result_date - p.one_yr_dt) ASC) AS rk
      FROM poag_iop_avg as p 
      WHERE abs(p.result_date - p.one_yr_dt) between 0 and 90)
SELECT s.*
FROM iop3sum s
WHERE s.rk = 1;

--VA

--pull VA  ---ERROR

drop table if exists poag_va;
create TEMPORARY table poag_va as 
select distinct patient_guid, result_date, 
CAST(logmar AS DECIMAL(6, 2)), va_type, va_method, result_description, observation_description, pinhole, refraction     --Replaced practice_description with result_description
from madrid2.patient_result_va                                                 						                    --updated with madrid2.patient_result_va vs. madrid.patient_result_va
where logmar not ilike '999'
and va_method<>2
and CAST(logmar AS DECIMAL(6, 2)) < 3
and va_type<>2
and patient_guid in (select distinct patient_guid from goni_complianceA)
UNION
select distinct patient_guid, result_date, 
CAST(logmar AS DECIMAL(6, 2)), va_type, va_method, result_description, observation_description, pinhole, refraction    --Replaced practice_description with result_description
from madrid2.patient_result_va																	   					   --updated with madrid2.patient_result_va vs. madrid.patient_result_va
where logmar not ilike '999'
and va_method<>2
and CAST(logmar AS DECIMAL(6, 2)) < 3
and patient_guid in (select distinct patient_guid from goni_complianceA)
and va_type<>2
UNION
select distinct patient_guid, result_date,  
CAST(logmar AS DECIMAL(6, 2)), va_type, va_method, result_description, observation_description, pinhole, refraction     --Replaced practice_description with result_description
from madrid2.patient_result_va													                    					--updated with madrid2.patient_result_va vs. madrid.patient_result_va																
where logmar not ilike '999'
and va_method<>2
and CAST(logmar AS DECIMAL(6, 2)) < 3
and patient_guid in (select distinct patient_guid from goni_complianceA)
and va_type<>2;

--Step 1: average per day where va_type=1 (BCVA)

drop table if exists poag_bcva_avg;
create TEMPORARY table poag_bcva_avg as 
select distinct patient_guid, result_date, avg(logmar) as va_avg
from poag_va
where va_type=1
group by patient_guid, result_date;

--Step 2: for the patient, eyes, date combos that are NOT IN the BCVA group but not uncorrected, we are going to create an order variable
--1: pinhole 2: distance 3: refraction 4: glare

drop table if exists poag_va_process;
create TEMPORARY table poag_va_process as 
select distinct *, 
case when pinhole ilike 'TRUE' then 1
when refraction ilike 'TRUE' then 3
when (observation_description ilike '%glare%' or result_description ilike '%glare%') then 4     --Removed "or practice_description ilike '%glare%' "
else 2 end as va_order
from poag_va
where patient_guid not in (select distinct patient_guid from poag_bcva_avg);

--Step 3: for the non va_type=1, take value that is lowest in the order
                
DROP TABLE if exists poag_va_process2;
CREATE TEMPORARY TABLE poag_va_process2 as
WITH vsum AS (
    SELECT p.patient_guid, 
           p.result_date, 
           p.logmar,
           p.va_order,
           ROW_NUMBER() OVER(PARTITION BY p.patient_guid, p.result_date
                                 ORDER BY va_order ASC) AS rk
      FROM poag_va_process p)
SELECT s.*
FROM vsum s
WHERE s.rk = 1;

--combine both va datasets, join to cohort

drop table if exists poag_va_combine;
create TEMPORARY table poag_va_combine as 
select a.patient_guid, a.min_index_date, one_yr_dt,
b.result_date as va_date, b.va
from goni_complianceA as a
inner join 
(select distinct patient_guid, result_date, va_avg as va
from poag_bcva_avg
union 
select distinct patient_guid, result_date, logmar as va
from poag_va_process2) as b 
on a.patient_guid=b.patient_guid;

--take VA closest to earliest poag date per patient eye, +/- 3 mo windows

DROP TABLE if exists poag_va_bl;
CREATE TEMPORARY TABLE poag_va_bl as
WITH va2sum AS (
    SELECT p.patient_guid, 
           p.va, 
           p.va_date,
           p.min_index_date,
           abs(p.va_date - p.min_index_date) as index_diff,
           ROW_NUMBER() OVER(PARTITION BY p.patient_guid
                                 ORDER BY abs(p.va_date - p.min_index_date) ASC) AS rk
      FROM poag_va_combine as p 
      WHERE abs(p.va_date - p.min_index_date) between 0 and 90)
SELECT s.*
FROM va2sum s
WHERE s.rk = 1;

--take va closest to one year months date, +/- 3 mo windows

DROP TABLE if exists poag_va_1yr;
CREATE TEMPORARY TABLE poag_va_1yr as
WITH va3sum AS (
    SELECT p.patient_guid, 
           p.va, 
           p.va_date,
           p.one_yr_dt,
           abs(p.va_date - p.one_yr_dt) as one_yr_diff,
           ROW_NUMBER() OVER(PARTITION BY p.patient_guid
                                 ORDER BY abs(p.va_date - p.one_yr_dt) ASC) AS rk
      FROM poag_va_combine as p 
      WHERE abs(p.va_date - p.one_yr_dt) between 0 and 90)
SELECT s.*
FROM va3sum s
WHERE s.rk = 1;

--create final cohort by combining main cohort with demographics

Drop table if exists aao_project.goni_with_demographics;
create table aao_project.goni_with_demographics as 
select a.*, b.gender, b.race, b.yob, coalesce(d.region, 'Unknown') as region_final,         --b.race, b.yob added vs. b.gender, c.race,
e.ins_final, f.iop_avg as bl_iop, g.iop_avg as iop_1yr, h.va as bl_va, i.va as va_1yr
from goni_complianceA as a 																	--goni_complianceA vs. goni_compliance 
left join POAG_demog_process as b 															--POAG_demog_process replaced both 'poag_gender_process' and 'poag_race_process'
on a.patient_guid=b.patient_guid
left join poag_region_process2 as d 
on a.patient_guid=d.patient_guid 
left join poag_ins_process_final as e    													--poag_ins_process_final reflects updated madrid2 ins table
on a.patient_guid=e.patient_guid
left join poag_iop_bl as f 
on a.patient_guid=f.patient_guid
left join poag_iop_1yr as g 
on a.patient_guid=g.patient_guid
left join poag_va_bl as h 
on a.patient_guid=h.patient_guid
left join poag_va_1yr as i 
on a.patient_guid=i.patient_guid;

--Counts for demographic data
Select count(*) from aao_project.goni_with_demographics; -- 1967087 (madrid2update) v 2133607 (madrid2) vs 2039432 (madrid)   
Select * from aao_project.goni_with_demographics limit 20; --2133607 (madrid2) vs 2039432 (madrid)   
select count(*) from aao_project.goni_with_demographics where goni_compliant = 1 and gender = 'Unknown'; --223002 (f), 189797 (m), 1690 (unknown)

select race, count(*) from aao_project.goni_with_demographics 
where goni_compliant = 1
group by race ;


create TEMPORARY table goni_age_bracket as
select a.*,															
 	case when birth_age >=0 and birth_age < 18 then 'under 18'
		 when birth_age >=18 and birth_age <= 44 then 'between 18 and 44'
		 when birth_age >44 and birth_age <= 64 then 'between 45 and 64'
		 when birth_age >64 and birth_age <= 74 then 'between 65 and 74'
		 when birth_age >74 and birth_age <= 84 then 'between 75 and 84'
		 when birth_age >84 and birth_age < 115 then '85+'
		 else 'unknown' end as agecat
		 from aao_project.goni_with_demographics a;
		
select agecat, count(*) from goni_age_bracket
where goni_compliant = 1
group by agecat;
	
SELECT median(birth_age) from aao_project.goni_with_demographics where goni_compliant = 1 ;





