--
-- SQL for creation of the tables for P element processing
--

begin transaction;


create table person (
            login varchar(8) primary key not null unique,
            first_name varchar(32),
            initials varchar(10),
            last_name varchar(32) not null,
            suffix varchar(10),
            code varchar(64) not null,
            ison varchar(4),
            email varchar(255)
               );

create index person_login_I on person (login);
grant select on person to public;


create table enzyme (
            enzyme_name varchar(10) primary key not null unique,
            recognize_seq varchar(32)
              );
create index enzyme_enzyme_name_I on enzyme (enzyme_name);
grant select on enzyme to public;
grant all privileges on enzyme to web;
           
create table batch (
            id serial primary key,
            description varchar(64),
            user_login varchar(8) references person(login) deferrable,
            batch_date date
               );
grant select on batch to public;
grant all privileges on batch to web;

-- the sample table is the well mapping for a plate
create table sample (
            id serial primary key,
            batch_id int not null references batch(id) deferrable,
            well varchar(3) not null,
            strain_name varchar(32) not null
             );
create index sample_batch_id_I on sample(batch_id);
create index sample_strain_name_I on sample(strain_name);
grant select on sample to public;
grant all privileges on sample to web;

create table strain_alias (
            strain_name varchar(32) not null references strain(strain_name),
            alias varchar(32) not null unique
             );

grant select on strain_alias to public;
grant all privileges on strain_alias to web;

create table digestion (
            id serial primary key,
            name varchar(10) not null unique,
            batch_id integer not null references batch(id) deferrable,
            enzyme1 varchar(10) not null references enzyme(enzyme_name) deferrable,
            enzyme2 varchar(10) references enzyme(enzyme_name) deferrable,
            user_login varchar(8) references person(login) deferrable,
            digestion_date date
               );
create index digestion_name_I on digestion(name);
grant select on digestion to public;
grant all privileges on digestion to web;

create table ligation (
            id serial primary key,
            name varchar(13) not null unique,
            digestion_name varchar(10) not null references digestion(name) deferrable,
            user_login varchar(8) references person(login) deferrable,
            ligation_date date
                );
create index ligation_name_I on ligation(name);
grant select on ligation to public;
grant all privileges on ligation to web;

create table ipcr (
            id serial primary key,
            name varchar(16) not null unique,
            ligation_name varchar(13) not null references ligation(name) deferrable,
            primer1 varchar(20) not null,
            primer2 varchar(20) not null,
            end_type varchar(4),
            ipcr_date date,
            user_login varchar(8)
               );
create index ipcr_name_I on ipcr(name);
grant select on ipcr to public;
grant all privileges on ipcr to web;
            

create table gel (
            id serial primary key,
            name varchar(10),
            ipcr_id varchar(16) not null references ipcr(name) deferrable,
            gel_date date,
            failure boolean default 'f',
            user_login varchar(8) references person(login) deferrable,
            seq_primer varchar(20)
               );
create index gel_gel_name_I on gel(name);
grant select on gel to public;
grant all privileges on gel to web;

create table lane (
            id serial primary key,
            seq_name varchar(32),
            gel_id int references gel(id) deferrable on delete cascade,
            well varchar(3),
            directory varchar(256) not null,
            file varchar(256) not null,
            lane int,
            run_date datetime,
            end_sequenced varchar(20),
            machine varchar(32)
               );

create index lane_seq_name_I on lane (seq_name);
create index lane_gel_id_I on lane(gel_id);
grant select on lane to public;
grant all privileges on lane to web;

-- the primer to end lookup table. lane and gel do not enforce
-- foreign key constraints in this table; we will still want to
-- process a lane even if the primer is not (yet) in the table
create table primer (
            id serial primary key,
            name varchar(20),
            end_type char(1) not null,
            seq_primer bool not null,
            direction char(1)
                    );
create index primer_seq_primer_I on primer(seq_primer);
grant select on primer to public;
grant all privileges on primer to web;


create table phred_seq (
            id serial primary key,
            lane_id int references lane(id) deferrable on delete cascade,
            q_trim_start int,
            q_trim_end int,
            v_trim_start int,
            v_trim_end int,
            q20 int,
            q30 int,
            seq text
               );
create index phred_seq_lane_id on phred_seq(lane_id);
grant select on phred_seq to public;

