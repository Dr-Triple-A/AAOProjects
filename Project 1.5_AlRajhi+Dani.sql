SELECT * FROM madrid.patient_diagnosis_laterality limit 200;

/*practice_code only for POAG*/
drop table if exists q1p;

create TEMPORARY table q1p as 
select a.patient_diagnosis_id, a.practice_code, a.diag_eye,
case when practice_code ilike 'H40.111%' then 1
		 when practice_code ilike 'H40.112%' then 2
		 when practice_code ilike 'H40.113%' then 3
		 when practice_code ilike 'H40.119%' or practice_code ilike 'H40.11X%' then 4
		 when practice_code ilike 'H40.11' then 5
		 else 0 end as latcat
from madrid.patient_diagnosis_laterality as a
where (a.practice_code ilike 'H40.11%');

select * from q1p limit 200;
select count(DISTINCT patient_diagnosis_id) from q1p; /*9726746*/

/*comparison table POAG*/
drop table if exists qp_compare;

create TEMPORARY table qp_compare as 
select *,
	case when diag_eye = latcat then 1
	else 0 end as lat_match 
from q1p;

select lat_match, count(lat_match) from qp_compare group by lat_match; /*POAG match = 8823046 vs. POAG mismatch = 903700*/

/*mismatch breakdown POAG*/
drop table if EXISTS qp_mismatch;

create TEMPORARY table qp_mismatch as
select *,
case when diag_eye = 1 and latcat = 4 then 'd1l4'
	 when diag_eye = 1 and latcat = 3 then 'd1l3'
	 when diag_eye = 1 and latcat = 2 then 'd1l2'
	 when diag_eye = 2 and latcat = 1 then 'd2l1'
	 when diag_eye = 2 and latcat = 3 then 'd2l3'
	 when diag_eye = 2 and latcat = 4 then 'd2l4'
	 when diag_eye = 3 and latcat = 1 then 'd3l1'
	 when diag_eye = 3 and latcat = 2 then 'd3l2'
	 when diag_eye = 3 and latcat = 4 then 'd3l4'
	 when diag_eye = 4 and latcat = 1 then 'd4l1'
	 when diag_eye = 4 and latcat = 2 then 'd4l2'
	 when diag_eye = 4 and latcat = 3 then 'd4l3'
else 'undiag' end as error_count
from qp_compare a where lat_match = 0;

select * from qp_mismatch where error_count = 'undiag' limit 100;

select error_count, count(DISTINCT patient_diagnosis_id) from qp_mismatch group by error_count;
----------------------------------------------------------------
----------------------------------------------------------------
/*practice_code only for conjunctiva*/
drop table if EXISTS q1c;

create TEMPORARY table q1c as 
select a.patient_diagnosis_id, a.practice_code, a.diag_eye,
case when practice_code ilike 'H11.411%' then 1
		 when practice_code ilike 'H11.412%' then 2
		 when practice_code ilike 'H11.413%' then 3
		 when practice_code ilike 'H11.419%' or practice_code ilike 'H11.41X%' then 4
		 when practice_code ilike 'H11.41' then 5
		 else 0 end as latcat
from madrid.patient_diagnosis_laterality as a
where (a.practice_code ilike 'H11.41%');

select count(DISTINCT patient_diagnosis_id) from q1c; /*9600*/

/*comparison table conjunctiva*/
drop table if exists qc_compare;

create TEMPORARY table qc_compare as 
select *,
	case when diag_eye = latcat then 1
	else 0 end as lat_match 
from q1c;

select lat_match, count(lat_match) from qc_compare group by lat_match; /*Conjunctiva match = 7644 vs. Conjunctiva mismatch = 1956*/

/*mismatch conjun*/
drop table if EXISTS qc_mismatch;

create TEMPORARY table qc_mismatch as
select *,
case when diag_eye = 1 and latcat = 4 then 'd1l4'
	 when diag_eye = 1 and latcat = 3 then 'd1l3'
	 when diag_eye = 1 and latcat = 2 then 'd1l2'
	 when diag_eye = 2 and latcat = 1 then 'd2l1'
	 when diag_eye = 2 and latcat = 3 then 'd2l3'
	 when diag_eye = 2 and latcat = 4 then 'd2l4'
	 when diag_eye = 3 and latcat = 1 then 'd3l1'
	 when diag_eye = 3 and latcat = 2 then 'd3l2'
	 when diag_eye = 3 and latcat = 4 then 'd3l4'
	 when diag_eye = 4 and latcat = 1 then 'd4l1'
	 when diag_eye = 4 and latcat = 2 then 'd4l2'
	 when diag_eye = 4 and latcat = 3 then 'd4l3'
else 'undiag' end as error_count
from qc_compare a where lat_match = 0;

select error_count, count(DISTINCT patient_diagnosis_id) from qc_mismatch group by error_count;
