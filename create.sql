-- SQL Script to document the creation of SQL tables.

-- loc2bin:
-- Calculates the R-tree bin for a given range
CREATE or replace FUNCTION loc2bin(int, int) RETURNS bigint AS $$
select floor(min(case when floor($1/10^g) = floor($2/10^g) then 10^g else null end)*10^6
    + floor($1/min(case when floor($1/10^g) = floor($2/10^g) then 10^g else null end)))::bigint
from generate_series(3,8) g
$$ LANGUAGE SQL;
ALTER FUNCTION loc2bin(int,int) OWNER TO labtrack;
GRANT EXECUTE ON FUNCTION loc2bin(int,int) TO public;

DROP VIEW gene_model_view;
CREATE OR REPLACE VIEW gene_model_view AS
SELECT a.feature_id AS scaffold_id
  , a.name AS scaffold_name
  , a.uniquename AS scaffold_uniquename
  , a.type_id AS scaffold_type_id
  , g.feature_id AS gene_id
  , g.name AS gene_name
  , g.uniquename AS gene_uniquename
  , g.type_id AS gene_type_id
  , t.feature_id AS transcript_id
  , t.name AS transcript_name
  , t.uniquename AS transcript_uniquename
  , t.type_id AS transcript_type_id
  , e.feature_id AS exon_id
  , e.name AS exon_name
  , e.uniquename AS exon_uniquename
  , e.type_id AS exon_type_id
  , gl.fmin AS gene_start
  , gl.fmax AS gene_end
  , gl.strand AS gene_strand
  , tl.fmin AS transcript_start
  , tl.fmax AS transcript_end
  , tl.strand AS transcript_strand
  , el.fmin AS exon_start
  , el.fmax AS exon_end
  , el.strand AS exon_strand
  , te.rank AS exon_rank
  , pl.fmin as cds_min
  , pl.fmax as cds_max
  , loc2bin(gl.fmin, gl.fmax) as gene_bin
  , loc2bin(tl.fmin, tl.fmax) as transcript_bin
  , loc2bin(el.fmin, el.fmax) as exon_bin
  , loc2bin(pl.fmin, pl.fmax) as cds_bin
FROM feature g
JOIN feature_relationship gt
  ON gt.object_id = g.feature_id
  AND gt.type_id = 26
  AND g.type_id = 219
JOIN feature t
  ON gt.subject_id = t.feature_id
  AND (t.type_id = 475
    OR t.type_id = 438
    OR t.type_id = 368
    OR t.type_id = 450
    OR t.type_id = 927
    OR t.type_id = 456
    OR t.type_id = 461
    OR t.type_id = 426)
JOIN feature_relationship te
  ON te.object_id = t.feature_id
  AND te.type_id = 26
JOIN feature e
  ON e.type_id = 257
  AND te.subject_id = e.feature_id
JOIN featureloc el
  ON el.feature_id = e.feature_id
JOIN featureloc tl
  ON tl.feature_id = t.feature_id
JOIN featureloc gl
  ON gl.feature_id = g.feature_id
JOIN feature a
  ON a.feature_id = gl.srcfeature_id
  AND a.feature_id = tl.srcfeature_id
  AND a.feature_id = el.srcfeature_id
JOIN feature_relationship tp
  ON tp.object_id=t.feature_id
JOIN feature p
  ON p.type_id=1179
  AND tp.subject_id=p.feature_id
JOIN featureloc pl
  ON pl.feature_id=p.feature_id;
ALTER TABLE gene_model_view OWNER TO labtrack;
GRANT ALL ON TABLE gene_model_view TO labtrack;
GRANT SELECT ON TABLE gene_model_view TO public;

create table gene_model as select * from gene_model_view;
ALTER TABLE gene_model OWNER TO labtrack;
GRANT ALL ON TABLE gene_model TO labtrack;
GRANT SELECT ON TABLE gene_model TO public;
create index on gene_model (gene_name);
create index on gene_model (gene_uniquename);
create index on gene_model (transcript_name);
create index on gene_model (transcript_uniquename);
create index on gene_model (scaffold_uniquename,exon_bin,exon_start,exon_end);
create index on gene_model (scaffold_uniquename,gene_bin,gene_start,gene_end);
create index on gene_model (scaffold_uniquename,transcript_bin,transcript_start,transcript_end);
create index on gene_model (scaffold_uniquename,cds_bin,cds_min,cds_max);
analyze gene_model;
