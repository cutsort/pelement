/* fasta_extract

   a routine for ripping snippets of sequence out of a multisequence fasta
   file with POSIX regular expressions and memory mapped file i (not i/o, just i).

   In normal operation seq_extract(file,pattern,start,end,NULL) will
   return the sequence of the first entry that matches pattern in file
   between the (interbase) coordinates start and end. The value FSTA_ENTIRE
   (defined in fasta_extract.h) for the end coordinate will give the whole sequence.

   FSTA_ENTIRE is -1; in general, negative coordinates are the seq coordinates
   from the end of the sequence.

   For detailed informaton of the matching, or for iterating over successive
   matches, the 5th argument is a extract_info structure that contains elements
   for the actual header matched, and the position of the subexpressions, the offset
   within the file to start looking (on input) or the high water mark that was
   scanned (on output) and flags for processing and detailed error flags.
 
   A file offset member of the data structure is (on input) the starting location
   from which to look and (on output) the starting point for the next searching
   point when iterating over matches.

   On successful completion, a pointer to a malloc'ed char is returned. This must be
   free'ed by the caller to prevent memory leaks.  NULL value indicates an error. The
   error is printed to stdout (unless specified to supress in the flags) and an error
   value is set in the extract_info structure. If the coordinates are specified with
   end < start, a zero length string is returned.

*/

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <regex.h>
#include <errno.h>

#include "fasta_extract.h"

