/*
 * gvlogo.y is the bison code for the parser for
 * gvlogo. gvlogo consists of multiple drawing commands 
 * as well as basic arithmetic commands and basic float variables.
 *
 * Base code by Professor Ira Woodring
 * Updated and added to by Breanna Zinky
 * Date: 11/12/2023
 */

%{
#define WIDTH 640
#define HEIGHT 480

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <SDL2/SDL.h>
#include <SDL2/SDL_thread.h>

static SDL_Window* window;
static SDL_Renderer* rend;
static SDL_Texture* texture;
static SDL_Thread* background_id;
static SDL_Event event;
static int running = 1;
static const int PEN_EVENT = SDL_USEREVENT + 1;
static const int DRAW_EVENT = SDL_USEREVENT + 2;
static const int COLOR_EVENT = SDL_USEREVENT + 3;

typedef struct color_t {
	unsigned char r;
	unsigned char g;
	unsigned char b;
} color;

static color current_color;
static double x = WIDTH / 2;
static double y = HEIGHT / 2;
static int pen_state = 1;
static double direction = 0.0;

int yylex(void);
int yyerror(const char* s);
void startup();
int run(void* data);
void prompt();
void penup();
void pendown();
void move(int num);
void turn(int dir);
void output(const char* s);
void change_color(int r, int g, int b);
void clear();
void save(const char* path);
void shutdown();
void where();
void go_to(int x, int y);

// Struct and array for variables
// Program allows for 26 variables named A-Z that hold a float value.
// Variables are accessed with a $ before their name.
typedef struct Variable {
	float value;
	char name;
} Variable;
Variable numVars[26]; // This array will hold the 26 Variables (struct) named A-Z (0-25). 

%}

%union {
	float f;
	char* s;
	char v; // Holds the character name of a variable which can be A-Z
}

%locations

%token SEP
%token PENUP
%token PENDOWN
%token PRINT
%token COLOR
%token CLEAR
%token TURN
%token MOVE
%token<f> NUMBER
%token END
%token SAVE
%token GOTO
%token WHERE
%token PLUS SUB MULT DIV EQUALS
%token<v> VARIABLE
%token<s> STRING QSTRING
%type<f> expression expression_list variable_or_num

%%

program:	        statement_list END				{ printf("Program complete.\n"); shutdown(); exit(0); }
		;
statement_list:		statement					
		|	statement statement_list
		;
statement:		command SEP					{ prompt(); }
		|	error SEP					{ yyerrok; prompt(); } // Changed to SEP instead of '\n' since '\n' wasn't properly being recognized and letting input continue after
		;
command:		PENUP						{ penup(); }
       		|	PENDOWN						{ pendown(); }
		|	PRINT STRING					{ printf("%s", $2);}
		|	SAVE STRING					{ save($2); }
		|	COLOR NUMBER NUMBER NUMBER			{ change_color($2, $3, $4); }
		| 	CLEAR						{ clear(); }
		| 	TURN variable_or_num				{ turn($2); }
		| 	MOVE variable_or_num				{ move($2); }
		|	GOTO variable_or_num variable_or_num		{ go_to($2, $3); }
		|	WHERE						{ where(); }
		|	VARIABLE EQUALS expression_list			{ numVars[$1 - 65].name = $1; numVars[$1 - 65].value = $3; } // Store expression to a variable
		|	expression_list 
		;
expression_list:	expression					{ printf("%g\n", $$); }
		|	expression expression_list
		;
expression:		variable_or_num PLUS expression			{ $$ = $1 + $3; }
	  	|	variable_or_num MULT expression			{ $$ = $1 * $3; }
		|	variable_or_num SUB expression			{ $$ = $1 - $3; }
		|	variable_or_num DIV expression			{ $$ = $1 / $3; }
		|	variable_or_num					{ $$ = $1; }
		;
variable_or_num:	NUMBER						{ $$ = $1; }
		|	VARIABLE					{ $$ = numVars[$1 - 65].value; } // Used indexing like this to be able to easily map the char to the array index. The char $1 is converted to its hex value.
		;
%%

int main(int argc, char** argv){
	startup();
	return 0;
}

int yyerror(const char* s){
	printf("Error: %s\n", s);
	return -1;
};

void prompt(){
	printf("gv_logo > ");
}

void penup(){
	event.type = PEN_EVENT;		
	event.user.code = 0;
	SDL_PushEvent(&event);
}

void pendown() {
	event.type = PEN_EVENT;		
	event.user.code = 1;
	SDL_PushEvent(&event);
}

void move(int num){
	event.type = DRAW_EVENT;
	event.user.code = 1;
	event.user.data1 = num;
	SDL_PushEvent(&event);
}

void turn(int dir){
	event.type = PEN_EVENT;
	event.user.code = 2;
	event.user.data1 = dir;
	SDL_PushEvent(&event);
}