create table phred_qual (
            id serial primary key,
            phred_seq_id int references phred_seq(id) deferrable on delete cascade,
            char_per_base int default 2,
            qual text
               );
create index phred_qual_phred_seq_id_I on phred_qual(phred_seq_id);
grant select on phred_qual to public;



-- 
-- Tables related to vector trimming
--
create table vector (
            id serial primary key,
            vector_name varchar(32) unique,
            sequence varchar(255) not null
               );
create index vector_name_I on vector(vector_name);
grant select on vector to public;
grant all privileges on vector to web;

create table trimming_protocol (
             id serial primary key,
             protocol_name varchar(32),
             vector_id int not null references vector(id) deferrable,
             vector_offset int not null default 0,
             insertion_offset int not null default 0
               );
grant select on trimming_protocol to public;
grant all privileges on trimming_protocol to web;

create table collection_protocol (
             id serial primary key,
             collection varchar(4) not null,
             end_sequenced varchar(2) not null default '35',
             protocol_id int not null references trimming_protocol(id) deferrable
               );
create index collection_protocol_collection_I on collection_protocol(collection);
grant select on collection_protocol to public;
grant all privileges on collection_protocol to web;


create table strain (
            strain_name varchar(32) primary key not null unique,
            collection varchar(32),
            registry_date date,
            status varchar(12)
                    );
create index strain_strain_name_I on strain (strain_name);
grant select on strain to public;
grant all privileges on strain to web;

-- control are "special" samples which check for plate orientation
-- we will not process these sequence except to check for orientation
create table control (
            name varchar(32) primary key not null unique references strain(strain_name) deferrable,
            original_strain varchar(32) not null unique references strain(strain_name) deferrable,
            collection varchar(32) not null,
            five_prime_seq varchar(500),
            three_prime_seq varchar(500)
                 );

create index control_name_I on control(name);
grant select on control to public;
grant select on control to web;
             
create table phenotype (
            id serial primary key,
            strain_name varchar(32) not null
                        references strain(strain_name) deferrable,
            is_homozygous_viable char(1),
            is_homozygous_fertile char(1),
            is_multiple_insertion char(1),
            associated_aberration varchar(255),
            phenotype varchar(255),
            derived_cytology varchar(32),
            strain_comment text,
            phenotype_comment text );
create index phenotype_strain_name_I on phenotype(strain_name);
grant select on phenotype to public;
grant all privileges on phenotype to web;


create table strain_comment (
            id serial primary key,
            strain_name varchar(32) not null references strain(strain_name) deferrable,
            author varchar(64) not null references person(login) deferrable,
            date date not null,
            status varchar(64),
            details text
                        );
create index strain_comment_strain_name_I on strain_comment(strain_name);
grant select on strain_comment to public;


create table seq (
            seq_name varchar(32) primary key not null unique,
            strain_name varchar(32) not null references strain(strain_name) deferrable,
            sequence text,
            last_update date not null default 'today'
                  );

create index seq_seq_name_I on seq (seq_name);
create index seq_strain_name_I on seq (strain_name);
grant all privileges on seq to web;
grant all privileges on seq_id_seq to web;


--
-- the seq_assembly table provides the link between the phred_seq
-- and the seq table to show which raw seq were used to create the
-- db seq.

create table seq_assembly (
            phred_seq_id int not null references phred_seq(id),
            seq_name varchar(32) not null references seq(seq_name) deferrable,
            assembly_date date not null default 'today'
                   );
create index seq_assembly_phred_seq_id_I on seq_assembly(phred_seq_id);
create index seq_assembly_seq_name_I on seq_assembly(seq_name);
grant all privileges on seq_assembly to web;
grant select on seq_assembly to public;


grant select on seq to public;

-- blast tables and results

create table blast_run (
            id serial primary key,
            seq_name varchar(32) not null references seq(seq_name) deferrable
                                 on delete cascade,
            db varchar(50) not null,
            date timestamp );

create index blast_run_seq_name_I on blast_run (seq_name);
create index blast_run_db_I on blast_run (db);


create table blast_hit (
            id serial primary key,
            run_id int references blast_run(id) deferrable on delete cascade,
            name varchar(80) not null,
            db varchar(20),
            accession varchar(20),
            description varchar(255) );

create index blast_hit_run_id_I on blast_hit (run_id);
create index blast_hit_name_I on blast_hit (name);

