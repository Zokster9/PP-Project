%{
  #include <stdio.h>
  #include <stdlib.h>
  #include <string.h>
  #include "defs.h"
  #include "symtab.h"
  #include "codegen.h"

  int yyparse(void);
  int yylex(void);
  int yyerror(char *s);
  void warning(char *s);

  extern int yylineno;
  int out_lin = 0;
  char char_buffer[CHAR_BUFFER_LENGTH];
  int error_count = 0;
  int warning_count = 0;
  int var_num = 0;
  int heaps[100][50];
  int heap_declarations[100];
  int heap_num = 0;
  int fun_idx = -1;
  int fcall_idx = -1;
  int lab_num = -1;
  FILE *output;
%}

%union {
  int i;
  char *s;
}

%token <i> _TYPE
%token _IF
%token _ELSE
%token _RETURN
%token <s> _ID
%token <s> _INT_NUMBER
%token <s> _UINT_NUMBER
%token _LPAREN
%token _RPAREN
%token _LBRACKET
%token _RBRACKET
%token _ASSIGN
%token _SEMICOLON
%token _CREATE_HEAP
%token _SIZE
%token _DOT
%token _IS_EMPTY
%token _PUSH
%token _ROOT
%token _POP
%token <i> _AROP
%token <i> _RELOP

%type <i> num_exp exp literal
%type <i> function_call argument rel_exp if_part

%nonassoc ONLY_IF
%nonassoc _ELSE

%%

program
  : function_list
      {  
        if(lookup_symbol("main", FUN) == NO_INDEX)
          err("undefined reference to 'main'");
      }
  ;

function_list
  : function
  | function_list function
  ;

function
  : _TYPE _ID
      {
        fun_idx = lookup_symbol($2, FUN);
        if(fun_idx == NO_INDEX)
          fun_idx = insert_symbol($2, FUN, $1, NO_ATR, NO_ATR);
        else 
          err("redefinition of function '%s'", $2);

        code("\n%s:", $2);
        code("\n\t\tPUSH\t%%14");
        code("\n\t\tMOV \t%%15,%%14");
      }
    _LPAREN parameter _RPAREN body
      {
        clear_symbols(fun_idx + 1);
        var_num = 0;
        
        code("\n@%s_exit:", $2);
        code("\n\t\tMOV \t%%14,%%15");
        code("\n\t\tPOP \t%%14");
        code("\n\t\tRET");
      }
  ;

parameter
  : /* empty */
      { set_atr1(fun_idx, 0); }

  | _TYPE _ID
      {
        insert_symbol($2, PAR, $1, 1, NO_ATR);
        set_atr1(fun_idx, 1);
        set_atr2(fun_idx, $1);
      }
  ;

body
  : _LBRACKET variable_list
      {
        if(var_num) 
        {
          if (heap_num)
          {
            int places = (var_num - heap_num) + heap_num * 50;
            code("\n\t\tSUBS\t%%15,$%d,%%15", 4*places);
          }
          else
          {
            code("\n\t\tSUBS\t%%15,$%d,%%15", 4*var_num);
          }
        }
        code("\n@%s_body:", get_name(fun_idx));
      }
    statement_list _RBRACKET
  ;

variable_list
  : /* empty */
  | variable_list variable
  ;

variable
  : _TYPE _ID _SEMICOLON
      {
        if(lookup_symbol($2, VAR|PAR|HEAP) == NO_INDEX)
        {
          if ($1 == HEAP_VAR)
            err("Heap '%s' is declared incorrectly", $2);
          else
          {
            var_num++;
            int place = (var_num - heap_num) + heap_num * 50;
            insert_symbol($2, VAR, $1, place, NO_ATR);
          }
        }
        else
          err("redefinition of '%s'", $2);
      }
  | _TYPE _ID _ASSIGN _CREATE_HEAP _LPAREN _RPAREN _SEMICOLON
      {
        if(lookup_symbol($2, VAR|PAR|HEAP) == NO_INDEX) 
        {
          var_num++;
          int place = (var_num - heap_num) + heap_num * 50;
          int idx = insert_symbol($2, HEAP, 1, place, 0);
          heap_declarations[heap_num] = idx;
          heap_num++;
        }
        else
          err("redefinition of '%s'", $2);
      }
  ;