void output(const char* s){
	printf("%s\n", s);
}

void change_color(int r, int g, int b){
	event.type = COLOR_EVENT;
	current_color.r = r;
	current_color.g = g;
	current_color.b = b;
	SDL_PushEvent(&event);
}

void clear(){
	event.type = DRAW_EVENT;
	event.user.code = 2;
	SDL_PushEvent(&event);
}

void startup(){
	SDL_Init(SDL_INIT_VIDEO);
	window = SDL_CreateWindow("GV-Logo", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, WIDTH, HEIGHT, SDL_WINDOW_SHOWN);
	if (window == NULL){
		yyerror("Can't create SDL window.\n");
	}
	
	//rend = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_TARGETTEXTURE);
	rend = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE | SDL_RENDERER_TARGETTEXTURE);
	SDL_SetRenderDrawBlendMode(rend, SDL_BLENDMODE_BLEND);
	texture = SDL_CreateTexture(rend, SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_TARGET, WIDTH, HEIGHT);
	if(texture == NULL){
		printf("Texture NULL.\n");
		exit(1);
	}
	SDL_SetRenderTarget(rend, texture);
	SDL_RenderSetScale(rend, 3.0, 3.0);

	background_id = SDL_CreateThread(run, "Parser thread", (void*)NULL);
	if(background_id == NULL){
		yyerror("Can't create thread.");
	}
	while(running){
		SDL_Event e;
		while( SDL_PollEvent(&e) ){
			if(e.type == SDL_QUIT){
				running = 0;
			}
			if(e.type == PEN_EVENT){
				if(e.user.code == 2){
					double degrees = ((int)e.user.data1) * M_PI / 180.0;
					direction += degrees;
				}
				pen_state = e.user.code;
			}
			if(e.type == DRAW_EVENT){
				if(e.user.code == 1){
					int num = (int)event.user.data1;
					double x2 = x + num * cos(direction);
					double y2 = y + num * sin(direction);
					if(pen_state != 0){
						SDL_SetRenderTarget(rend, texture);
						SDL_RenderDrawLine(rend, x, y, x2, y2);
						SDL_SetRenderTarget(rend, NULL);
						SDL_RenderCopy(rend, texture, NULL, NULL);
					}
					x = x2;
					y = y2;
				} else if(e.user.code == 2){
					SDL_SetRenderTarget(rend, texture);
					SDL_RenderClear(rend);
					SDL_SetTextureColorMod(texture, current_color.r, current_color.g, current_color.b);
					SDL_SetRenderTarget(rend, NULL);
					SDL_RenderClear(rend);
				} else if (e.user.code == 3){// NEW CODE for go_to function 
                      			// Check if pen is down to draw
                                        if(pen_state != 0){ // If so, create line from original x,y to new x,y
                                                SDL_SetRenderTarget(rend, texture);
                                                SDL_RenderDrawLine(rend, x, y, (int)event.user.data1, (int)event.user.data2);
                                                SDL_SetRenderTarget(rend, NULL);
                                                SDL_RenderCopy(rend, texture, NULL, NULL);
                                        }
					// Now actually update x and y
                                        x = (int)event.user.data1; 
                                        y = (int)event.user.data2;
				}
			}
			if(e.type == COLOR_EVENT){
				SDL_SetRenderTarget(rend, NULL);
				SDL_SetRenderDrawColor(rend, current_color.r, current_color.g, current_color.b, 255);
			}
			if(e.type == SDL_KEYDOWN){
			}

		}
		//SDL_RenderClear(rend);
		SDL_RenderPresent(rend);
		SDL_Delay(1000 / 60);
	}
}

int run(void* data){
	prompt();
	yyparse();
	return 0;
}

void shutdown(){
	running = 0;
	SDL_WaitThread(background_id, NULL);
	SDL_DestroyWindow(window);
	SDL_Quit();
}

void save(const char* path){
	SDL_Surface *surface = SDL_CreateRGBSurface(0, WIDTH, HEIGHT, 32, 0, 0, 0, 0);
	SDL_RenderReadPixels(rend, NULL, SDL_PIXELFORMAT_ARGB8888, surface->pixels, surface->pitch);
	SDL_SaveBMP(surface, path);
	SDL_FreeSurface(surface);
}

// Implement the following two functions: goto and where
// Where prints the current coordinates (x, y) that the pen is at.
void where(){
	printf("Current coordinates: (%g, %g)\n", x, y);
}

// Goto moves to a particular coordinate. Draws if the pen is down, otherwise does not.
void go_to(int newX, int newY){
	// Following code selects the event you want, sets the type member, fills the type member with info
	// then places the event onto the event queue.
	// The handling of the event (what happens) is controlled in the startup function.
	event.type = DRAW_EVENT;
        event.user.code = 3; 
        event.user.data1 = newX;
	event.user.data2 = newY;
        SDL_PushEvent(&event); 
}