create table blast_hsp (
            id serial primary key,
            hit_id int references blast_hit(id) deferrable on delete cascade,
            score int,
            bits real,
            percent real,
            match int,
            length int,
            query_begin int,
            query_end int,
            subject_begin int,
            subject_end int,
            query_gaps int,
            subject_gaps int,
            p_val double precision,
            query_align text,
            match_align text,
            subject_align text,
            strand int);

create index blast_hsp_hit_id_I on blast_hsp (hit_id);

grant insert on blast_run to web;
grant insert on blast_hit to web;
grant insert on blast_hsp to web;

-- A simplified view to extract blast reports

create view blast_report as select s.id, r.id as run_id, h.id as hit_id, r.seq_name, r.db, h.name,
                score, bits, percent, match, length, query_begin, query_end,
                subject_begin, subject_end, query_gaps, subject_gaps, p_val,
                query_align, match_align, subject_align, strand from blast_run r,
                blast_hit h,  blast_hsp s where h.id=hit_id and r.id=run_id;

grant select on blast_run to public;
grant select on blast_hit to public;
grant select on blast_hsp to public;
grant select on blast_report to public;


create table seq_alignment (
           id serial primary key,
           seq_name varchar(32) not null,
           scaffold varchar(32) not null,
           p_start integer not null,
           p_end integer not null,
           s_start integer not null,
           s_end integer not null,
           s_insert integer not null,
           status varchar(20),
           hsp_id integer references blast_hsp(id) deferrable
                   );

create index seq_alignment_seq_name_I on seq_alignment(seq_name);
create index seq_alignment_scaffold_I on seq_alignment(scaffold);
create index seq_alignment_s_start_I on seq_alignment(s_start);
create index seq_alignment_s_end_I on seq_alignment(s_end);
create index seq_alignment_s_insert_I on seq_alignment(s_insert);
grant select on seq_alignment to public;
grant select on seq_alignment_id_seq to public;


create table alignment_transfer (
           id serial primary key,
           seq_name varchar(32) not null,
           old_scaffold varchar(32) not null,
           old_insert integer not null,
           old_status varchar(20) not null,
           old_release integer not null,
           new_scaffold varchar(32),
           new_insert integer,
           new_status varchar(20),
           new_release integer not null,
           success boolean not null,
           transfer_status varchar(50) not null,
           transfer_timestamp timestamp(0) default current_timestamp );
create index alignment_transfer_seq_name_I on alignment_transfer(seq_name);

create table gene_association (
           id serial primary key,
           strain_name varchar(32) not null,
           cg varchar(32) not null,
           transcript varchar(4),
           login varchar(8) not null references person(login),
           annotation_date date not null default 'today',
           comment text
                     );
           
create index gene_association_strain_name_I on gene_association (strain_name);
create index gene_association_cg_I on gene_association (cg);
grant select on gene_association to public;

create table gadfly_syn (
           pelement_scaffold varchar(32) not null,
           gadfly_scaffold varchar(32) not null
             );
create index gadfly_syn_pelement_scaffold_I on gadfly_syn(pelement_scaffold);
create index gadfly_syn_gadfly_scaffold_I on gadfly_syn(gadfly_scaffold);
grant select on gadfly_syn to public;

create table genbankscaffold (
           accession varchar(32) not null unique,
           arm varchar(32),
           start int,
           stop int,
           cytology varchar(32)
              );

create index genbankscaffold_arm_I on genbankscaffold(arm);
create index genbankscaffold_start_I on genbankscaffold(start);
create index genbankscaffold_stop on genbankscaffold(stop);
grant select on genbankscaffold to public;
grant all privileges on genbankscaffold to web;

create table genbank_submission_info (
           collection varchar(4) not null unique,
           cont_name varchar(64),
           citation varchar(64),
           library varchar(64),
           class varchar(64),
           comment varchar(255)
                 );
grant select on genbank_submission_info to public;

create table cytology (
           scaffold varchar(32) not null,
           start int,
           stop int,
           band varchar(32)
                 );
create index cytology_scaffold_I on cytology(scaffold);
create index cytology_start_I on cytology(start);
create index cytology_stop_I on cytology(stop);
grant select on cytology to public;
grant select on cytology to web;

create table stock_record (
           stock_number int not null,
           strain_name varchar(32),
           genotype varchar(256),
           insertion varchar(32)
                          );
