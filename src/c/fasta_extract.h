#ifndef FASTA_EXTRACT_H
#define FASTA_EXTRACT_H
#include <regex.h>

struct extract_info {
    char *header;
    int file_offset;
    int regex_flags;
    regmatch_t *match;
    int n_match;
    int err;
    int flags;
    char *mmem;
};

/* a first guess of header size. This is doubled
   every time we need to exceed this size */
#define HEADERSIZE 200

/* get everything */
#define FSTA_ENTIRE -1

/* eventually, it may be nice to have the ability to keep the
   file open and mapped when iterating. These currently do not
   work - but it doesn't look like a show stopper. */

/* i/o flags */
#define FSTA_NO_OPEN      1
#define FSTA_OPEN_ONLY    (FSTA_NO_OPEN    <<1)
#define FSTA_NO_CLOSE     (FSTA_OPEN_ONLY  <<1)
#define FSTA_CLOSE_ONLY   (FSTA_NO_CLOSE   <<1)
#define ERR_SUPPRESS      (FSTA_CLOSE_ONLY <<1)

/* error flags */
#define NO_MATCH          1
#define OPEN_ERR          (NO_MATCH+1)
#define STAT_ERR          (OPEN_ERR+1)
#define MMAP_ERR          (STAT_ERR+1)
#define REGEXP_COMP_ERR   (MMAP_ERR+1)
#define MALLOC_ERR        (REGEXP_COMP_ERR+1)
#define NO_EOL            (MALLOC_ERR+1)

char *strncpychk(char *,char *,size_t *,size_t);
char *seq_extract(char *,char *,int,int,struct extract_info *);

#endif
