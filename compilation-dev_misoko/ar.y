%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "include/token_tab.h"
#include "include/fct_utilitaires.h"
#include "include/quad.h"
extern quad globalcode[100];
extern int nextquad;
extern int ntp;



int yydebug = 1;


void yyerror(char*);
int yylex();
void lex_free();

//********* Declarationde tableau ********

char* id_and_indexs(char *tab_id, char *exprlist){
	char *lvalue = malloc(100);
	sprintf(lvalue, "%s%s", tab_id, exprlist);
	return lvalue;
}

char* all_indexs(quadop* index, char *indexs){
	char *expr_list = malloc(100);
	if(index->type == QO_CST)
		sprintf(expr_list, "[%d]%s", index->u.cst, indexs);
	else
		sprintf(expr_list, "[%s]%s", index->u.name, indexs);	
	return expr_list;
}

char* solo_index(quadop* index){
	char *expr = malloc(100);
	if(index->type == QO_CST)
		sprintf(expr, "[%d]", index->u.cst);
	else
		sprintf(expr, "[%s]", index->u.name);	
	return expr;
}

//*********ADDITION*********

typedef struct dim_list {
	int min_dim;
	int max_dim;
	struct dim_list* next;
} dim_list;

dim_list* add_dim(int dim_inf, int dim_sup){
	dim_list * st_dimension = malloc(sizeof(dim_list)) ;
	st_dimension -> min_dim = dim_inf ;
	st_dimension -> max_dim = dim_sup ;
	st_dimension -> next = NULL ;
	return st_dimension;
}

dim_list* add_dims(dim_list* old_list, int dim_inf, int dim_sup){

    dim_list *loop_dim = old_list;
    while (loop_dim->next != NULL)
        loop_dim = loop_dim -> next;
    loop_dim->next = add_dim(dim_inf, dim_sup);
    return old_list;

}

void print_dims(dim_list* dims_list){

    dim_list *loop_dim = dims_list;
    while (loop_dim->next != NULL)
	{
		printf("dim : %d %d \n", loop_dim->min_dim, loop_dim->max_dim);
        loop_dim = loop_dim->next;
	}
	printf("dim : %d %d \n", loop_dim->min_dim, loop_dim->max_dim);
}
//************************
%}

%union {
	char *strval;
	int intval;
	struct P_symb **psymb;
	struct ident_list* list;
	struct quadop* exprval;
	struct {
		struct lpos* false;
		struct lpos* true;
	} tf;
	struct lpos* lpos;
	int actualquad;
	struct dim_list* dim_list;
}

%token PROGRAM  VAR SARRAY SOF //ADDITION
%token <strval> ID STR 
%token <intval> NUM UNIT BOOL INT
%token INTRV_SEP
%token <intval> PLUS AFFECT TIMES MINUS DIVIDE POWER TRUE FALSE
%token <intval> INF INFEQ SUP SUPEQ DIFF EQ
%token <intval> AND OR XOR NOT

%token SBEGIN SEND WRITE READ
%token IF THEN ELSE ENDIF WHILE DO DONE RETURN


%type <list> identlist
%type <strval> atomictype typename lvalue exprlist
%type <intval> opb oprel
%type <exprval> E
%type <tf> cond
%type <actualquad> M
%type <lpos> instr tag sequence
%type <dim_list> rangelist arraytype //ADDITION


%left INF INFEQ SUP SUPEQ DIFF EQ
%left PLUS MINUS OR XOR
%left TIMES DIVIDE AND
%right POWER
%left NEG NOT


%start program
%%


/* Grammaire à complémenté au fur et à mesure de l'implémentation */
program: PROGRAM ID vardecllist instr
        ;

vardecllist: varsdecl {}
            | varsdecl ';' vardecllist {}
			| {} //element vide
            ;
varsdecl: VAR identlist ':' typename {create_symblist("var",$2, $4);}
		| VAR identlist ':' arraytype {create_symblist("array",$2, "int");}
		;

identlist: ID                 {$$ = create_identlist($1);}
         | identlist ',' ID   {$$ = add_to_identlist($1, $3);}
         ;
 //**********************ADDITION*************************************
typename: atomictype   {$$ = $1;}
		//| arraytype
		;


arraytype : SARRAY '[' rangelist ']' SOF atomictype
			{$$=$3;print_dims($3);};

rangelist : NUM INTRV_SEP NUM { $$ = add_dim($1,$3); }
		| rangelist ',' NUM INTRV_SEP NUM  { $$ = add_dims($1,$3,$5);}
		;

lvalue : ID '[' exprlist ']' { $$ = id_and_indexs($1,$3); };

exprlist : E 				{ $$ = solo_index($1); }
		 | E ',' exprlist  { $$ = all_indexs($1,$3); } ;

//**************************************************************
atomictype: UNIT  {$$ = "unit";}
          | BOOL  {$$ = "bool";}
          | INT   {$$ = "int";}
          ;