create index stock_record_stock_number_I on stock_record(stock_number);
create index stock_record_strain_name on stock_record(strain_name);
grant select on stock_record to public;

create table flybase_submission_info (
           collection varchar(4) not null unique,
           originating_lab varchar(64),
           contact_person varchar(64),
           contact_person_email varchar(64),
           project_name varchar(64),
           publication_citation varchar(64),
           FBrf varchar(64),
           comment varchar(64),
           transposon_symbol varchar(64)
                         );
grant select on flybase_submission_info to public;


create table submitted_seq (
           seq_name varchar(32) not null references seq(seq_name) deferrable,
           gb_acc varchar(12) not null,
           dbgss_id varchar(12),
           submission_date date
                           );
create index submitted_seq_gb_acc_I on submitted_seq(gb_acc);
grant select on submitted_seq  to public;

create table websession (
           webid char(22) not null unique,
           login varchar(8) not null references person(login) deferrable,
           timestamp integer );

create index websession_webid_I on websession(webid);
create index websession_user_I on websession(login);
grant select on websession to public;

create table webcache (
           id serial primary key,
           script varchar(32) not null,
           param varchar(32) not null,
           format varchar(6) not null default 'html',
           creation_time timestamp not null default 'now',
           expiration timestamp not null default 'infinity'
               );

create index webcache_script_I on webcache(script);
create index webcache_param_I on webcache(param);
grant select on webcache to public;
grant all privileges on webcache to web;
grant all privileges on webcache_id_seq to web;


-- Processing tables
--
-- A table for the processing steps
create table task (
            task_name varchar(24) primary key not null unique,
            next_task varchar(24),
            failure_task varchar(24)
               );
--
-- A table that shows the processing steps of different items
--
create table processing (
            id serial primary key,
            item_id varchar(24) not null,
            item_src varchar(24),
            task_name varchar(24),
            time_entered datetime not null default 'now',
            time_processed datetime,
            process_lock varchar(24)
               );

create index processing_item_name_I on processing (item_id);
create index processing_item_src_I on processing (item_src);
create index processing_task_name_I on processing (task_name);
grant select on processing to public;

grant all on processing_id_seq to web;
grant insert on processing_id_seq to public;
grant insert on processing to web;
grant insert on processing to public;

--
-- sessions is used by the web pages to monitor logins

create table sessions (
             id char(32) not null unique,
             a_session text not null
            );

grant all on sessions to public;


-- views for to-do lists

create view blast_to_do as
select s.seq_name,'all' as "database" from
seq_assembly a,(seq s left join blast_run b on b.seq_name = s.seq_name)
where
(s.seq_name = a.seq_name and
 a.src_seq_src = 'phred_seq' and
 b.seq_name is null)
union
select s.seq_name, b.db as "database" from seq s, blast_run b
where
(s.seq_name = b.seq_name and
 s.last_update > b.date and
 b.program = 'blastn');

grant select on blast_to_do to public;

create view digestion_to_do as
select batch.id as batch, description, batch.user_login, batch_date from
batch left join digestion on batch.id=digestion.batch_id
where
digestion.batch_id is null and
batch.canceled is not true;

grant select on digestion_to_do to public;

create view ligation_to_do as
select digestion.name, digestion.user_login, digestion_date from
digestion left join ligation on digestion.name = ligation.digestion_name
where
ligation.digestion_name is null and
digestion.canceled is not true;

grant select on digestion_to_do to public;

-- is there a way to do this with outer joins?
create view ipcr_to_do as
select ligation.name, ligation.user_login, ligation_date, '3' as end_type from
ligation left join ipcr on ipcr.ligation_name = ligation.name
where
ipcr.ligation_name is null and
ligation.canceled is not true
union
select ligation.name, ligation.user_login, ligation_date,'5' as end_type from
ligation 
where
ligation.name not in (select ligation_name from ipcr where end_type='5') and
ligation.canceled is not true
union
select ligation.name, ligation.user_login, ligation_date,'3' as end_type from
ligation 
where
ligation.name not in (select ligation_name from ipcr where end_type='3') and
ligation.canceled is not true;

grant select on ipcr_to_do to public;

create view gel_to_do as
select ipcr.name, ipcr.user_login, ipcr_date from 
ipcr left join gel on ipcr.name=gel.ipcr_name
where
gel.ipcr_name is null and
ipcr.canceled is not true;

