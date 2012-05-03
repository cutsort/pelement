-- chado-lite
--
-- this only supports the fields needed for basic transcript models:
-- exon -> transcripts -> genes.

-- feature_id's are copied from the version of chado to save us
-- the work of regenerating them. featureloc_id's and feature_relationship_id's
-- are regenerated: there are not referential constraints on them

create table feature ( feature_id integer not null unique primary key,
                       name varchar(255),
                       uniquename text not null,
                       type_id integer);

create table featureloc ( featureloc_id serial,
                          feature_id integer not null references feature(feature_id) deferrable,
                          srcfeature_id integer not null references feature(feature_id) deferrable,
                          fmin integer not null,
                          fmax integer not null,
                          strand smallint);

create table feature_relationship ( feature_relationship_id serial,
                                    subject_id integer not null references feature(feature_id) deferrable,
                                    object_id integer not null references feature(feature_id) deferrable,
                                    type_id integer not null );

create index feature_name_I on feature(name);
create index feature_uniquename_I on feature(uniquename);
grant select on feature to public;

create index featureloc_feature_id_I on featureloc(feature_id);
create index featureloc_srcfeature_id_I on featureloc(srcfeature_id);
create index featureloc_fmin_I on featureloc(fmin);
create index featureloc_fmax_I on featureloc(fmax);
grant select on featureloc to public;

create index feature_relationship_subject_id_I on feature_relationship(subject_id);
create index feature_relationship_object_id_I on feature_relationship(object_id);
grant select on feature_relationship to public;
                        
