--NEW INSURANCE TABLES WITH NEW TEST4 TABLE

-- insurance status

drop table if exists test;
create temp table test as
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

drop table if exists test2;
create temp table test2 as
select distinct patient_guid, sum(npl) as npl_sum, sum(misc) as misc_sum, sum(mc_ffs) as mc_ffs_sum,
sum(mc_mngd) as mc_mngd_sum, sum(mil) as mil_sum, sum(govt) as govt_sum, sum(medicaid) as medicaid_sum,
sum(private) as private_sum, sum(unkwn) as unkwn_sum
from test
group by patient_guid;

-- denote categories

DROP TABLE IF EXISTS ins_test3;
CREATE temp TABLE ins_test3 AS 
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
	test2;


SELECT count(patient_guid)
FROM ins_test3;
--62084802

SELECT count(DISTINCT patient_guid)
FROM ins_test3;
--62084802

----------------------------------------------------------------------
DROP TABLE IF EXISTS test4;
CREATE temp TABLE test4 AS SELECT DISTINCT
	count(
		*),
	procedure_code_fix,
	ins_final,
	specialization_oph,
	rk
FROM (
	SELECT DISTINCT
		x.*,
		ROW_NUMBER() OVER (PARTITION BY patient_guid,
			procedure_code_fix, EXTRACT(year FROM procedure_date) ORDER BY
				procedure_code_fix) AS two_surgeries
		FROM ( SELECT DISTINCT
			COALESCE(i.ins_final, 'Unknown') AS ins_final,
			
			ROW_NUMBER() OVER (PARTITION BY
			p.patient_guid, procedure_code_fix, p.procedure_date
			ORDER BY d.npi) as rk,											 --rk is defined as coding for a single set of "pt guid, px_code_fix and procedure_date"
			
			d.specialization_oph,
			p.patient_guid,
			p.procedure_date,
			CASE WHEN p.procedure_code ILIKE '15820%' THEN
				'15820'
			WHEN p.procedure_code ILIKE '15821%' THEN
				'15821'
			WHEN p.procedure_code ILIKE '15822%' THEN
				'15822'
			WHEN p.procedure_code ILIKE '15823%' THEN
				'15823'
			WHEN p.procedure_code ILIKE '65730%' THEN
				'65730'
			WHEN p.procedure_code ILIKE '65750%' THEN
				'65750'
			WHEN p.procedure_code ILIKE '65755%' THEN
				'65755'
			WHEN p.procedure_code ILIKE '65756%' THEN
				'65756'
			WHEN p.procedure_code ILIKE '65855%' THEN
				'65855'
			WHEN p.procedure_code ILIKE '66179%' THEN
				'66179'
			WHEN p.procedure_code ILIKE '66180%' THEN
				'66180'
			WHEN p.procedure_code ILIKE '66183%' THEN
				'66183'
			WHEN p.procedure_code ILIKE '66184%' THEN
				'66184'
			WHEN p.procedure_code ILIKE '66185%' THEN
				'66185'
			WHEN p.procedure_code ILIKE '66840%' THEN
				'66840'
			WHEN p.procedure_code ILIKE '66850%' THEN
				'66850'
			WHEN p.procedure_code ILIKE '66852%' THEN
				'66852'
			WHEN p.procedure_code ILIKE '66920%' THEN
				'66920'
			WHEN p.procedure_code ILIKE '66982%' THEN
				'66982'
			WHEN p.procedure_code ILIKE '66983%' THEN
				'66983'
			WHEN p.procedure_code ILIKE '66984%' THEN
				'66984'
			WHEN p.procedure_code ILIKE '66985%' THEN
				'66985'
			WHEN p.procedure_code ILIKE '66986%' THEN
				'66986'
			WHEN p.procedure_code ILIKE '67101%' THEN
				'67101'
			WHEN p.procedure_code ILIKE '67105%' THEN
				'67105'
			WHEN p.procedure_code ILIKE '67107%' THEN
				'67107'
			WHEN p.procedure_code ILIKE '67108%' THEN
				'67108'
			WHEN p.procedure_code ILIKE '67110%' THEN
				'67110'
			WHEN p.procedure_code ILIKE '67113%' THEN
				'67113'
			WHEN p.procedure_code ILIKE '67121%' THEN
				'67121'
			WHEN p.procedure_code ILIKE '67141%' THEN
				'67141'
			WHEN p.procedure_code ILIKE '67145%' THEN
				'67145'
			WHEN p.procedure_code ILIKE '67228%' THEN
				'67228'
			WHEN p.procedure_code ILIKE '67901%' THEN
				'67901'
			WHEN p.procedure_code ILIKE '67902%' THEN
				'67902'
			WHEN p.procedure_code ILIKE '67904%' THEN
				'67904'
			WHEN p.procedure_code ILIKE '67906%' THEN
				'67906'
			WHEN p.procedure_code ILIKE '67908%' THEN
				'67908'
			WHEN p.procedure_code ILIKE '92002%' THEN
				'92002'
			WHEN p.procedure_code ILIKE '92004%' THEN
				'92004'
			WHEN p.procedure_code ILIKE '92012%' THEN
				'92012'
			WHEN p.procedure_code ILIKE '92014%' THEN
				'92014'
			WHEN p.procedure_code ILIKE '92081%' THEN
				'92081'
			WHEN p.procedure_code ILIKE '92082%' THEN
				'92082'
			WHEN p.procedure_code ILIKE '92083%' THEN
				'92083'
			WHEN p.procedure_code ILIKE '92132%' THEN
				'92132'
			WHEN p.procedure_code ILIKE '92133%' THEN
				'92133'
			WHEN p.procedure_code ILIKE '92134%' THEN
				'92134'
			WHEN p.procedure_code ILIKE '92235%' THEN
				'92235'
			WHEN p.procedure_code ILIKE '92240%' THEN
				'92240'
			WHEN p.procedure_code ILIKE '92242%' THEN
				'92242'
			WHEN p.procedure_code ILIKE '99201%' THEN
				'99201'
			WHEN p.procedure_code ILIKE '99202%' THEN
				'99202'
			WHEN p.procedure_code ILIKE '99203%' THEN
				'99203'
			WHEN p.procedure_code ILIKE '99204%' THEN
				'99204'
			WHEN p.procedure_code ILIKE '99205%' THEN
				'99205'
			WHEN p.procedure_code ILIKE '99211%' THEN
				'99211'
			WHEN p.procedure_code ILIKE '99212%' THEN
				'99212'
			WHEN p.procedure_code ILIKE '99213%' THEN
				'99213'
			WHEN p.procedure_code ILIKE '99214%' THEN
				'99214'
			WHEN p.procedure_code ILIKE '99215%' THEN
				'99215'
			WHEN p.procedure_code ILIKE '0191T%' THEN
				'0191T'
			WHEN procedure_code ILIKE '67210%' THEN
				'67210'
			WHEN procedure_code ILIKE '67903%' THEN
				'67903' 
			END AS procedure_code_fix
		FROM
			madrid2.patient_procedure p
		LEFT JOIN ins_test3 i ON p.patient_guid = i.patient_guid
		INNER JOIN madrid2.provider_directory d ON d.npi = p.npi
	WHERE (p.procedure_code ILIKE '15820%'
	OR p.procedure_code ILIKE '15821%'
	OR p.procedure_code ILIKE '15822%'
	OR p.procedure_code ILIKE '15823%'
	OR p.procedure_code ILIKE '65730%'
	OR p.procedure_code ILIKE '65750%'
	OR p.procedure_code ILIKE '65755%'
	OR p.procedure_code ILIKE '65756%'
	OR p.procedure_code ILIKE '65855%'
	OR p.procedure_code ILIKE '66179%'
	OR p.procedure_code ILIKE '66180%'
	OR p.procedure_code ILIKE '66183%'
	OR p.procedure_code ILIKE '66184%'
	OR p.procedure_code ILIKE '66185%'
	OR p.procedure_code ILIKE '66840%'
	OR p.procedure_code ILIKE '66850%'
	OR p.procedure_code ILIKE '66852%'
	OR p.procedure_code ILIKE '66920%'
	OR p.procedure_code ILIKE '66982%'
	OR p.procedure_code ILIKE '66983%'
	OR p.procedure_code ILIKE '66984%'
	OR p.procedure_code ILIKE '66985%'
	OR p.procedure_code ILIKE '66986%'
	OR p.procedure_code ILIKE '67101%'
	OR p.procedure_code ILIKE '67105%'
	OR p.procedure_code ILIKE '67107%'
	OR p.procedure_code ILIKE '67108%'
	OR p.procedure_code ILIKE '67110%'
	OR p.procedure_code ILIKE '67113%'
	OR p.procedure_code ILIKE '67121%'
	OR p.procedure_code ILIKE '67141%'
	OR p.procedure_code ILIKE '67145%'
	OR p.procedure_code ILIKE '67228%'
	OR p.procedure_code ILIKE '67901%'
	OR p.procedure_code ILIKE '67902%'
	OR p.procedure_code ILIKE '67904%'
	OR p.procedure_code ILIKE '67906%'
	OR p.procedure_code ILIKE '67908%'
	OR p.procedure_code ILIKE '92002%'
	OR p.procedure_code ILIKE '92004%'
	OR p.procedure_code ILIKE '92012%'
	OR p.procedure_code ILIKE '92014%'
	OR p.procedure_code ILIKE '92081%'
	OR p.procedure_code ILIKE '92082%'
	OR p.procedure_code ILIKE '92083%'
	OR p.procedure_code ILIKE '92132%'
	OR p.procedure_code ILIKE '92133%'
	OR p.procedure_code ILIKE '92134%'
	OR p.procedure_code ILIKE '92235%'
	OR p.procedure_code ILIKE '92240%'
	OR p.procedure_code ILIKE '92242%'
	OR p.procedure_code ILIKE '99201%'
	OR p.procedure_code ILIKE '99202%'
	OR p.procedure_code ILIKE '99203%'
	OR p.procedure_code ILIKE '99204%'
	OR p.procedure_code ILIKE '99205%'
	OR p.procedure_code ILIKE '99211%'
	OR p.procedure_code ILIKE '99212%'
	OR p.procedure_code ILIKE '99213%'
	OR p.procedure_code ILIKE '99214%'
	OR p.procedure_code ILIKE '99215%'
	OR p.procedure_code ILIKE '0191T%'
	OR procedure_code ILIKE '67210%'
	OR procedure_code ILIKE '67903%')
and(p.procedure_date BETWEEN '2018-01-01'
AND '2018-12-31')
AND d.credential = 'OPH MD') x WHERE rk = 1) --We want rk to equal one because we are taking the first NPI for each patient_guid, proc_code + proc_date 
WHERE
	two_surgeries IN(
		1, 2)
GROUP BY
	ins_final, specialization_oph, rk, procedure_code_fix
ORDER BY
	ins_final, specialization_oph, rk, procedure_code_fix;



DROP TABLE IF EXISTS test5;
CREATE temp TABLE test5 AS SELECT DISTINCT
	ins_final,
	procedure_code_fix,
	sum(count) AS sc
FROM
	test4
GROUP BY
	ins_final,
	procedure_code_fix
ORDER BY
	ins_final,
	procedure_code_fix;

SELECT *
FROM test5
where ins_final='Unknown'
Limit 20;
;