grant select on gel_to_do to public;

create view trace_to_do as
select gel.name,gel.user_login, gel_date from
gel left join lane on gel.id=lane.gel_id
where
lane.gel_id is null and
gel.canceled is not true;

grant select on trace_to_do to public;

-- rules 

create rule batch_insert_R as on insert to batch do
       insert into processing (item_id,item_src,task_name,time_entered,time_processed) values
                                              (new.id,'batch','registered','now','now');
create rule digestion_insert_R as on insert to digestion do
       insert into processing (item_id,item_src,task_name,time_entered,time_processed) values
                                              (new.id,'digestion','registered','now','now');
create rule ligation_insert_R as on insert to ligation do
       insert into processing (item_id,item_src,task_name,time_entered,time_processed) values
                                              (new.id,'ligation','registered','now','now');
create rule ipcr_insert_R as on insert to ipcr do
       insert into processing (item_id,item_src,task_name,time_entered,time_processed) values
                                              (new.id,'ipcr','registered','now','now');

create rule gel_insert_R as on insert to gel do
       insert into processing (item_id,item_src,task_name) values (new.id,'gel','base_call');

create rule phred_seq_insert_R as on insert to phred_seq do
       insert into processing (item_id,item_src,task_name) values (new.id,'phred_seq','seq_trim');
create rule phred_seq_update_R as on update to phred_seq do
       insert into processing (item_id,item_src,task_name) values (old.id,'phred_seq','seq_build');
create rule seq_insert_R as on insert to seq do
       insert into processing (item_id,item_src,task_name) values (new.id,'seq','blast');
create rule seq_update_R as on update to seq do
       insert into processing (item_id,item_src,task_name) values (new.id,'seq','reblast');
create rule blast_update_R as on update to blast_run do
       insert into processing (item_id,item_src,task_name) values (new.id,'blast_run','realign');
create rule blast_insert_R as on insert to blast_run do
       insert into processing (item_id,item_src,task_name) values (new.id,'blast_run','align');

CREATE FUNCTION plpgsql_call_handler() RETURNS language_handler
    AS '$libdir/plpgsql', 'plpgsql_call_handler'
    LANGUAGE 'c';

CREATE TRUSTED PROCEDURAL LANGUAGE plpgsql HANDLER plpgsql_call_handler;

CREATE FUNCTION process_insert(character varying,character varying) RETURNS opaque AS '
  BEGIN
    IF NEW.id IS NULL THEN
      RAISE EXCEPTION ''id cannot be null'';
    END IF;
    INSERT INTO processing (item_id,item_scr,task_name) VALUES (NEW.id,$1,$2);
    RETURN NEW;
  END;
' LANGUAGE 'PLpgSQL';

CREATE TRIGGER blast_insert_T AFTER INSERT OR UPDATE ON blast_run FOR EACH ROW
EXECUTE PROCEDURE process_insert('blast_run','align);

CREATE TRIGGER seq_insert_T AFTER INSERT OR UPDATE ON seq FOR EACH ROW
EXECUTE PROCEDURE process_insert('seq','blast');

CREATE TRIGGER phred_seq_insert_T AFTER INSERT ON phred_seq FOR EACH ROW
EXECUTE PROCEDURE process_insert('phred_seq',seq_trim');

CREATE TRIGGER phred_seq_update_T AFTER UPDATE ON phred_seq FOR EACH ROW
EXECUTE PROCEDURE process_insert('phred_seq',seq_build');

CREATE TRIGGER gel_insert_T AFTER INSERT OR UPDATE ON seq FOR EACH ROW
EXECUTE PROCEDURE process_insert('gel','registered');

CREATE TRIGGER ipcr_insert_T AFTER INSERT OR UPDATE ON seq FOR EACH ROW
EXECUTE PROCEDURE process_insert('ipcr','registered');

CREATE TRIGGER ligation_insert_T AFTER INSERT OR UPDATE ON seq FOR EACH ROW
EXECUTE PROCEDURE process_insert('ligation','registered');

CREATE TRIGGER digestion_insert_T AFTER INSERT OR UPDATE ON seq FOR EACH ROW
EXECUTE PROCEDURE process_insert('digestion','registered');

CREATE TRIGGER batch_insert_T AFTER INSERT OR UPDATE ON seq FOR EACH ROW
EXECUTE PROCEDURE process_insert('batch','registered');

commit;