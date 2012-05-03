#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <regex.h>
#ifdef HAVE_GETOPT
#include <getopt.h>
#endif

#include "fasta_extract.h"

void putchar_rc(char c)
{
   switch (c) {
      case 'A': putchar('T'); break;
      case 'C': putchar('G'); break;
      case 'G': putchar('C'); break;
      case 'T': putchar('A'); break;
      case 'a': putchar('t'); break;
      case 'c': putchar('g'); break;
      case 'g': putchar('c'); break;
      case 't': putchar('a'); break;
      default : putchar(c);
   }
}
void format_print(char *seq,int width,int rev)
{

   int i,j;
   if ( rev ) {
      for(j=0,i=strlen(seq)-1;i>=0;i--) {
         putchar_rc(*(seq+i));
         j++;
         if (!(j%width) ) putchar('\n');
      }
      if (j && j%width) putchar('\n');
    } else {
      for(j=0,i=0;*(seq+i);i++) {
         putchar(*(seq+i));
         j++;
         if (!(j%width) ) putchar('\n');
      }
      if (j%width) putchar('\n');
   }

}
void usage(char *s)
{
   fprintf(stderr,"Usage: %s -i <file> [options]\n",s);
   exit(1);
}

main(int argc, char **argv)
{
   char *seq;
   int start = 0;
   int end = -1;
   int count = 0;
   int rev = 0;
   int width = 50;
   char *pattern = ".";
   char *file = NULL;
   struct extract_info fi;
   int opt;
   int opt_index=0;

#ifdef HAVE_GETOPT
   static struct option cmd_options[] = {
               {"in",1,0,'i'},
               {"baseSkip",1,0,'s'},
               {"baseskip",1,0,'s'},
               {"baseCount",1,0,'c'},
               {"basecount",1,0,'c'},
               {"baseEnd",1,0,'e'},
               {"baseend",1,0,'e'},
               {"pattern",1,0,'p'},
               {"width",1,0,'w'},
               {"rev",0,0,'r'},
               {0,0,0,0}  };
#endif

   bzero(&fi,sizeof(struct extract_info));

   fi.regex_flags = REG_EXTENDED;

   while (1) {
#ifdef HAVE_GETOPT
      opt=getopt_long_only(argc,argv,"i:s:c:e:p:w:r",cmd_options,&opt_index);
#else
      opt=getopt(argc,argv,"i:s:c:e:p:w:r");
#endif

      if (opt==-1 ) break;

      switch (opt) {
         case 's':
            start = atoi(optarg);
            break;
         case 'e':
            end = atoi(optarg);
            break;
         case 'c':
            count = atoi(optarg);
            break;
         case 'w':
            width = atoi(optarg);
            break;
         case 'r':
            rev = 1;
            break;
         case 'p':
            pattern = strdup(optarg);
            break;
         case 'i':
            file = strdup(optarg);
            break;
       }
   }

   if (! file) usage(argv[0]);
   
   for( seq = seq_extract(file,pattern,start,end,&fi); seq != NULL;
        seq = seq_extract(file,pattern,start,end,&fi) ) {
      printf("%s\n",fi.header);
      format_print(seq,width,rev);
   }
}