statement_list
  : /* empty */
  | statement_list statement
  ;

statement
  : compound_statement
  | assignment_statement
  | if_statement
  | return_statement
  | heap_push_statement
  | heap_pop_statement
  ;

heap_push_statement
  : _ID _DOT _PUSH _LPAREN literal _RPAREN _SEMICOLON
      {
        int idx = lookup_symbol($1, HEAP);
        if (idx == NO_INDEX)
          err("heap '%s' is undeclared", $1);
        if (get_type($5) != get_type(idx))
          err("incompatible types in assignment");
        if (get_atr2(idx) == 50)
          err("heap '%s' reached its capacity!", $1);
        int heap_idx = 0;
        for (int i = 0; i < heap_num; i++) {
          if (idx == heap_declarations[i]) {
            heap_idx = i;
            break;
          }
        }
        int size = get_atr2(idx);
        int new_elem = atoi(get_name($5));
        int new_elem_idx = size;
        heaps[heap_idx][new_elem_idx] = new_elem;
        set_atr2(idx, ++size);
        int place = (get_atr1(idx) + new_elem_idx) * 4;
        code("\n\t\tMOV\t\t$%d,-%d(%%14)", new_elem, place);
        if (size != 1)
        {
          while(1)
          {
            int parent_elem = heaps[heap_idx][(new_elem_idx - 1) / 2];
            if (parent_elem <= new_elem)
            {
              break;
            }
            heaps[heap_idx][(new_elem_idx - 1) / 2] = new_elem;
            heaps[heap_idx][new_elem_idx] = parent_elem;

            int reg = take_reg();
            int parent_place = (get_atr1(idx) + (new_elem_idx - 1) / 2) * 4;
            int new_elem_place = (get_atr1(idx) + new_elem_idx) * 4;
            code("\n\t\tMOV\t\t-%d(%%14),", parent_place);
            gen_sym_name(reg);

            code("\n\t\tMOV\t\t-%d(%%14),-%d(%%14)", new_elem_place, parent_place);
            
            code("\n\t\tMOV\t\t");
            gen_sym_name(reg);
            code(",-%d(%%14)", new_elem_place);
            free_if_reg(reg);

            if (new_elem_idx == 0)
              break;
            new_elem_idx = (new_elem_idx - 1) / 2;
          }
        }
      }
  ;