char *seq_extract(char *file,char *pat,int start,int end,struct extract_info *f_i)
{

   extern int errno;                 /* external error number         */
   int in_fd;                        /* file descriptor for i/o       */
   struct stat stat_buf;             /* we'll want the file size      */
   char *src;                        /* mapped input buffer           */
   char *header;                     /* a copy of the header          */
   size_t header_size;                  /* size allocated for the header */
   char *seq_p;                      /* a pointer to a seq            */
   char *next_seq;                   /* a pointer to the next seq     */
   char *next_new;                   /* a pointer to next newline     */
   char *last_new;
   char *cp_start;
   char *cp_end;
   char *seq;                        /* a pointer to the returned seq */
   off_t file_size;                  /* size of input file            */
   off_t offset;                     /* skip this much of the file    */
   long seq_size;                    /* size of the seq to write      */
   long base_ctr;
   long read_offset;

/* a macro for the size of the remainder of the file given a pointer */
#define REMAIN(a) (file_size - ((a)-src))

   regex_t reg;
   regmatch_t *regmatch;
   int reg_err;
   int n_sub;
   int report_err;

   char *header_end;
   size_t header_len;
   int headerSize;
   long copied = 0;

   int baseCount;

   /* see if we want to start looking at a particular place */
   if( f_i ) {
      offset = f_i->file_offset;
      report_err = !(f_i->flags & ERR_SUPPRESS);
   } else {
      offset = 0;
      report_err = 1;
   }

   if ( f_i && (f_i->flags & FSTA_NO_OPEN)) {
      src = f_i->mmem;
   } else {
      /* file opening */
      if( (in_fd = open(file,O_RDONLY)) == -1) {
         if (f_i) f_i->err = OPEN_ERR;
         if (report_err) fprintf(stderr,"File open failed on %s.\n",file);
         return NULL;
      }
   
      /* we need the file size */
      if ( fstat(in_fd,&stat_buf) == -1 ) {
         if (f_i) f_i->err = STAT_ERR;
         if (report_err) fprintf(stderr,"Stat error on file %s.\n",file);
         /* if we can't stat it, close it, regardless of the flag. */
         close(in_fd);
         return NULL;
      }
      file_size = stat_buf.st_size;
   
      /* mmap it */
      if((src = mmap(0,file_size,PROT_READ,MAP_SHARED,in_fd,0)) == MAP_FAILED) {
         if (f_i) f_i->err = MMAP_ERR;
         if (report_err) fprintf(stderr,"Mmap failed on file %s. errno=%d.\n",file,errno);
         /* if we can't map it, close it, regardless of the flag. */
         close(in_fd);
         return NULL;
      }
   }

   if ( f_i && (f_i->flags & FSTA_OPEN_ONLY) ) {
      f_i->mmem = src;
      f_i->err = 0;
      return NULL;
   }

   /* prepare the space for the header */
   if ( (header=(char *)malloc(HEADERSIZE*sizeof(char))) == NULL) {
      if (f_i) f_i->err = MALLOC_ERR;
      if (report_err) fprintf(stderr,"Trouble in malloc.\n");
      close(in_fd);
      return NULL;
   }
   header_size = HEADERSIZE;

   /* compile regexps and prepare for substring matches. */
   if ((reg_err=regcomp(&reg,pat,(f_i && f_i->regex_flags)?f_i->regex_flags:0))
                                                                        != 0 ) {
      if (f_i) f_i->err = REGEXP_COMP_ERR;
      if (report_err) fprintf(stderr,
                      "Error compiling regular expression: errno=%d.",reg_err);
      regfree(&reg);
      return NULL;
   }

   /* we will attempt to reuse old values if possible */
   if( f_i == NULL) {
      /* with no fasta info struct, we will not find subexpression matches. */
      n_sub = 0;
      regmatch = NULL;
   } else if (reg.re_nsub && f_i->n_match < reg.re_nsub+1) {
      /* we're asking for more this time */
      free(f_i->match);
      if( (regmatch=(regmatch_t *)malloc((reg.re_nsub+1)*sizeof(regmatch_t))) == NULL) {
         f_i->err = MALLOC_ERR;
         if (report_err) fprintf(stderr,"Trouble in malloc.\n");
         regfree(&reg);
         return NULL;
      }
      n_sub = reg.re_nsub;
      f_i->n_match = n_sub+1;
      f_i->match = regmatch;
   } else {
      regmatch = f_i->match;
      n_sub = reg.re_nsub;
      f_i->n_match = n_sub;
   } 


   /* let's start looking. seq_p points to where we're
      starting, and remaining is how much we have to do */
   seq_p = src + offset;

   /* loop. advance to the next fasta header */
   while ( (seq_p=memchr(seq_p,'>',REMAIN(seq_p))) != NULL ) {

      /* make sure this really is the start of a line. */
      if (seq_p > src && seq_p[-1] != '\n') {
         seq_p++;
         continue;
      }

      header_end = memchr(seq_p,'\n',REMAIN(seq_p));

      /* we really should always find this unless file is trash */
      if (header_end == NULL) {
         if ( f_i ) f_i->err = NO_EOL;
         if ( report_err ) fprintf(stderr,"Cannot find terminator of header. Corrupt file?\n");
         regfree(&reg);
         return NULL;
      }

      /* we're NOT including the newline in the header. */
      header_len = header_end - seq_p;
      header = strncpychk(header,seq_p,&header_size,header_len);
      if (header_size == 0 ) {
         f_i->err = MALLOC_ERR;
         if (report_err) fprintf(stderr,"Trouble in malloc.\n");
         close(in_fd);
         return NULL;
      }

      /* now see if the header matches */
      if( regexec(&reg,header,n_sub,regmatch,0)==0 ) {
         /* it does. This is where the sequence starts */
         seq_p = header_end+1;
         if ( (next_seq=memchr(seq_p,'>',REMAIN(seq_p))) != NULL ) {
            seq_size = next_seq - seq_p;
         } else {
            seq_size = REMAIN(seq_p);
            next_seq = src + file_size;
         }


         /* we scan through the sequence to count the number of
            newlines. While doing so, we keep track of the line
            that starts right before the start of the sequence. */
            
         cp_start = seq_p + start;
         last_new = seq_p - 1;
         base_ctr = 0;
         read_offset = 0;
         for(next_new = memchr(seq_p,'\n',REMAIN(seq_p));
             next_new != NULL && next_new < next_seq;
             next_new = memchr(next_new+1,'\n',REMAIN(next_new+1)) ) {
             seq_size--;
             base_ctr += next_new - last_new - 1;
             last_new = next_new;
             if (base_ctr < start ) {
                /* this is a bogus value every time except for the last */
                cp_start = next_new + (start - base_ctr) + 1;
             }
             /* we might be able to short circuit the counting */
             if (end>0 && base_ctr>=start) break;
         }

         if( end > 0 && end < seq_size ) {
            seq_size = end;
         } 

         if( start > 0 ) {
            seq_size -= start;
         }

         /* if we've asked for nothing, we return a zero length
            string - not a NULL. this is not an error */
         if (seq_size <= 0 ) {
            seq = (char *)malloc(sizeof(char));
            *seq = 0;
            break;
         } else {
            seq = (char *)malloc((seq_size+1)*sizeof(char));
         
            do {
               cp_end = memchr(cp_start,'\n',REMAIN(cp_start));
               if ( copied + cp_end - cp_start > seq_size) {
                  cp_end = cp_start + seq_size - copied;
               }
               memcpy(seq+copied,cp_start,cp_end-cp_start);
               copied += cp_end - cp_start;
               /* if the last character is numeric, then this
                  is a quality file. Add a space to keep things from
                  munging together */
               if (*(cp_end-1) >= '0' && *(cp_end-1) <= '9') {
                 memcpy(seq+copied+(cp_end-cp_start)," ",1);
                 seq_size++;
                 copied++;
               }
               /* advance to 1 char beyond the newline */
               cp_start = cp_end + 1;
            } while (copied < seq_size);
   
            seq[seq_size] = 0;

            /* we're done here */
         }

         /* final clean ups
         /* make sure the errors are cleared and offset is updated */
         if ( f_i ) {
            f_i->err = 0;
            f_i->file_offset = next_seq - src;
            f_i->header = strdup(header);
            if (!(f_i->flags & FSTA_NO_CLOSE)) {
               munmap(src,file_size);
               close(in_fd);
               f_i->mmem = 0;
            } else {
               f_i->mmem = src;
            }
         }
         return seq;

      }
      seq_p++;
   }


   /* nothing was found */
   if ( f_i ) {
      f_i->file_offset = file_size;
      f_i->header = NULL;
      f_i->err = NO_MATCH;
      if (!(f_i->flags & FSTA_NO_CLOSE)) {
         munmap(src,file_size);
         close(in_fd);
         f_i->mmem = 0;
      } else {
         f_i->mmem = src;
      }
   } else {
      close(in_fd);
   }
   return NULL;
}

/* a version of stdncpy which checks the allocated size of
   the destination and reallocs as needed.
   This returns the allocated size of the destination; a value
   of zero indicates a malloc error. */

char *strncpychk(char *dest,char *src,size_t *alloc,size_t n)
{
   char *end;
   char *cp;

   end = memchr(src,0,n);

   while ( (end==NULL && n+1 > *alloc) || (end!=NULL && end-src>*alloc) )  { 
      *alloc = 2*(*alloc);
      cp = (char *)malloc(*alloc*sizeof(char));
      if (cp==NULL) return 0;
      free(dest);
      dest = cp;
   }
 
   memcpy(dest,src,n);
   dest[n] = 0;
   return dest;
}