instr : lvalue AFFECT E {
			quad q = quad_make(Q_AFFECT, $3, NULL, quadop_name($1));
			gencode(q);
			$$ = crelist(nextquad);
			printf("fin affectation tableau\n");
		}

	  | ID AFFECT E //ID correspond a lvalue sans les listes
	  {
	 	  quad q = quad_make(Q_AFFECT, $3, NULL, quadop_name($1));
	 	  gencode(q);
		  $$ = crelist(nextquad);
		  printf("fin affect\n");
	  }
	  | IF cond THEN M instr ENDIF
	  {
		  complete($2.true,$4);
		  $$ = concat($2.false,crelist(nextquad));
		  printf("fin if\n" );
	  }
	  | IF cond THEN M instr tag ELSE M instr ENDIF
	  {
		  complete($2.true, $4);
		  complete($2.false, $8);
		  $$ = concat($5, $6);
		  $$ = concat($$, crelist(nextquad));
		  quad q = quad_make(Q_GOTO,NULL,NULL,quadop_cst(-1));
		  gencode(q);
	  }
	  | WHILE M cond DO M instr //DONE
	  {
	  		complete($3.true, $5);
			complete($6, $2);
			quad q = quad_make(Q_GOTO,NULL,NULL,quadop_cst($2));
			gencode(q);
			$$ = $3.false;
			printf("fin while\n" );
   		}
	  | RETURN E
	  {
		  quad q = quad_make(Q_RET,NULL,NULL,$2);
		  gencode(q);
	  }
	  | RETURN
	  {
		  quad q = quad_make(Q_RET,NULL,NULL,NULL);
		  gencode(q);
	  }
	  | SBEGIN sequence SEND ';'{$$ = $2;}
	  | SBEGIN SEND  { }
	  | READ ID //lvalue a l'origine, a changer apres les tableaux
	  {
		  quad q = quad_make(Q_READ, NULL, NULL, quadop_name($2));
		  gencode(q);
	  }
	  | WRITE E
	  {
		  quad q = quad_make(Q_WRITE, NULL, NULL, $2);
		  gencode(q);
	  }
	  ;

sequence : instr ';' M sequence {printf("seq%i\n", $1->position);complete($1, $3);$$ = $4;}
		 | instr ';' { $$ = $1; printf(";seq%i\n", $1->position);}
		 | instr { $$ = $1; printf("seq%i\n", $1->position);}
		 ;


E : ID { $$ = quadop_name($1);}
| NUM { $$ = quadop_cst($1);}
| '(' E ')' { $$ = $2;}
| lvalue {$$ = quadop_name($1);}
| E opb E
{
	  quadop* t = new_temp();
	  quad q = quad_make($2, $1, $3, t);
	  gencode(q);
	  $$ = t;
}
| MINUS E %prec NEG
{
	quadop* t = new_temp();
	quad q = quad_make(Q_NEG, $2, NULL, t);
	gencode(q);
	$$ = t;
}
;

cond : cond OR M cond
	{
		$$.true = concat ($1.true, $4.true);
		complete($1.false, $3);
		$$.false = $4.false;
	}
	| cond AND M cond
	{
		$$.false = concat ($1.false, $4.false);
		complete($1.true, $3);
		$$.true = $4.true;
	}
	| NOT cond
	{
		$$.true = $2.false;
		$$.false = $2.true;
	}
	| '(' cond ')'
	{
		$$.true = $2.true;
		$$.false = $2.false;
	}
	| E oprel E
	{
		$$.true = crelist(nextquad);
		quad q = quad_make($2,$1,$3,NULL);
		gencode (q); // if ($1 rel $3)     goto ?
		$$.false = crelist(nextquad);
		quad q2 = quad_make(Q_GOTO,NULL,NULL,quadop_cst(-1));
		gencode(q2);
	}
	| TRUE
	{
		$$.true = crelist(nextquad);
		quad q2 = quad_make(Q_GOTO,NULL,NULL,quadop_cst(-1));
		gencode(q2);
		$$.false = NULL;
	}
	| FALSE
	{
		$$.false = crelist(nextquad);
		quad q2 = quad_make(Q_GOTO,NULL,NULL,quadop_cst(-1));
		gencode(q2);
		$$.true = NULL;
	}
	;

opb : PLUS { $$ = Q_PLUS; }
	| MINUS { $$ = Q_MINUS; }
	| TIMES { $$ = Q_TIMES; }
	| DIVIDE { $$ = Q_DIVIDE; }
	| POWER { $$ = Q_POWER; }
	;

oprel :	INF { $$ = Q_INF; }
	  | INFEQ { $$ = Q_INFEQ; }
	  | SUP { $$ = Q_SUP; }
	  | SUPEQ { $$ = Q_SUPEQ; }
	  | EQ { $$ = Q_EQ; }
	  | DIFF { $$ = Q_DIFF; }

M : { $$ = nextquad;}
;

tag:
{
	  $$ = crelist(nextquad);
	  quad q = quad_make(Q_GOTO,NULL,NULL,quadop_cst(-1));
	  gencode(q);
}
;

%%
void yyerror (char *s) {
	fprintf(stderr, "[Yacc] error: %s\n", s);
}


int main() {
	init_symb_tab();
	printf("Enter your code:\n");

	yyparse();
	printf("-----------------\nSymbol table:\n-----------------\n");
	print_tab();
	printf("Quad list:\n");
	for (int i=0; i<nextquad; i++) {
		printf("%i ", i);
		affiche(globalcode[i]);
	}

	// Be clean.===> Ofc As always
	lex_free();
	return 0;
}

/*
*	Test fonctionnel : creation de variable:
*
*	Ce test contient tout type de symbole afin de recouvrir la totalité
*	des cas : symboles doublons d'indice de hachage mais symb différent,
*	test avec symbole doublon (et donc refus d'ajouter dans la table),
*	ajout symbole classique.
*
*	./ar < file_test/test_declaration_var
*/