heap_pop_statement
  : _ID _DOT _POP _LPAREN _RPAREN _SEMICOLON
      {
        int idx = lookup_symbol($1, HEAP);
        if (idx == NO_INDEX)
          err("heap '%s' is undeclared", $1);
        if (get_atr2(idx) == 0)
          err("heap '%s' is empty", $1);
        int heap_idx = 0;
        for (int i = 0; i < heap_num; i++) 
        {
          if (idx == heap_declarations[i])
          {
            heap_idx = i;
            break;
          }
        }
        
        int size = get_atr2(idx);
        int last_element_place = (get_atr1(idx) + size - 1) * 4;
        int root_element_place = get_atr1(idx) * 4;
        heaps[heap_idx][0] = heaps[heap_idx][size - 1];
        heaps[heap_idx][size - 1] = 0;
        code("\n\t\tMOV\t\t-%d(%%14),-%d(%%14)", last_element_place, root_element_place);
        code("\n\t\tMOV\t\t$0,-%d(%%14)", last_element_place);
        size--;
        set_atr2(idx, size);
        int i = 0;
        while(1)
        {
          int propagation_elem = heaps[heap_idx][i];
          int left_child_idx = 2 * i + 1;
          int right_child_idx = 2 * i + 2;
          int left_child = -1;
          int right_child = -1;
          if (left_child_idx < size)
            left_child = heaps[heap_idx][left_child_idx];
          if (right_child_idx < size)
            right_child = heaps[heap_idx][right_child_idx];
          if (left_child == -1 && right_child == -1)
            break;
          else if (left_child == -1 && right_child != -1)
          {
            if (propagation_elem > right_child)
            {
              int elem = heaps[heap_idx][i];
              heaps[heap_idx][i] = heaps[heap_idx][right_child_idx];
              heaps[heap_idx][right_child_idx] = elem;

              int reg = take_reg();
              int propagation_elem_place = (get_atr1(idx) + i) * 4;
              int right_child_place = (get_atr1(idx) + right_child_idx) * 4;
              code("\n\t\tMOV\t\t-%d(%%14),", propagation_elem_place);
              gen_sym_name(reg);

              code("\n\t\tMOV\t\t-%d(%%14),-%d(%%14)", right_child_place, propagation_elem_place);
              
              code("\n\t\tMOV\t\t");
              gen_sym_name(reg);
              code(",-%d(%%14)", right_child_place);
              free_if_reg(reg);
              i = right_child_idx;
            }
            else
              break;
          }
          else if (left_child != -1 && right_child == -1)
          {
            if (propagation_elem > left_child)
            {
              int elem = heaps[heap_idx][i];
              heaps[heap_idx][i] = heaps[heap_idx][left_child_idx];
              heaps[heap_idx][left_child_idx] = elem;

              int reg = take_reg();
              int propagation_elem_place = (get_atr1(idx) + i) * 4;
              int left_child_place = (get_atr1(idx) + left_child_idx) * 4;
              code("\n\t\tMOV\t\t-%d(%%14),", propagation_elem_place);
              gen_sym_name(reg);

              code("\n\t\tMOV\t\t-%d(%%14),-%d(%%14)", left_child_place, propagation_elem_place);
              
              code("\n\t\tMOV\t\t");
              gen_sym_name(reg);
              code(",-%d(%%14)", left_child_place);
              free_if_reg(reg);
              i = left_child_idx;
            }
            else
              break;
          }
          else if (left_child != -1 && right_child != -1)
          {
            if (left_child < right_child)
            {
              if (propagation_elem > left_child)
              {
                int elem = heaps[heap_idx][i];
                heaps[heap_idx][i] = heaps[heap_idx][left_child_idx];
                heaps[heap_idx][left_child_idx] = elem;

                int reg = take_reg();
                int propagation_elem_place = (get_atr1(idx) + i) * 4;
                int left_child_place = (get_atr1(idx) + left_child_idx) * 4;
                code("\n\t\tMOV\t\t-%d(%%14),", propagation_elem_place);
                gen_sym_name(reg);

                code("\n\t\tMOV\t\t-%d(%%14),-%d(%%14)", left_child_place, propagation_elem_place);
                
                code("\n\t\tMOV\t\t");
                gen_sym_name(reg);
                code(",-%d(%%14)", left_child_place);
                free_if_reg(reg);
                i = left_child_idx;
              }
              else
                break;
            }
            else if (right_child <= left_child)
            {
              if (propagation_elem > right_child)
              {
                int elem = heaps[heap_idx][i];
                heaps[heap_idx][i] = heaps[heap_idx][right_child_idx];
                heaps[heap_idx][right_child_idx] = elem;

                int reg = take_reg();
                int propagation_elem_place = (get_atr1(idx) + i) * 4;
                int right_child_place = (get_atr1(idx) + right_child_idx) * 4;
                code("\n\t\tMOV\t\t-%d(%%14),", propagation_elem_place);
                gen_sym_name(reg);

                code("\n\t\tMOV\t\t-%d(%%14),-%d(%%14)", right_child_place, propagation_elem_place);
                
                code("\n\t\tMOV\t\t");
                gen_sym_name(reg);
                code(",-%d(%%14)", right_child_place);
                free_if_reg(reg);
                i = right_child_idx;
              }
              else
                break;
            }
          }
        }
      }

