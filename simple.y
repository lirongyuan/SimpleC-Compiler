/*
 * CS250
 *
 * simple.l: simple parser for the simple "C" language
 *
 */

%token <string_val> WORD
  
  %token  NOTOKEN LPARENT RPARENT LBRACE RBRACE LCURLY RCURLY COMA SEMICOLON EQUAL STRING_CONST LONG LONGSTAR VOID CHARSTAR CHARSTARSTAR INTEGER_CONST AMPERSAND OROR ANDAND EQUALEQUAL NOTEQUAL LESS GREAT LESSEQUAL GREATEQUAL PLUS MINUS TIMES DIVIDE PERCENT IF ELSE WHILE DO FOR CONTINUE BREAK RETURN
  
  %union {
  char   *string_val;
  int nargs;
  int my_nlabel;
}

%{
  #include <stdio.h>
  #include <stdlib.h>
  #include <string.h>
    
  extern int line_number;
  const char * input_file;
  char * asm_file;
  FILE * fasm;
  
  #define MAX_ARGS 5
  int nargs;
  char * args_table[MAX_ARGS];
  
  #define MAX_GLOBALS 100
  int nglobals=0;
  char * global_vars_typetable[MAX_GLOBALS];
  char * global_vars_table[MAX_GLOBALS];
  
  #define MAX_FUNCS 100
  int nfuncs=0;
  int currfunc=0;
  char *funcs_table[MAX_FUNCS];
  char *funcs_returntable[MAX_FUNCS];

  #define MAX_LOCALS 300
  int nlocals=0;
  
  char * local_vars_typetable[MAX_FUNCS][MAX_LOCALS];
  char * local_vars_table[MAX_FUNCS][MAX_LOCALS];
  int local_vars_addtable[MAX_FUNCS][MAX_LOCALS];
  int nlocals_table[MAX_FUNCS];
  
  int nstack=1;
  char * stack_typetable[MAX_LOCALS];
  
  #define MAX_STRINGS 100
  int nstrings=0;
  char * string_table[MAX_STRINGS];

  char *regStk[]={ "rbx", "r10", "r13", "r14", "r15"};
  char nregStk = sizeof(regStk)/sizeof(char*);
  
  char *regArgs[]={ "rdi", "rsi", "rdx", "rcx", "r8", "r9"};
  char nregArgs = sizeof(regArgs)/sizeof(char*);
   
  int nargs =0;
  
  int localtemp=0;  
  //label for equal
  int nlabel = 0; 
  
  //label for while
  int nwhile = 0;

  //label for if
  int nif=0;
  
  //current type
  char* currtype;
  %}

