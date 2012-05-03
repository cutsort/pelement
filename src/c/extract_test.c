#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <regex.h>

#include "fasta_extract.h"

main(int argc, char **argv)
{

   char *seq;
   struct extract_info *fi;
   int start,end;
   int i;
   char submatch[80];

   fi = calloc(1,sizeof(struct extract_info));

   if (argc < 5 )  {
      fprintf(stderr,"Usage: %s <pattern> <file> <start> <end>\n",argv[0]);
      exit(2);
   }

   start = atoi(argv[3]);
   end = atoi(argv[4]);

   fi->regex_flags = REG_EXTENDED;
   
   /*for( seq = seq_extract(argv[2],argv[1],start,end,fi); seq != NULL;
        seq = seq_extract(argv[2],argv[1],start,end,fi) ) {
      printf("%s\n",fi->header);
      printf("Seq from %d to %d is %s.\n",start,end,seq);

      for(i=0;i<fi->n_match;i++) {
         memcpy(submatch,fi->header+fi->match[i].rm_so,fi->match[i].rm_eo-fi->match[i].rm_so);
         submatch[fi->match[i].rm_eo-fi->match[i].rm_so] = 0;
         printf("Match %d is to %s\n",i,submatch);
      }
   }*/

   printf("1 match is %s.\n",one_seq_extract(argv[2],argv[1],start,end));

}