compound_statement
  : _LBRACKET statement_list _RBRACKET
  ;

assignment_statement
  : _ID _ASSIGN num_exp _SEMICOLON
      {
        int idx = lookup_symbol($1, VAR|PAR);
        if(idx == NO_INDEX)
          err("invalid lvalue '%s' in assignment", $1);
        else
          if(get_type(idx) != get_type($3))
            err("incompatible types in assignment");
        gen_mov($3, idx);
      }
  ;

num_exp
  : exp

  | num_exp _AROP exp
      {
        if(get_type($1) != get_type($3))
          err("invalid operands: arithmetic operation");
        int t1 = get_type($1);    
        code("\n\t\t%s\t", ar_instructions[$2 + (t1 - 1) * AROP_NUMBER]);
        gen_sym_name($1);
        code(",");
        gen_sym_name($3);
        code(",");
        free_if_reg($3);
        free_if_reg($1);
        $$ = take_reg();
        gen_sym_name($$);
        set_type($$, t1);
      }
  ;

exp
  : literal

  | _ID _DOT _POP _LPAREN _RPAREN
      {
        int idx = lookup_symbol($1, HEAP);
        if (idx == NO_INDEX)
          err("heap '%s' is undeclared", $1);
        if (get_atr2(idx) == 0)
          err("heap '%s' is empty", $1);
        int heap_idx = 0;
        for (int i = 0; i < heap_num; i++) 
        {
          if (idx == heap_declarations[i])
          {
            heap_idx = i;
            break;
          }
        }
        
        int size = get_atr2(idx);
        int last_element_place = (get_atr1(idx) + size - 1) * 4;
        int root_element_place = get_atr1(idx) * 4;
        heaps[heap_idx][0] = heaps[heap_idx][size - 1];
        heaps[heap_idx][size - 1] = 0;
        int reg = take_reg();
        set_type(reg, INT);
        code("\n\t\tMOV\t\t-%d(%%14),", root_element_place);
        gen_sym_name(reg);
        code("\n\t\tMOV\t\t-%d(%%14),-%d(%%14)", last_element_place, root_element_place);
        code("\n\t\tMOV\t\t$0,-%d(%%14)", last_element_place);
        size--;
        set_atr2(idx, size);
        int i = 0;
        while(1)
        {
          int propagation_elem = heaps[heap_idx][i];
          int left_child_idx = 2 * i + 1;
          int right_child_idx = 2 * i + 2;
          int left_child = -1;
          int right_child = -1;
          if (left_child_idx < size)
            left_child = heaps[heap_idx][left_child_idx];
          if (right_child_idx < size)
            right_child = heaps[heap_idx][right_child_idx];
          if (left_child == -1 && right_child == -1)
            break;
          else if (left_child == -1 && right_child != -1)
          {
            if (propagation_elem > right_child)
            {
              int elem = heaps[heap_idx][i];
              heaps[heap_idx][i] = heaps[heap_idx][right_child_idx];
              heaps[heap_idx][right_child_idx] = elem;

              int reg = take_reg();
              int propagation_elem_place = (get_atr1(idx) + i) * 4;
              int right_child_place = (get_atr1(idx) + right_child_idx) * 4;
              code("\n\t\tMOV\t\t-%d(%%14),", propagation_elem_place);
              gen_sym_name(reg);

              code("\n\t\tMOV\t\t-%d(%%14),-%d(%%14)", right_child_place, propagation_elem_place);
              
              code("\n\t\tMOV\t\t");
              gen_sym_name(reg);
              code(",-%d(%%14)", right_child_place);
              free_if_reg(reg);
              i = right_child_idx;
            }
            else
              break;
          }
          else if (left_child != -1 && right_child == -1)
          {
            if (propagation_elem > left_child)
            {
              int elem = heaps[heap_idx][i];
              heaps[heap_idx][i] = heaps[heap_idx][left_child_idx];
              heaps[heap_idx][left_child_idx] = elem;

              int reg = take_reg();
              int propagation_elem_place = (get_atr1(idx) + i) * 4;
              int left_child_place = (get_atr1(idx) + left_child_idx) * 4;
              code("\n\t\tMOV\t\t-%d(%%14),", propagation_elem_place);
              gen_sym_name(reg);

              code("\n\t\tMOV\t\t-%d(%%14),-%d(%%14)", left_child_place, propagation_elem_place);
              
              code("\n\t\tMOV\t\t");
              gen_sym_name(reg);
              code(",-%d(%%14)", left_child_place);
              free_if_reg(reg);
              i = left_child_idx;
            }
            else
              break;
          }
          else if (left_child != -1 && right_child != -1)
          {
            if (left_child < right_child)
            {
              if (propagation_elem > left_child)
              {
                int elem = heaps[heap_idx][i];
                heaps[heap_idx][i] = heaps[heap_idx][left_child_idx];
                heaps[heap_idx][left_child_idx] = elem;

                int reg = take_reg();
                int propagation_elem_place = (get_atr1(idx) + i) * 4;
                int left_child_place = (get_atr1(idx) + left_child_idx) * 4;
                code("\n\t\tMOV\t\t-%d(%%14),", propagation_elem_place);
                gen_sym_name(reg);

                code("\n\t\tMOV\t\t-%d(%%14),-%d(%%14)", left_child_place, propagation_elem_place);
                
                code("\n\t\tMOV\t\t");
                gen_sym_name(reg);
                code(",-%d(%%14)", left_child_place);
                free_if_reg(reg);
                i = left_child_idx;
              }
              else
                break;
            }
            else if (right_child <= left_child)
            {
              if (propagation_elem > right_child)
              {
                int elem = heaps[heap_idx][i];
                heaps[heap_idx][i] = heaps[heap_idx][right_child_idx];
                heaps[heap_idx][right_child_idx] = elem;

                int reg = take_reg();
                int propagation_elem_place = (get_atr1(idx) + i) * 4;
                int right_child_place = (get_atr1(idx) + right_child_idx) * 4;
                code("\n\t\tMOV\t\t-%d(%%14),", propagation_elem_place);
                gen_sym_name(reg);

                code("\n\t\tMOV\t\t-%d(%%14),-%d(%%14)", right_child_place, propagation_elem_place);
                
                code("\n\t\tMOV\t\t");
                gen_sym_name(reg);
                code(",-%d(%%14)", right_child_place);
                free_if_reg(reg);
                i = right_child_idx;
              }
              else
                break;
            }
          }
        }
        $$ = reg;
      }
  | _ID _DOT _ROOT _LPAREN _RPAREN
      {
        $$ = lookup_symbol($1, HEAP);
        if ($$ == NO_INDEX)
          err("heap '%s' is undeclared", $1);
        if (get_atr2($$) == 0)
          err("heap '%s' is empty", $1);
      }
  
  | _ID _DOT _SIZE _LPAREN _RPAREN
      {
        int idx = lookup_symbol($1, HEAP);
        if (idx == NO_INDEX)
          err("heap '%s' is undeclared", $1);
        char* string = NULL;
        char* s = NULL;
        s = malloc(sizeof(char *) * 15);
        int num = get_atr2(idx);
        snprintf(s, 11, "%d", num);
        string = malloc(sizeof(char *) * 11);
        strcpy(string, s);
        free(s);
        int lit = insert_literal(string, INT);
        $$ = lit;
      }
  
  | _ID _DOT _IS_EMPTY _LPAREN _RPAREN
      {
        int idx = lookup_symbol($1, HEAP);
        if (idx == NO_INDEX)
          err("heap '%s' is undeclared", $1);
        int num;
        if (get_atr2(idx) == 0)
          num = 1;
        else
          num = 0;
        char* string = NULL;
        char* s = NULL;
        s = malloc(sizeof(char *) * 15);
        snprintf(s, 11, "%d", num);
        string = malloc(sizeof(char *) * 11);
        strcpy(string, s);
        free(s);
        int lit = insert_literal(string, INT);
        $$ = lit;
      }

  | _ID
      {
        $$ = lookup_symbol($1, VAR|PAR|HEAP);
        if($$ == NO_INDEX)
          err("'%s' undeclared", $1);
        if (get_kind($$) == HEAP)
          err("'%s' heap unsupported use!", $1);
      }

  | function_call
      {
        $$ = take_reg();
        gen_mov(FUN_REG, $$);
      }
  
  | _LPAREN num_exp _RPAREN
      { $$ = $2; }
  ;

