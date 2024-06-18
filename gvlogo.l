/*
 * gvlogo.l is the flex code for the lexer for
 * gvlogo. gvlogo consists of multiple drawing commands
 * as well as basic arithmetic commands and basic float variables.
 *
 * Base code by Professor Ira Woodring
 * Updated and added to by Breanna Zinky
 * Date: 11/12/2023
 */

%{
#include <stdio.h>
#include <stdlib.h>
#include "gvlogo.tab.h"

extern void yyerror(const char* s);
%}

%%

; 			{ return SEP; }
penup			{ return PENUP; }
pendown 		{ return PENDOWN; }
print			{ return PRINT; }
color			{ return COLOR; }
clear			{ return CLEAR; }
turn			{ return TURN; }
move			{ return MOVE; }
[0-9]+\.[0-9]+|\.?[0-9]+ { yylval.f = atof(yytext); return NUMBER; }
end			{ return END; }
save			{ return SAVE; }
goto			{ return GOTO; }
where			{ return WHERE; }
\+			{ return PLUS; }
\-			{ return SUB; }
\*			{ return MULT; }
\/			{ return DIV; }
\= 			{ return EQUALS; }
[A-Za-z]+		{ yylval.s = yytext; return STRING; }
$[A-Z]			{ yylval.v = yytext[1]; return VARIABLE; /* Sets yylval.v to only the actual character after the $. */ }
[ \t\r\n]		{ ; }
.			{ yyerror("Lexing Syntax error.\n"); } 

%%