%%
  
  goal: program
  ;
  
  program :
    function_or_var_list;
    
  function_or_var_list:
    function_or_var_list function
    | function_or_var_list global_var
    | /*empty */
    ;
    
  function:
    var_type WORD
  {
  	nlocals=0;
  	currfunc=nfuncs;
	funcs_table[nfuncs]=strdup($<string_val>2);
  	funcs_returntable[nfuncs]=strdup($<string_val>1);
  
	fprintf(fasm,"#func declaration(%s):currfunc=%d\n\n",$<string_val>2,nfuncs);
    fprintf(fasm, "\t.text\n");
    fprintf(fasm, ".globl %s\n", $2);
    fprintf(fasm, "\t.type %s,@function\n", $2);
    fprintf(fasm, "%s:\n", $2);
    
    //use stack
    fprintf(fasm, "\tpushq %%rbp\n");
    fprintf(fasm, "\tmovq %%rsp,%%rbp\n");
    fprintf(fasm, "\tsubq $%d,%%rsp",MAX_LOCALS*8);
  }LPARENT arguments RPARENT{
    int num=$<nargs>5;
    fprintf(fasm,"\t#move args to stack:\n");
    int i;
    for(i=0;i< $<nargs>5;i++){
      fprintf(fasm,"\tmovq %%%s,-%d(%%rbp)\n",regArgs[i],local_vars_addtable[nfuncs][i]);
    }
  }compound_statement{
    //printf("var_type:%s\n",$<string_val>1);
    if(strcmp($<string_val>1,"void")){
    
	}else{
      fprintf(fasm, "\tmovq $0,%%rax\n");
    }
    
    fprintf(fasm, "\tleave\n");
    fprintf(fasm, "\tret\n");
    
	nlocals_table[nfuncs]=nlocals;
    nstack=1;
	nfuncs++;
  }
  ;
  
  arg_list:
    arg{
      $<nargs>$=1;
    }
    | arg_list COMA arg{
      $<nargs>$++;
    }
    ;
    
  arguments:
    arg_list{
      $<nargs>$=$<nargs>1;
    }
    | /*empty*/{
      $<nargs>$=0;
    }
    ;
    
  arg: var_type WORD{
    
    fprintf(fasm, "\t#nstack=%d\n",nstack);
    fprintf(fasm, "\t#add word %s to stack, nlocals=%d\n",$<string_val>2,nlocals);
    
    local_vars_typetable[nfuncs][nlocals]=strdup($<string_val>1);
    local_vars_table[nfuncs][nlocals]=strdup($<string_val>2);
    local_vars_addtable[nfuncs][nlocals]=8*nstack;
    nlocals_table[nfuncs]++;
    stack_typetable[nstack]=strdup($<string_val>1);

    nstack++;
   	fprintf(fasm,"\t#nstack:%d\n\n",nstack);
    nlocals++;

  }
  
  global_var: 
    var_type global_var_list SEMICOLON;
  
  global_var_list: 
    WORD{
    //add it to global var table
    global_vars_typetable[nglobals]=strdup(currtype);
    global_vars_table[nglobals++]=strdup($<string_val>1);
    //add it to asm file
    fprintf(fasm,"\t.comm %s,8,8\n",$<string_val>1);
  }
    | global_var_list COMA WORD { 
    }
    ;
    
  var_type: 
    CHARSTAR{
    $<string_val>$="char*";
	currtype=strdup("char*");
  }| CHARSTARSTAR{
    $<string_val>$="char**";
	currtype=strdup("char**");
  }| LONG{
    $<string_val>$="long";
	currtype=strdup("long");
  }| LONGSTAR{
    $<string_val>$="long*";
	currtype=strdup("long*");
  }| VOID{
    $<string_val>$="void";
	currtype=strdup("void");
  };
  
  assignment:
    WORD EQUAL expression{
    char *id=$<string_val>1;
    int i,found=0;
    //if (id is a global var)
    for(i=0;i<nglobals;i++){
		if(!strcmp(global_vars_table[i],id)){
          fprintf(fasm, "\n\t#global var assignment %s:\n\n",id);
		  fprintf(fasm, "\tmovq -%d(%%rbp),%%r10\n",(nstack-1)*8);
          fprintf(fasm, "\tmovq %%r10,%s\n",id);
          nstack--; found=1;
          fprintf(fasm,"\t#nstack:%d\n\n",nstack);
		  break;
		}
    }
    
    //if (id is a local var)
    if(found==0){
      	for(i=0;i<nlocals_table[currfunc];i++){
      		if(!strcmp(local_vars_table[currfunc][i],id)){
				fprintf(fasm, "\n\t#local var assignment %s:\n\n",id);
     		    fprintf(fasm, "\tmovq -%d(%%rbp),%%r10\n",8*(nstack-1));
     		    fprintf(fasm, "\tmovq %%r10,-%d(%%rbp)\n",local_vars_addtable[currfunc][i]);
     		    nstack--;
     		    fprintf(fasm,"\t#nstack:%d\n\n",nstack);
				found=1;break;
     	 	}
    		}
    }
  }
  | WORD LBRACE expression RBRACE EQUAL expression{
	char *id=$<string_val>1;
	int i,found=0;
	//if id is a global var
	for(i=0;i<nglobals;i++){
			if(!strcmp(global_vars_table[i],id)){
				fprintf(fasm,"\tmovq -%d(%%rbp),%%r10\n",8*(nstack-2));
				if(strcmp(global_vars_typetable[i],"char*")){
					fprintf(fasm,"\timulq $8,%%r10\n");
				}
				fprintf(fasm,"\taddq %s,%%r10\n",id);
				
				fprintf(fasm,"\tmovq -%d(%%rbp),%%r13\n",8*(nstack-1));
				fprintf(fasm,"\tmovq %%r13,(%%r10)\n");
				nstack-=2;
				found=1;break;
			}
	}
	//if id is a local var
	if(found==0){	
		for(i=0;i<nlocals_table[currfunc];i++){
			if(!strcmp(local_vars_table[currfunc][i],id)){
				fprintf(fasm,"\tmovq -%d(%%rbp),%%r10\n",8*(nstack-2));
				if(strcmp(local_vars_typetable[currfunc][i],"char*")){
					fprintf(fasm,"\timulq $8,%%r10\n");
				}
				fprintf(fasm,"\taddq -%d(%%rbp),%%r10\n",local_vars_addtable[currfunc][i]);
			
				fprintf(fasm,"\tmovq -%d(%%rbp),%%r13\n",8*(nstack-1));
				fprintf(fasm,"\tmovq %%r13,(%%r10)\n");
				nstack-=2;
				found=1;break;
			}
		}
	}
  }
  ;
    
  call :
    WORD LPARENT  call_arguments RPARENT {
    char * funcName = $<string_val>1;
    int nargs = $<nargs>3;
    int i;
    int functemp=currfunc;
   
    
    for(i=0;i<nfuncs;i++){
    		if(!strcmp(funcName,funcs_table[i])){
    			currfunc=i;break;
    		}
    }
    fprintf(fasm,"#call_start: currfunc(%s)=%d\n\n",funcName,currfunc);

    fprintf(fasm,"\t# func=%s nargs=%d\n", funcName, nargs);
    fprintf(fasm,"\t# Move values from reg stack to reg args\n");
    
    for (i=nargs-1; i>=0; i--) {
      nstack--;
      fprintf(fasm,"\t#nstack:%d\n\n",nstack);
	  fprintf(fasm, "\tmovq -%d(%%rbp), %%%s\n",
              nstack*8, regArgs[i]);
    }
    
    if (!strcmp(funcName, "printf")) {
      // printf has a variable number of arguments
      // and it need the following
      fprintf(fasm, "\tmovq $0, %%rax\n");
    }
    
    fprintf(fasm, "\tcall %s\n", funcName);
    fprintf(fasm, "\tmovq %%rax, -%d(%%rbp)\n", nstack*8);
    
    for(i=0;i<nfuncs;i++){
    		if(!strcmp(funcName,funcs_table[i])){
    			stack_typetable[nstack]=funcs_returntable[i];
    			break;
    		}
    }
    
    nstack++;
    fprintf(fasm,"\t#nstack:%d\n\n",nstack);
    currfunc=functemp;
  
  	fprintf(fasm,"\t#call_end: currfunc=%d\n",currfunc);
  }
    ;
    
  call_arg_list:
    expression {
    	$<nargs>$=1;
  	}
    | call_arg_list COMA expression {
      	$<nargs>$++;
    }
    
    ;
    
  call_arguments:
    call_arg_list { $<nargs>$=$<nargs>1; }
    | /*empty*/ { $<nargs>$=0;}
    ;
    
  expression :
    logical_or_expr
    ;
    
  logical_or_expr:
    logical_and_expr
    |logical_or_expr OROR logical_and_expr{
    fprintf(fasm,"\t# || operator\n");
    fprintf(fasm,"\tmovq -%d(%%rbp),%%r10\n",8*(nstack-2));
    fprintf(fasm,"\torq %%r10,-%d(%%rbp)\n",8*(nstack-1));
    if(!strcmp(stack_typetable[nstack-1],"char")){
    		fprintf(fasm,"\tcmpb $0,-%d(%%rbp)\n",8*(nstack-1));
    }else{
    		fprintf(fasm,"\tcmpq $0,-%d(%%rbp)\n",8*(nstack-1));
    }
    fprintf(fasm,"\tje equal%d\n",nlabel);
    //not equal--return 1
    fprintf(fasm,"\tmovq $1,-%d(%%rbp)\n",8*(nstack-2));
    fprintf(fasm,"\tjmp equal%dend\n",nlabel);
    //equal--return 0
    fprintf(fasm,"\tequal%d:\n",nlabel);
    fprintf(fasm,"\tmovq $0,-%d(%%rbp)\n",8*(nstack-2));
    fprintf(fasm,"\tequal%dend:\n",nlabel);
    nstack--;
    fprintf(fasm,"\t#nstack:%d\n\n",nstack);
	nlabel++;
  }
    ;
    
  logical_and_expr:
    equality_expr
    | logical_and_expr ANDAND equality_expr{
    fprintf(fasm,"\t# && operator\n");
    fprintf(fasm,"\tmovq -%d(%%rbp),%%r10\n",8*(nstack-2));
    fprintf(fasm,"\tandq %%r10,-%d(%%rbp)\n",8*(nstack-1));
    if(!strcmp(stack_typetable[nstack-1],"char")){
    		fprintf(fasm,"\tcmpb $0,-%d(%%rbp)\n",8*(nstack-1));
    }else{
    		fprintf(fasm,"\tcmpq $0,-%d(%%rbp)\n",8*(nstack-1));
    }
    fprintf(fasm,"\tje equal%d\n",nlabel);
    //not equal--return 1
    fprintf(fasm,"\tmovq $1,-%d(%%rbp)\n",8*(nstack-2));
    fprintf(fasm,"\tjmp equal%dend\n",nlabel);
    //equal--return 0
    fprintf(fasm,"\tequal%d:\n",nlabel);
    fprintf(fasm,"\tmovq $0,-%d(%%rbp)\n",8*(nstack-2));
    fprintf(fasm,"\tequal%dend:\n",nlabel);
    nstack--;
    fprintf(fasm,"\t#nstack:%d\n\n",nstack);
	nlabel++;
  }
    ;
    
  equality_expr:
    relational_expr
    | equality_expr EQUALEQUAL relational_expr{
    fprintf(fasm,"\t# == operator\n");
    fprintf(fasm,"\tmovq -%d(%%rbp),%%r10\n",8*(nstack-2));
    fprintf(fasm,"\tsubq %%r10,-%d(%%rbp)\n",8*(nstack-1));
    if(!strcmp(stack_typetable[nstack-1],"char")){
    		fprintf(fasm,"\tcmpb $0,-%d(%%rbp)\n",8*(nstack-1));
    }else{
    		fprintf(fasm,"\tcmpq $0,-%d(%%rbp)\n",8*(nstack-1));
    }
    fprintf(fasm,"\tje equal%d\n",nlabel);
    //not equal
    fprintf(fasm,"\tmovq $0,-%d(%%rbp)\n",8*(nstack-2));
    fprintf(fasm,"\tjmp equal%dend\n",nlabel);
    //equal
    fprintf(fasm,"\tequal%d:\n",nlabel);
    fprintf(fasm,"\tmovq $1,-%d(%%rbp)\n",8*(nstack-2));
    fprintf(fasm,"\tequal%dend:\n",nlabel);
    nstack--;
    fprintf(fasm,"\t#nstack:%d\n\n",nstack);
	nlabel++;
  }
    | equality_expr NOTEQUAL relational_expr{
      fprintf(fasm,"\t# != operator\n");
      fprintf(fasm,"\tmovq -%d(%%rbp),%%r10\n",8*(nstack-2));
      fprintf(fasm,"\tsubq %%r10,-%d(%%rbp)\n",8*(nstack-1));
      if(!strcmp(stack_typetable[nstack-1],"char")){
      	fprintf(fasm,"\tcmpb $0,-%d(%%rbp)\n",8*(nstack-1));
      }else{
      	fprintf(fasm,"\tcmpq $0,-%d(%%rbp)\n",8*(nstack-1));
      }
      fprintf(fasm,"\tje equal%d\n",nlabel);
      //not equal
      fprintf(fasm,"\tmovq $1,-%d(%%rbp)\n",8*(nstack-2));
      fprintf(fasm,"\tjmp equal%dend\n",nlabel);
      //equal
      fprintf(fasm,"\tequal%d:\n",nlabel);
      fprintf(fasm,"\tmovq $0,-%d(%%rbp)\n",8*(nstack-2));
      fprintf(fasm,"\tequal%dend:\n",nlabel);
      nstack--;
      fprintf(fasm,"\t#nstack:%d\n\n",nstack);
	  nlabel++;
    }
    ;
    
  relational_expr:
    additive_expr
    | relational_expr LESS additive_expr{
    fprintf(fasm,"\t# < operator\n");
    fprintf(fasm,"\tmovq -%d(%%rbp),%%r10\n",8*(nstack-2));
    if(!strcmp(stack_typetable[nstack-1],"char")){
    		fprintf(fasm,"\tcmpb %%r10b,-%d(%%rbp)\n",8*(nstack-1));
    }else{
    		fprintf(fasm,"\tcmpq %%r10,-%d(%%rbp)\n",8*(nstack-1));
    }
    fprintf(fasm,"\tjg equal%d\n",nlabel);
    //not less
    fprintf(fasm,"\tmovq $0,-%d(%%rbp)\n",8*(nstack-2));
    fprintf(fasm,"\tjmp equal%dend\n",nlabel);
    //less
    fprintf(fasm,"\tequal%d:\n",nlabel);
    fprintf(fasm,"\tmovq $1,-%d(%%rbp)\n",8*(nstack-2));
    fprintf(fasm,"\tequal%dend:\n",nlabel);
    nstack--;
    fprintf(fasm,"\t#nstack:%d\n\n",nstack);
	nlabel++;
  }
    | relational_expr GREAT additive_expr{
      fprintf(fasm,"\t# > operator\n");
      fprintf(fasm,"\tmovq -%d(%%rbp),%%r10\n",8*(nstack-2));
      if(!strcmp(stack_typetable[nstack-1],"char")){
      	fprintf(fasm,"\tcmpb %%r10b,-%d(%%rbp)\n",8*(nstack-1));
      }else{
      	fprintf(fasm,"\tcmpq %%r10,-%d(%%rbp)\n",8*(nstack-1));
      }
      fprintf(fasm,"\tjl equal%d\n",nlabel);
      //great
      fprintf(fasm,"\tmovq $0,-%d(%%rbp)\n",8*(nstack-2));
      fprintf(fasm,"\tjmp equal%dend\n",nlabel);
      //not great
      fprintf(fasm,"\tequal%d:\n",nlabel);
      fprintf(fasm,"\tmovq $1,-%d(%%rbp)\n",8*(nstack-2));
      fprintf(fasm,"\tequal%dend:\n",nlabel);
      nstack--;
      fprintf(fasm,"\t#nstack:%d\n\n",nstack);
	  nlabel++;
    }
    | relational_expr LESSEQUAL additive_expr{
      fprintf(fasm,"\t# <= operator\n");
      fprintf(fasm,"\tmovq -%d(%%rbp),%%r10\n",8*(nstack-2));
      if(!strcmp(stack_typetable[nstack-1],"char")){
      	fprintf(fasm,"\tcmpb %%r10b,-%d(%%rbp)\n",8*(nstack-1));
      }else{
      	fprintf(fasm,"\tcmpq %%r10,-%d(%%rbp)\n",8*(nstack-1));
      }
      fprintf(fasm,"\tjge equal%d\n",nlabel);
      //not less equal
      fprintf(fasm,"\tmovq $0,-%d(%%rbp)\n",8*(nstack-2));
      fprintf(fasm,"\tjmp equal%dend\n",nlabel);
      //less equal
      fprintf(fasm,"\tequal%d:\n",nlabel);
      fprintf(fasm,"\tmovq $1,-%d(%%rbp)\n",8*(nstack-2));
      fprintf(fasm,"\tequal%dend:\n",nlabel);
      nstack--;
      fprintf(fasm,"\t#nstack:%d\n\n",nstack);
	  nlabel++;
    }
    | relational_expr GREATEQUAL additive_expr{
      fprintf(fasm,"\t# >= operator\n");
      fprintf(fasm,"\tmovq -%d(%%rbp),%%r10\n",8*(nstack-2));
      if(!strcmp(stack_typetable[nstack-1],"char")){
      	fprintf(fasm,"\tcmpb %%r10b,-%d(%%rbp)\n",8*(nstack-1));
      }else{
      	fprintf(fasm,"\tcmpq %%r10,-%d(%%rbp)\n",8*(nstack-1));
      }
      fprintf(fasm,"\tjle equal%d\n",nlabel);
      //not great equal
      fprintf(fasm,"\tmovq $0,-%d(%%rbp)\n",8*(nstack-2));
      fprintf(fasm,"\tjmp equal%dend\n",nlabel);
      //great equal 
      fprintf(fasm,"\tequal%d:\n",nlabel);
      fprintf(fasm,"\tmovq $1,-%d(%%rbp)\n",8*(nstack-2));
      fprintf(fasm,"\tequal%dend:\n",nlabel);
      nstack--;
      fprintf(fasm,"\t#nstack:%d\n\n",nstack);
	  nlabel++;
    }
    ;
    
  additive_expr:
    multiplicative_expr
    | additive_expr PLUS multiplicative_expr {
    fprintf(fasm,"\n\t# +addition:\n");
    if (nstack<MAX_LOCALS) {
      fprintf(fasm, "\tmovq -%d(%%rbp),%%r10\n",8*(nstack-1));
      fprintf(fasm, "\taddq %%r10,-%d(%%rbp)\n",8*(nstack-2));
      nstack--;
      fprintf(fasm,"\t#nstack:%d\n\n",nstack);
	}
  }
    | additive_expr MINUS multiplicative_expr {
      fprintf(fasm,"\n\t# -substraction:\n");
      if (nstack<=MAX_LOCALS) {
        fprintf(fasm, "\tmovq -%d(%%rbp),%%r10\n",8*(nstack-1));
        fprintf(fasm, "\tsubq %%r10, -%d(%%rbp)\n",8*(nstack-2));
        nstack--;
        fprintf(fasm,"\t#nstack:%d\n\n",nstack);
	  }
    }
    ;
    
  multiplicative_expr:
    primary_expr
    | multiplicative_expr TIMES primary_expr {
    fprintf(fasm,"\n\t# *multiply:\n");
    if (nstack<MAX_LOCALS) {
      fprintf(fasm, "\tmovq -%d(%%rbp),%%rax\n",8*(nstack-1));
      fprintf(fasm, "\timulq -%d(%%rbp)\n", 8*(nstack-2));
      fprintf(fasm, "\tmovq %%rax, -%d(%%rbp)\n", 8*(nstack-2));
      nstack--;
      fprintf(fasm,"\t#nstack:%d\n\n",nstack);
	}
  }
    | multiplicative_expr DIVIDE primary_expr {
      fprintf(fasm,"\n\t# /dividsion:\n");
      if (nstack<MAX_LOCALS) {
        fprintf(fasm, "\tmovq -%d(%%rbp),%%rax\n",8*(nstack-2));
        fprintf(fasm, "\tsarq $63,%%rdx\n");
        fprintf(fasm, "\tidivq -%d(%%rbp)\n", 8*(nstack-1));
        fprintf(fasm, "\tmovq %%rax,-%d(%%rbp)\n",8*(nstack-2));
        fprintf(fasm, "\tmovq $0,%%rax\n");
        fprintf(fasm, "\tmovq $0,%%rdx\n");
        nstack--;
        fprintf(fasm,"\t#nstack:%d\n\n",nstack);
	  }
    }
    | multiplicative_expr PERCENT primary_expr {
      fprintf(fasm,"\n\t# %%modulus:\n");
      if (nstack<MAX_LOCALS) {
        fprintf(fasm, "\tmovq -%d(%%rbp),%%rax\n",8*(nstack-2));
        fprintf(fasm, "\tmovq $0,%%rdx\n");
        fprintf(fasm, "\tsarq $63,%%rdx\n");
        fprintf(fasm, "\tidivq -%d(%%rbp)\n", 8*(nstack-1));
        fprintf(fasm, "\tmovq %%rdx,-%d(%%rbp)\n", 8*(nstack-2));
        fprintf(fasm, "\tmovq $0,%%rax\n");
        fprintf(fasm, "\tmovq $0,%%rdx\n");
        nstack--;
        fprintf(fasm,"\t#nstack:%d\n\n",nstack);
	  }
    }
    ;
    
  primary_expr:
    STRING_CONST {
    // Add string to string table.
    // String table will be produced later
    string_table[nstrings]=$<string_val>1;
    fprintf(fasm, "\t#nstack=%d\n", nstack);
    fprintf(fasm, "\n\t# push string %s nstack=%d\n",
            $<string_val>1, nstack);
    if (nstack<MAX_LOCALS) {
      fprintf(fasm, "\tmovq $string%d, -%d(%%rbp)\n", 
              nstrings, nstack*8);
      //fprintf(fasm, "\tmovq $%s,%%%s\n", 
      //$<string_val>1, regStk[top]);
      stack_typetable[nstack]=strdup("char*");
      nstack++;
	  fprintf(fasm,"\t#nstack:%d\n\n",nstack);
    }
    nstrings++;
  }
    | call
    | WORD {
      fprintf(fasm,"\t#primary_expr: WORD(%s)\n",$<string_val>1);
      // Assume it is a global variable
      char * id = $<string_val>1;
      //look up id in local and global variable table
      //if id is a local var, 
      //read local var from stack and push into stack
      int i,found=0;
      for(i=0;i<nglobals;i++){
          if(!strcmp(global_vars_table[i],id)){
            //push var to stack
            fprintf(fasm,"\tmovq %s,%%r10\n",id);
            fprintf(fasm,"\tmovq %%r10,-%d(%%rbp)\n",nstack*8);
            stack_typetable[nstack]=strdup("char*");
            nstack++;found=1;
            fprintf(fasm,"\t#nstack:%d\n\n",nstack);
			break;
          }
      }
      
      if(found==0){
        for(i=0;i<nlocals_table[currfunc];i++){
        		if(!strcmp(local_vars_table[currfunc][i],id)){
          	  //push var to stack
          	  fprintf(fasm,"\tmovq -%d(%%rbp),%%r10\n",local_vars_addtable[currfunc][i]);
        		  fprintf(fasm,"\tmovq %%r10, -%d(%%rbp)\n",nstack*8);
        		  stack_typetable[nstack]=strdup("char*");
     	      	  found=1;nstack++;
        		  fprintf(fasm,"\t#nstack:%d\n\n",nstack);
				  break;
        		}
      	}	
      }
    }
    | WORD LBRACE expression RBRACE{
    		char *id=$<string_val>1;
		int i,found=0;
		//if id is a global var
		
		for(i=0;i<nglobals;i++){
			if(!strcmp(global_vars_table[i],id)){
				fprintf(fasm,"\tmovq -%d(%%rbp),%%r10\n",8*(nstack-1));
				if(strcmp(global_vars_typetable[i],"char*")){
					fprintf(fasm,"\timulq $8,%%r10\n");
				}
				if(!strcmp(global_vars_typetable[i],"char*")){
					stack_typetable[nstack-1]=strdup("char");
				}else if(!strcmp(global_vars_typetable[i],"char**")){
					stack_typetable[nstack-1]=strdup("char*");
				}else if(!strcmp(global_vars_typetable[i],"long*")){
					stack_typetable[nstack-1]=strdup("long");
				}
				fprintf(fasm,"\taddq %s,%%r10\n",id);
				
				fprintf(fasm,"\tmovq (%%r10),%%r13\n");
				fprintf(fasm,"\tmovq %%r13,-%d(%%rbp)\n",8*(nstack-1));
				found=1;break;
			}
		}
		
		if(found==0){
			//if id is a local var
			for(i=0;i<nlocals_table[currfunc];i++){
				if(!strcmp(local_vars_table[currfunc][i],id)){
					fprintf(fasm,"\tmovq -%d(%%rbp),%%r10\n",8*(nstack-1));
					if(strcmp(local_vars_typetable[currfunc][i],"char*")){
						fprintf(fasm,"\timulq $8,%%r10\n");
					}
					if(!strcmp(local_vars_typetable[currfunc][i],"char*")){
						stack_typetable[nstack-1]=strdup("char");
					}else if(!strcmp(local_vars_typetable[currfunc][i],"char**")){
						stack_typetable[nstack-1]=strdup("char*");
					}else if(!strcmp(local_vars_typetable[currfunc][i],"long*")){
						stack_typetable[nstack-1]=strdup("long");
					}
					fprintf(fasm,"\taddq -%d(%%rbp),%%r10\n",local_vars_addtable[currfunc][i]);
				
					fprintf(fasm,"\tmovq (%%r10),%%r13\n");
					fprintf(fasm,"\tmovq %%r13,-%d(%%rbp)\n",8*(nstack-1));
					found=1;break;
				}
			}
		}
    }
    | AMPERSAND WORD {
    	  fprintf(fasm,"\t#primary_expr: AMPERSAND WORD\n");
		  // Assume it is a global variable
		  char * id = $<string_val>2;
		  //look up id in local and global variable table
		  //if id is a local var, 
		  //read local var from stack and push into stack
		  int i,found=0;
		  for(i=0;i<nglobals;i++){
		      if(!strcmp(global_vars_table[i],id)){
		        //push var to stack
		        fprintf(fasm,"\tmovq $%s,%%r10\n",id);
		        fprintf(fasm,"\tmovq %%r10,-%d(%%rbp)\n",nstack*8);
		        if(!strcmp(global_vars_typetable[i],"char*")){
					stack_typetable[nstack]=strdup("char**");
				}else if(!strcmp(global_vars_typetable[i],"char**")){
					stack_typetable[nstack]=strdup("char***");
				}else if(!strcmp(global_vars_typetable[i],"long*")){
					stack_typetable[nstack]=strdup("long**");
				}else if(!strcmp(global_vars_typetable[i],"long")){
					stack_typetable[nstack]=strdup("long*");
				}
		        nstack++;found=1;
		        fprintf(fasm,"\t#nstack:%d\n\n",nstack);
				break;
		      }
		  }
		  
		  if(found==0){
			for(i=0;i<nlocals_table[currfunc];i++){
		    		if(!strcmp(local_vars_table[currfunc][i],id)){
		      	  //push var to stack
		      	  fprintf(fasm,"\tleaq -%d(%%rbp),%%r10\n",local_vars_addtable[currfunc][i]);
		    		  fprintf(fasm,"\tmovq %%r10, -%d(%%rbp)\n",nstack*8);
		    		  if(!strcmp(local_vars_typetable[currfunc][i],"char*")){
						stack_typetable[nstack]=strdup("char**");
					}else if(!strcmp(local_vars_typetable[currfunc][i],"char**")){
						stack_typetable[nstack]=strdup("char***");
					}else if(!strcmp(local_vars_typetable[currfunc][i],"long*")){
						stack_typetable[nstack]=strdup("long**");
					}else if(!strcmp(local_vars_typetable[currfunc][i],"long")){
						stack_typetable[nstack]=strdup("long*");
					}
		 	      	found=1;nstack++;
		    		fprintf(fasm,"\t#nstack:%d\n\n",nstack);
					break;
		    		}
		  	}	
		  }
    
    }
    | INTEGER_CONST {
      fprintf(fasm, "\n\t# push %s\n", $<string_val>1);
      if (nstack<MAX_LOCALS) {
        fprintf(fasm, "\tmovq $%s,-%d(%%rbp)\n", 
                $<string_val>1, nstack*8);
        stack_typetable[nstack]=strdup("long");
        nstack++;
      	fprintf(fasm,"\t#nstack:%d\n\n",nstack);
	  }
    }
    | LPARENT expression RPARENT
      ;
    
  compound_statement:
    LCURLY statement_list RCURLY
    ;
    
  statement_list:
    statement_list statement
    | /*empty*/
    ;
    
  local_var:
    var_type local_var_list SEMICOLON;
    
  local_var_list: 
    WORD{
    //first local variable
    fprintf(fasm,"\t#add local var %s to table\n",$<string_val>1);
	local_vars_typetable[nfuncs][nlocals]=strdup(currtype);
	local_vars_table[nfuncs][nlocals]=$<string_val>1;
    local_vars_addtable[nfuncs][nlocals]=nstack*8;
    nlocals_table[nfuncs]++;
    stack_typetable[nstack]=strdup(currtype);
    nlocals++;nstack++;
    fprintf(fasm,"\t#nstack:%d\n\n",nstack);
  }
    | local_var_list COMA WORD{
      fprintf(fasm,"\t#add local var %s to table\n",$<string_val>1);
	  local_vars_typetable[nfuncs][nlocals]=strdup(currtype);
	  local_vars_table[nfuncs][nlocals]=$<string_val>3;
      local_vars_addtable[nfuncs][nlocals]=nstack*8;
      nlocals_table[nfuncs]++;
      stack_typetable[nstack]=strdup(currtype);
      nlocals++;nstack++;
	  fprintf(fasm,"\t#nstack:%d\n\n",nstack);
    }
    ;
  
  single_statement:
      assignment SEMICOLON
    | call SEMICOLON
    | local_var
    | IF LPARENT expression RPARENT{
    		$<my_nlabel>1=nif;nif++;
    		if(!strcmp(stack_typetable[nstack-1],"char")){
    			fprintf(fasm, "\tcmpb $0, -%d(%%rbp)\n",8*(nstack-1));
    		}else{
    			fprintf(fasm, "\tcmpq $0, -%d(%%rbp)\n",8*(nstack-1));
    		}
		nstack--;
		fprintf(fasm,"\t#nstack:%d\n\n",nstack);
		fprintf(fasm, "\tje elseif%d\n", $<my_nlabel>1);
    }single_statement{
    		fprintf(fasm, "jmp endif%d\n", $<my_nlabel>1);
    		fprintf(fasm, "elseif%d:\n", $<my_nlabel>1);
    }else_optional{
    		fprintf(fasm, "endif%d:\n", $<my_nlabel>1);
    }
    | IF LPARENT expression RPARENT{
    		$<my_nlabel>1=nif;nif++;
    		if(!strcmp(stack_typetable[nstack-1],"char")){
    			fprintf(fasm, "\tcmpb $0, -%d(%%rbp)\n",8*(nstack-1));
    		}else{
    			fprintf(fasm, "\tcmpq $0, -%d(%%rbp)\n",8*(nstack-1));
    		}
		nstack--;
		fprintf(fasm,"\t#nstack:%d\n\n",nstack);
		fprintf(fasm, "\tje elseif%d\n", $<my_nlabel>1);
    }statement{
    		fprintf(fasm, "jmp endif%d\n", $<my_nlabel>1);
    		fprintf(fasm, "elseif%d:\n", $<my_nlabel>1);
    }else_optional{
    		fprintf(fasm, "endif%d:\n", $<my_nlabel>1);
    }
    | WHILE LPARENT {
		  // act 1
		  $<my_nlabel>1=nwhile;nwhile++;
		  fprintf(fasm, "whileloop%d:\n", $<my_nlabel>1);
		}
		expression RPARENT {
		  // act2
		  if(!strcmp(stack_typetable[nstack-1],"char")){
		  	fprintf(fasm, "\tcmpb $0, -%d(%%rbp)\n",8*(nstack-1));
		  }else{
		  	fprintf(fasm, "\tcmpq $0, -%d(%%rbp)\n",8*(nstack-1));
		  }
		  nstack--;
		  fprintf(fasm,"\t#nstack:%d\n\n",nstack);
		  fprintf(fasm, "\tje endwhileloop%d\n", $<my_nlabel>1);
		}
		statement {
		  // act3
		  fprintf(fasm, "\tjmp whileloop%d\n", $<my_nlabel>1);
		  fprintf(fasm, "endwhileloop%d:\n", $<my_nlabel>1);
    }
    | DO{
    		$<my_nlabel>1=nwhile;nwhile++;
    		fprintf(fasm, "whileloop%d:\n", $<my_nlabel>1);
    }statement WHILE LPARENT expression RPARENT SEMICOLON{
    		if(!strcmp(stack_typetable[nstack-1],"char")){
    			fprintf(fasm, "\tcmpb $0, -%d(%%rbp)\n",8*(nstack-1));
    		}else{
    			fprintf(fasm, "\tcmpq $0, -%d(%%rbp)\n",8*(nstack-1));
    		}
    		nstack--;
		fprintf(fasm,"\t#nstack:%d\n\n",nstack);
		fprintf(fasm, "\tje endwhileloop%d\n", $<my_nlabel>1);
		fprintf(fasm, "\tjmp whileloop%d\n", $<my_nlabel>1);
		fprintf(fasm, "endwhileloop%d:\n", $<my_nlabel>1);
    }
    | FOR LPARENT assignment{
			$<my_nlabel>1=nwhile;nwhile++;
			fprintf(fasm,"\tjmp expression%d\n",$<my_nlabel>1);	
	}SEMICOLON{
    		fprintf(fasm, "\twhileloop%d:\n", $<my_nlabel>1);
			fprintf(fasm, "\tjmp assignment%d\n",$<my_nlabel>1);
    		fprintf(fasm, "\texpression%d:\n",$<my_nlabel>1);
	}expression SEMICOLON{
		if(!strcmp(stack_typetable[nstack-1],"char")){
    			fprintf(fasm, "\tcmpb $0, -%d(%%rbp)\n",8*(nstack-1));
    		}else{
    			fprintf(fasm, "\tcmpq $0, -%d(%%rbp)\n",8*(nstack-1));
    		}	
    		nstack--;
		    fprintf(fasm,"\t#nstack:%d\n\n",nstack);
			fprintf(fasm, "\tje endwhileloop%d\n", $<my_nlabel>1);
			fprintf(fasm, "\tjmp statement%d\n",$<my_nlabel>1);
			fprintf(fasm, "\tassignment%d:\n",$<my_nlabel>1);
    }assignment RPARENT{
			fprintf(fasm,"\t jmp expression%d\n",$<my_nlabel>1);
    		fprintf(fasm,"\tstatement%d:\n",$<my_nlabel>1);
    }statement{
			fprintf(fasm, "\tjmp whileloop%d\n", $<my_nlabel>1);
			fprintf(fasm, "endwhileloop%d:\n", $<my_nlabel>1);
    }
    | jump_statement
      ;
    
  statement:
    assignment SEMICOLON
    | call SEMICOLON
    | local_var
    | compound_statement
    | IF LPARENT expression RPARENT{
    		$<my_nlabel>1=nif;nif++;
    		if(!strcmp(stack_typetable[nstack-1],"char")){
    			fprintf(fasm, "\tcmpb $0, -%d(%%rbp)\n",8*(nstack-1));
    		}else{
    			fprintf(fasm, "\tcmpq $0, -%d(%%rbp)\n",8*(nstack-1));
    		}
		nstack--;
		fprintf(fasm,"\t#nstack:%d\n\n",nstack);
		fprintf(fasm, "\tje elseif%d\n", $<my_nlabel>1);
    }single_statement{
    		fprintf(fasm, "jmp endif%d\n", $<my_nlabel>1);
    		fprintf(fasm, "elseif%d:\n", $<my_nlabel>1);
    }else_optional{
    		fprintf(fasm, "endif%d:\n", $<my_nlabel>1);
    }
    | IF LPARENT expression RPARENT{
    		$<my_nlabel>1=nif;nif++;
    		if(!strcmp(stack_typetable[nstack-1],"char")){
    			fprintf(fasm, "\tcmpb $0, -%d(%%rbp)\n",8*(nstack-1));
    		}else{
    			fprintf(fasm, "\tcmpq $0, -%d(%%rbp)\n",8*(nstack-1));
    		}
		nstack--;
		fprintf(fasm,"\t#nstack:%d\n\n",nstack);
		fprintf(fasm, "\tje elseif%d\n", $<my_nlabel>1);
    }statement{
    		fprintf(fasm, "jmp endif%d\n", $<my_nlabel>1);
    		fprintf(fasm, "elseif%d:\n", $<my_nlabel>1);
    }else_optional{
    		fprintf(fasm, "endif%d:\n", $<my_nlabel>1);
    }
    | WHILE LPARENT {
		  // act 1
		  $<my_nlabel>1=nwhile;nwhile++;
		  fprintf(fasm, "whileloop%d:\n", $<my_nlabel>1);
		}
		expression RPARENT {
		  // act2
		  if(!strcmp(stack_typetable[nstack-1],"char")){
		  	fprintf(fasm, "\tcmpb $0, -%d(%%rbp)\n",8*(nstack-1));
		  }else{
		  	fprintf(fasm, "\tcmpq $0, -%d(%%rbp)\n",8*(nstack-1));
		  }
		  nstack--;
		  fprintf(fasm,"\t#nstack:%d\n\n",nstack);
		  fprintf(fasm, "\tje endwhileloop%d\n", $<my_nlabel>1);
		}
		statement {
		  // act3
		  fprintf(fasm, "\tjmp whileloop%d\n", $<my_nlabel>1);
		  fprintf(fasm, "endwhileloop%d:\n", $<my_nlabel>1);
    }
    | DO{
    		$<my_nlabel>1=nwhile;nwhile++;
    		fprintf(fasm, "whileloop%d:\n", $<my_nlabel>1);
    }statement WHILE LPARENT expression RPARENT SEMICOLON{
    		if(!strcmp(stack_typetable[nstack-1],"char")){
    			fprintf(fasm, "\tcmpb $0, -%d(%%rbp)\n",8*(nstack-1));
    		}else{
    			fprintf(fasm, "\tcmpq $0, -%d(%%rbp)\n",8*(nstack-1));
    		}
    		nstack--;
		fprintf(fasm,"\t#nstack:%d\n\n",nstack);
		fprintf(fasm, "\tje endwhileloop%d\n", $<my_nlabel>1);
		fprintf(fasm, "\tjmp whileloop%d\n", $<my_nlabel>1);
		fprintf(fasm, "endwhileloop%d:\n", $<my_nlabel>1);
    }
    | FOR LPARENT assignment{
			$<my_nlabel>1=nwhile;nwhile++;
			fprintf(fasm,"\tjmp expression%d\n",$<my_nlabel>1);	
	}SEMICOLON{
    		fprintf(fasm, "\twhileloop%d:\n", $<my_nlabel>1);
			fprintf(fasm, "\tjmp assignment%d\n",$<my_nlabel>1);
    		fprintf(fasm, "\texpression%d:\n",$<my_nlabel>1);
	}expression SEMICOLON{
		if(!strcmp(stack_typetable[nstack-1],"char")){
    			fprintf(fasm, "\tcmpb $0, -%d(%%rbp)\n",8*(nstack-1));
    		}else{
    			fprintf(fasm, "\tcmpq $0, -%d(%%rbp)\n",8*(nstack-1));
    		}	
    		nstack--;
		    fprintf(fasm,"\t#nstack:%d\n\n",nstack);
			fprintf(fasm, "\tje endwhileloop%d\n", $<my_nlabel>1);
			fprintf(fasm, "\tjmp statement%d\n",$<my_nlabel>1);
			fprintf(fasm, "\tassignment%d:\n",$<my_nlabel>1);
    }assignment RPARENT{
			fprintf(fasm,"\t jmp expression%d\n",$<my_nlabel>1);
    		fprintf(fasm,"\tstatement%d:\n",$<my_nlabel>1);
    }statement{
			fprintf(fasm, "\tjmp whileloop%d\n", $<my_nlabel>1);
			fprintf(fasm, "endwhileloop%d:\n", $<my_nlabel>1);
    }
    | jump_statement
      ;
    
  else_optional:
    ELSE  statement
    | /* empty */
    ;
    
  jump_statement:
    CONTINUE SEMICOLON{
		fprintf(fasm, "\tjmp whileloop%d\n",nwhile-1);
	}
    | BREAK SEMICOLON{
		fprintf(fasm, "\tjmp endwhileloop%d\n",nwhile-1);
	}
    | RETURN expression SEMICOLON {
	fprintf(fasm, "\n\t#return expression\n\n");
    fprintf(fasm, "\tmovq -%d(%%rbp), %%rax\n",8*(nstack-1));
    fprintf(fasm, "\tleave\n");
	fprintf(fasm, "\tret\n");
  }
    ;
    
    %%
      
      void yyset_in (FILE *  in_str );
    
    int
      yyerror(const char * s)
    {
      fprintf(stderr,"%s:%d: %s\n", input_file, line_number, s);
    }
    
    
    int
      main(int argc, char **argv)
    {
      //printf("-------------WARNING: You need to implement global and local vars ------\n");
      //printf("------------- or you may get problems with top------\n");
      
      // Make sure there are enough arguments
      if (argc <2) {
        fprintf(stderr, "Usage: simple file\n");
        exit(1);
      }
      
      // Get file name
      input_file = strdup(argv[1]);
      
      int len = strlen(input_file);
      if (len < 2 || input_file[len-2]!='.' || input_file[len-1]!='c') {
        fprintf(stderr, "Error: file extension is not .c\n");
        exit(1);
      }
      
      // Get assembly file name
      asm_file = strdup(input_file);
      asm_file[len-1]='s';
      
      // Open file to compile
      FILE * f = fopen(input_file, "r");
      if (f==NULL) {
        fprintf(stderr, "Cannot open file %s\n", input_file);
        perror("fopen");
        exit(1);
      }
      
      // Create assembly file
      fasm = fopen(asm_file, "w");
      if (fasm==NULL) {
        fprintf(stderr, "Cannot open file %s\n", asm_file);
        perror("fopen");
        exit(1);
      }
      
      // Uncomment for debugging
      //fasm = stderr;
      
      // Create compilation file
      // 
      yyset_in(f);
      yyparse();
      
      // Generate string table
      int i;
      for (i = 0; i<nstrings; i++) {
        fprintf(fasm, "string%d:\n", i);
        fprintf(fasm, "\t.string %s\n\n", string_table[i]);
      }
      
      fclose(f);
      fclose(fasm);
      
      return 0;
    }
    
