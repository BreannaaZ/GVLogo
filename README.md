# GVLogo
A remake of the classic language Logo; a drawing language with different commands. Also has features such as variables and expressions. Uses flex and bison for lexer and parser and created with C.

Build as follows:
        bison -d gvlogo.y
        flex gvlogo.l
        clang *.c -o gvlogo -lSDL2 -ll -lm