literal
  : _INT_NUMBER
      { $$ = insert_literal($1, INT); }

  | _UINT_NUMBER
      { $$ = insert_literal($1, UINT); }
  ;

function_call
  : _ID 
      {
        fcall_idx = lookup_symbol($1, FUN);
        if(fcall_idx == NO_INDEX)
          err("'%s' is not a function", $1);
      }
    _LPAREN argument _RPAREN
      {
        if(get_atr1(fcall_idx) != $4)
          err("wrong number of arguments");
        code("\n\t\t\tCALL\t%s", get_name(fcall_idx));
        if($4 > 0)
          code("\n\t\t\tADDS\t%%15,$%d,%%15", $4 * 4);
        set_type(FUN_REG, get_type(fcall_idx));
        $$ = FUN_REG;
      }
  ;

argument
  : /* empty */
    { $$ = 0; }

  | num_exp
    { 
      if(get_atr2(fcall_idx) != get_type($1))
        err("incompatible type for argument");
      free_if_reg($1);
      code("\n\t\t\tPUSH\t");
      gen_sym_name($1);
      $$ = 1;
    }
  ;

if_statement
  : if_part %prec ONLY_IF
      { code("\n@exit%d:", $1); }

  | if_part _ELSE statement
      { code("\n@exit%d:", $1); }
  ;

