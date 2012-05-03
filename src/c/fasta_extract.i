%module fasta_extract
%{
#include "fasta_extract.h"
%}
char *seq_extract(char *s,char *t,int,int,struct extract_info*i=0);
%inline %{
struct extract_info *get_info() {
   return (struct extract_info *)malloc(sizeof(struct extract_info));
}
%}
%include fasta_extract.h

