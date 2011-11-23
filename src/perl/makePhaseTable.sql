--
--
-- generate the table for reporting the phase of introns
--
--

\a
\f'\t'

select a.uniquename as arm,g.name as gene_name,t.name as transcript_name,te1.rank as exon_number,e1l.fmin as exon_start,
e1l.fmax as exon_end,
mod(e1l.fmax-e1l.fmin,3) as exon_phase,e1l.fmax as intron_start,e2l.fmin as intron_end,ag.strand
into temp table joe_pstr_temp
from
feature g, feature_relationship gt,
feature a, featureloc ag,
feature t, feature_relationship te1, feature_relationship te2, feature e1, feature e2,
featureloc e1l, featureloc e2l
where
ag.srcfeature_id=a.feature_id and
ag.feature_id=g.feature_id and
a.organism_id=1 and
ag.strand=1 and
g.type_id=219 and
t.type_id=368 and
e1.type_id=369 and
e2.type_id=369 and
gt.object_id=g.feature_id and
gt.subject_id=t.feature_id and
gt.type_id=26 and
te1.object_id = t.feature_id and
te1.subject_id = e1.feature_id and
te1.type_id=26 and
te2.object_id = t.feature_id and
te2.subject_id = e2.feature_id and
te2.type_id=26 and
te1.rank+1=te2.rank and
e1.feature_id=e1l.feature_id and
e2.feature_id=e2l.feature_id;

select a.uniquename as arm,g.name as gene_name,t.name as transcript_name,te1.rank as exon_number,e1l.fmax as exon_start,
e1l.fmin as exon_end,
mod(e1l.fmax-e1l.fmin,3) as exon_phase,e1l.fmin as intron_start,e2l.fmax as intron_end,ag.strand
into temp table joe_mstr_temp
from
feature g, feature_relationship gt,
feature a, featureloc ag,
feature t, feature_relationship te1, feature_relationship te2, feature e1, feature e2,
featureloc e1l, featureloc e2l
where
ag.srcfeature_id=a.feature_id and
ag.feature_id=g.feature_id and
a.organism_id=1 and
ag.strand=-1 and
g.type_id=219 and
t.type_id=368 and
e1.type_id=369 and
e2.type_id=369 and
gt.object_id=g.feature_id and
gt.subject_id=t.feature_id and
gt.type_id=26 and
te1.object_id = t.feature_id and
te1.subject_id = e1.feature_id and
te1.type_id=26 and
te2.object_id = t.feature_id and
te2.subject_id = e2.feature_id and
te2.type_id=26 and
te1.rank+1=te2.rank and
e1.feature_id=e1l.feature_id and
e2.feature_id=e2l.feature_id;

select a.arm,a.gene_name,a.transcript_name,a.strand,a.exon_number,a.intron_start,a.intron_end,mod(sum(b.exon_phase),3) as phase
into table phase
from joe_pstr_temp a, joe_pstr_temp b
where
a.transcript_name=b.transcript_name and
b.exon_number <= a.exon_number
group by
a.arm,a.gene_name,a.transcript_name,a.exon_number,a.intron_start,a.intron_end,a.strand
order by a.arm,a.gene_name,a.transcript_name,a.exon_number;

insert into phase 
select a.arm,a.gene_name,a.transcript_name,a.strand,a.exon_number,a.intron_end as intron_start,a.intron_start as intron_end,mod(sum(b.exon_phase),3) as phase
from joe_mstr_temp a, joe_mstr_temp b
where
a.transcript_name=b.transcript_name and
b.exon_number <= a.exon_number
group by
a.arm,a.gene_name,a.transcript_name,a.exon_number,a.intron_start,a.intron_end,a.strand
order by a.arm,a.gene_name,a.transcript_name,a.exon_number
;

\o phase_dmp
select * from phase;
\o