if_part
  : _IF _LPAREN
      {
        $<i>$ = ++lab_num;
        code("\n@if%d:", lab_num);
      }
    rel_exp
      {
        code("\n\t\t%s\t@false%d", opp_jumps[$4], $<i>3);
        code("\n@true%d:", $<i>3);
      }
    _RPAREN statement
      {
        code("\n\t\tJMP \t@exit%d", $<i>3);
        code("\n@false%d:", $<i>3);
        $$ = $<i>3;
      }
  ;

rel_exp
  : num_exp _RELOP num_exp
      {
        if(get_type($1) != get_type($3))
          err("invalid operands: relational operator");
        $$ = $2 + ((get_type($1) - 1) * RELOP_NUMBER);
        gen_cmp($1, $3);
      }
  ;

return_statement
  : _RETURN num_exp _SEMICOLON
      {
        if(get_type(fun_idx) != get_type($2))
          err("incompatible types in return");
        gen_mov($2, FUN_REG);
        code("\n\t\tJMP \t@%s_exit", get_name(fun_idx));        
      }
  ;

%%

int yyerror(char *s) {
  fprintf(stderr, "\nline %d: ERROR: %s", yylineno, s);
  error_count++;
  return 0;
}

void warning(char *s) {
  fprintf(stderr, "\nline %d: WARNING: %s", yylineno, s);
  warning_count++;
}

int main() {
  int synerr;
  init_symtab();
  output = fopen("output.asm", "w+");

  synerr = yyparse();

  clear_symtab();
  fclose(output);
  
  if(warning_count)
    printf("\n%d warning(s).\n", warning_count);

  if(error_count) {
    remove("output.asm");
    printf("\n%d error(s).\n", error_count);
  }

  if(synerr)
    return -1;  //syntax error
  else if(error_count)
    return error_count & 127; //semantic errors
  else if(warning_count)
    return (warning_count & 127) + 127; //warnings
  else
    return 0; //OK
}

