//
// Grammar for plpgsql Postgres 9.1
//
grammar PlPgSql;

import LexerRules;

varExpr          : QNAME | ID | ANONYMOUS_PARAMETER;

functionCallExpr : functionCallName=ID L_BRACKET R_BRACKET
                 | functionCallName=ID L_BRACKET expression  (',' expression)*  R_BRACKET
				 ;


// -- definition of numeric constants
// -- see http://www.postgresql.org/docs/9.1/static/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS
// -- Examples:
// REAL '1.23'  -- string style
// 1.23::REAL   -- PostgreSQL (historical) style
numericConstant : value=( INTEGER_VALUE | DECIMAL_VALUE ) '::' type=(ID | QNAME | ARRAY_TYPE | COPY_TYPE | ROW_TYPE)
				| typeName=(ID | QNAME | ARRAY_TYPE | COPY_TYPE | ROW_TYPE) QUOTE value=( INTEGER_VALUE | DECIMAL_VALUE ) QUOTE
				;




// -- definition of constants of other types
// -- see http://www.postgresql.org/docs/9.1/static/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS
// -- Examples:
// type 'string'
// 'string'::type
// CAST ( 'string' AS type )
constantOfOtherTypes : type=(ID | QNAME | ARRAY_TYPE | COPY_TYPE | ROW_TYPE) value=STRING
				     | value=STRING '::' type=(ID | QNAME | ARRAY_TYPE | COPY_TYPE | ROW_TYPE)
				     | CAST L_BRACKET value=STRING AS type=(ID | QNAME | ARRAY_TYPE | COPY_TYPE | ROW_TYPE) R_BRACKET
				     ;



numericalLiteralExpr : numericConstant       			  			 # numericalConstantExpression
			  		 | INTEGER_VALUE  					   			 # integerLiteral
	  		  		 | DECIMAL_VALUE						   		 # decimalLiteral
   	 		  		 ;


booleanLiteralExpr  : NOT expression		# negateExpression
					| value=(TRUE | FALSE)  # booleanLiteral
					;

// TODO Not finished yet
// OVERLAPS expression: http://www.postgresql.org/docs/9.1/static/functions-datetime.html
// -- expression definitions
// http://www.postgresql.org/docs/8.2/static/functions-comparison.html
// http://www.postgresql.org/docs/9.1/interactive/sql-syntax-lexical.html#SQL-SYNTAX-OPERATORS
expression  : functionCallExpr                     					# functionCallExpression
			| L_BRACKET expression R_BRACKET                   					# expressionGroup
			| expression  ('[' arrayIndexExpr=expression ']')+  	# arrayAccessExpression
    		| varExpr                             					# variableExpression
		    | booleanLiteralExpr                          			# booleanLiteralExpression
	        | numericalLiteralExpr						   		    # numericalLiteralExpression
	        | STRING          			     			            # stringLiteralExpression
			| expression  operator=EQ  					 expression   # comparisonExpression
			| expression  operator=NEQ 					 expression   # comparisonExpression
			| expression  operator=LT  					 expression   # comparisonExpression
			| expression  operator=LTE 					 expression   # comparisonExpression
			| expression  operator=GT  					 expression   # comparisonExpression
			| expression  operator=GTE 					 expression   # comparisonExpression

			// TODO these definitions are NOT COMPLETE yet
			| expression  (not=NOT)? operator=LIKE           STRING   # comparisonExpression
			| expression  (not=NOT)? operator=SIMILAR TO     STRING   # comparisonExpression

		    | unaryOperator=ADD<assoc=right> 			 expression   # unaryExpression
			| unaryOperator=SUB<assoc=right> 			 expression   # unaryExpression
			| expression operator=MUL      				 expression   # mulExpression
			| expression operator=DIV      				 expression   # divExpression
		 	| expression operator=MOD      				 expression   # modExpression
			| expression operator=ADD      				 expression   # addExpression
		 	| expression operator=SUB      				 expression   # subExpression
		 	| expression  '^'<assoc=right> expression   			  # exponentiationExpression
	        | constantOfOtherTypes  			  					# arbitraryConstantExpression
	        | expression AS label=ID   							    # labelExpression
			| expression  operator=IN   expression # inExpression
			| expression  operator=AND  expression # logicalConjunctionExpression
			| expression  operator=OR   expression # logicalConjunctionExpression
	  		| select                               # subQueryExpression
	  		| caseExpr                             # caseExpression
	  		| subject=expression operator=BETWEEN left=expression AND right=expression # betweenExpression
	  		;


condition : expression ;



// ---------
// -- parser rules
// ---------

// -- the entry point
unit        : plFunction+; // each file has at least one function definition


// ---------
// -- http://www.postgresql.org/docs/9.1/static/sql-createfunction.html
// -- NOTE: for now, the specification is not fully matched (the parts following after ROWS definition are omitted)
// ---------


plFunction         : CREATE (OR REPLACE)? FUNCTION functionName=ID L_BRACKET functionArgsList R_BRACKET functionReturns functionBody LANGUAGE LANGUAGE_NAME functionSettings? ';';
functionArgsList   : ( functionArg (',' functionArg)* )? ;

functionArg        : (argMode=(IN | OUT | INOUT | VARIADIC))? argName=ID type=(ID | QNAME | ARRAY_TYPE)   ( initOperator=( DEFAULT | ASSIGN_OP | EQ ) expression )?;


functionReturns    : RETURNS type=(ID | QNAME | ARRAY_TYPE | COPY_TYPE | ROW_TYPE)
				   | RETURNS (type=(ID | QNAME | ARRAY_TYPE | COPY_TYPE | ROW_TYPE) outName=ID)+
				   ;


functionBody       : F_DOLLAR_QUOTE blockStmt DOLLAR_QUOTE
				   | F_QUOTE        blockStmt QUOTE
				   ;




blockStmt          : (DECLARE varDeclarationList)* BEGIN  stmts (EXCEPTION exceptionHandlingBlock)?  END ';';

exceptionHandlingBlock  : (WHEN  exceptionWhenConditions THEN stmts)* stmts;
exceptionWhenConditions : exceptionWhenCondition (OR exceptionWhenCondition)* ;
exceptionWhenCondition  : expression;

functionSettings   : window functionBehavior functionInputHandling functionSecurity functionCosts functionRows; // TODO not sure if there is a fixed order

functionBehavior   : IMMUTABLE
 				   | STABLE
 				   | VOLATILE
 				   ;

window             : WINDOW;

functionInputHandling   : CALLED_ON_NULL_INPUT
					    | RETURNS_NULL_ON_NULL_INPUT
					    | STRICT
					    ;

functionSecurity        : SECURITY_INVOKER
						| SECURITY_DEFINER
						;

functionCosts           : COST value=INTEGER_VALUE;

functionRows            : ROWS value=INTEGER_VALUE;


// ---------
// -- Declarations
// -- see http://www.postgresql.org/docs/9.1/static/plpgsql-declarations.html
// ---------

varDeclarationList : (varDeclaration | aliasDeclaration)*;

// -- name [ CONSTANT ] type [ COLLATE collation_name ] [ NOT NULL ] [ { DEFAULT | := } expression ];
varDeclaration     : varName=ID CONSTANT? type=(ID | QNAME | ARRAY_TYPE | COPY_TYPE | ROW_TYPE) (COLLATE collationName=ID)? (NOT NULL)?  ( initOperator=( DEFAULT | ASSIGN_OP | EQ ) expression )? ';' ;

// -- newname ALIAS FOR oldname;
aliasDeclaration   : newVarName=ID ALIAS FOR oldVarName=ID ';' ;


//------------

assignStmt : assignExpr ';'
		   ;

assignExpr : receiver=expression assignOperator=(ASSIGN_OP | EQ) value=expression
           ;

//-------------
// -- RETURNING clause
//    RETURNING expressions INTO [STRICT] target
// -- http://www.postgresql.org/docs/9.1/static/plpgsql-statements.html  "9.5.3. Executing a Query with a Single-row Result"
//-------------
// TODO might generate uncomfy api
returningClause      : RETURNING (returningExpressions | returningAll)
					 ;

returningExpressions : returningOutputExpression (',' returningOutputExpression)* returningIntoClause?
                     ;

returningOutputExpression : expression (AS aliasName=ID)?
                          ;

returningAll         : '*'
                     ;

returningIntoClause  : INTO hasStrict=STRICT? returningIntoTargets
                     ;

returningIntoTargets : returningIntoTarget (',' returningIntoTarget)*
                     ;

returningIntoTarget  : target=(ID | QNAME)
                     ;



//----------
// -- WITH queries
// -- http://www.postgresql.org/docs/9.1/static/queries-with.html
// -- http://www.postgresql.org/docs/9.1/static/sql-delete.html
// -- http://www.postgresql.org/docs/9.1/static/sql-insert.html
// -- http://www.postgresql.org/docs/9.1/static/sql-update.html
//----------

withClause  : WITH withQueries
            ;

withRecursiveClause : WITH RECURSIVE withQueries
                    ;

withQueries : withQuery (',' withQuery)*
            ;

withQuery   : withTempTable=ID AS L_BRACKET select R_BRACKET
            ;

//------
//-- SELECT STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/queries-overview.html
//-- http://www.postgresql.org/docs/9.1/static/sql-select.html
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-statements.html
//------

// see http://www.postgresql.org/docs/9.1/static/queries-overview.html
selectStmt : select ';' ;

// TODO we leave WINDOW out for now
select :   withClause?
           SELECT  selectList
			(
			   intoClause?     // necessary for selectStmt
			   fromClause
			   joinClause*
			   whereClause?
		       groupByClause?
			   havingClause?
			   bulkOperationClause?
			   orderByClause?
			   limitClause?
			   offsetClause?
			   fetchClause?
			   forClause?
			)?
			;

selectList          : (ALL | distinctClause )?  ( selectAll | selectSpecific );
distinctClause      : DISTINCT ON expression (',' expression)* ;
selectSpecific      : expression (',' expression)* ;

selectAll           : '*';

intoClause     : INTO   strict=STRICT? target=ID (',' target=ID)* ;

limitClause    : LIMIT  limit=( INTEGER_VALUE | ALL ) ;
offsetClause   : OFFSET offset=INTEGER_VALUE (ROW | ROWS)? ;

orderByClause  : ORDER_BY orderByItem (',' orderByItem)*;
orderByItem    : expression  ordering=( ASC | DESC )?  nullsOrdering ? # standardOrdering
			   | expression orderByUsing nullsOrdering ?               # usingOrdering
			   ;

orderByUsing   :  USING operator=(LT | LTE | GT | GTE);

nullsOrdering  : NULLS  ordering=( FIRST | LAST  );

// http://www.postgresql.org/docs/9.1/static/sql-select.html#SQL-FROM
// didn't really get this part: "from_item [ NATURAL ] join_type from_item [ ON join_condition | USING ( join_column [, ...] ) ]"

fromClause        : FROM  tableExpression (',' tableExpression)* ;

joinClause : NATURAL? join;

// TODO not finished yet
tableExpression   : (only=ONLY)? tableName=( QNAME | ID) ('*')? (AS?  alias=ID columnAlias)?  # fromTable
				  | L_BRACKET select R_BRACKET AS? alias=ID  columnAlias?                         # fromSelect
			      ;

join            : INNER?      JOIN  table=( QNAME | ID)  ON condition # innerJoin
				| LEFT  OUTER JOIN  table=( QNAME | ID)  ON condition # leftOuterJoin
				| LEFT        JOIN  table=( QNAME | ID)  ON condition # leftJoin
				| RIGHT OUTER JOIN  table=( QNAME | ID)  ON condition # rightOuterJoin
				| RIGHT       JOIN  table=( QNAME | ID)  ON condition # rightJoin
				| FULL  OUTER JOIN  table=( QNAME | ID)  ON condition # fullJoin
				| FULL        JOIN  table=( QNAME | ID)  ON condition # fullOuterJoin
				| CROSS       JOIN  table=( QNAME | ID)  ON condition # crossJoin
				;

columnAlias     : L_BRACKET columnAliasItem (',' columnAliasItem)* R_BRACKET ;
columnAliasItem : ID;


whereClause         : WHERE    condition;
groupByClause       : GROUP_BY expression ;
havingClause        : HAVING   condition;
bulkOperationClause : operator=( UNION | INTERSECT | EXCEPT )   selectMode=(ALL | DISTINCT) select ;

// In this syntax, to write anything except a simple integer constant for start or count,
// you must write parentheses around it. If count is omitted in a FETCH clause, it defaults to 1.
// ROW and ROWS as well as FIRST and NEXT are noise words that don't influence the effects of these clauses
fetchClause  : FETCH  (FIRST | NEXT )? (count=INTEGER_VALUE)?  (ROW | ROWS)? ONLY;

forClause    :  FOR lockMode=(UPDATE | SHARE)  (lockedTables)?  nowait=NOWAIT?;
lockedTables : OF lockedTable (',' lockedTable)*;
lockedTable  : ID;


//------
//-- PERFORM STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-statements.html
//-- TODO: did not really get the part with WITH Queries. Could not define any PERFORM statement with WITH clause
//------

performStmt :  PERFORM  selectList
						(
						   fromClause
						   joinClause*
						   whereClause?
					       groupByClause?
						   havingClause?
						   bulkOperationClause?
						   orderByClause?
						   limitClause?
						   offsetClause?
						   fetchClause?
						   forClause?
						)?
				';'
	 				  ;


//------
//-- EXECUTE STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-statements.html
//-- EXECUTE command-string [ INTO [STRICT] target ] [ USING expression [, ... ] ];
// TODO: string operations are not considered yet
//------

executeStmt : execute ';'
            ;

execute : EXECUTE executeCommand executeIntoClause? executeUsingClause?
        ;

executeCommand : STRING
               | functionCallExpr
               ;

executeIntoClause  : INTO hasStrict=STRICT? executeIntoTargets
                   ;

executeIntoTargets : executeIntoTarget (',' executeIntoTarget)*
                     ;

executeIntoTarget    : target=(ID | QNAME)
                     ;

executeUsingClause : USING executeUsingExpression (',' executeUsingExpression)*
                   ;

executeUsingExpression : expression
                       ;


//------
//-- INSERT STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/sql-insert.html
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-statements.html  "9.5.3. Executing a Query with a Single-row Result"
//------

insertStmt : insert ';' ;

insert : withClause?
         INSERT INTO table=(ID | QNAME) insertColumnList?
         (insertValuesClause | select)
         returningClause?
	   ;

insertColumnList : L_BRACKET insertColumn (',' insertColumn)* R_BRACKET
                 ;

insertColumn     : column=ID
				 ;

insertValuesClause     : insertDefaultValues
                       | insertValues
                       ;

insertDefaultValues    : DEFAULT VALUES
                       ;

insertValues     : VALUES insertValueTuple (',' insertValueTuple)*
                 ;

insertValueTuple : L_BRACKET insertValue (',' insertValue)*  R_BRACKET
                 ;

insertValue         : expression
                    | column=(ID | QNAME)
                    | hasDefault=DEFAULT
                    ;

//------
//-- UPDATE STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/sql-update.html
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-statements.html  "9.5.3. Executing a Query with a Single-row Result"
// TODO: cursors ignored for now
//------

updateStmt : update ';'
           ;

// UPDATE [ ONLY ] table [ * ] [ [ AS ] alias ]
//     SET { column = { expression | DEFAULT } |
//           ( column [, ...] ) = ( { expression | DEFAULT } [, ...] ) } [, ...]
//     [ FROM from_list ]
//     [ WHERE condition | WHERE CURRENT OF cursor_name ]
//     [ RETURNING * | output_expression [ [ AS ] output_name ] [, ...] ]

update : withClause?
         UPDATE hasOnly=ONLY? table=(ID | QNAME) (areDescendantTablesIncluded='*')? (AS tableAliasName=ID)?
            SET (updateSingleSetClause | updateMultiSetClause)
          fromClause?
          whereClause?
          returningClause?
       ;


updateSingleSetClause : updateSingleSetAssignment (',' updateSingleSetAssignment)*
                      ;

updateSingleSetAssignment : column=(ID | QNAME) '=' updateSetValue
                          ;


updateMultiSetClause   : updateMultiSetAssignment (',' updateMultiSetAssignment)*
                       ;

updateMultiSetAssignment : L_BRACKET updateMultiSetColumns R_BRACKET '=' L_BRACKET  updateMultiSetValues R_BRACKET
                         ;


updateMultiSetColumns  : updateMultiSetColumn (',' updateMultiSetColumn)*
                       ;

updateMultiSetColumn   : column=(ID | QNAME)
                       ;

updateMultiSetValues   : updateSetValue (',' updateSetValue)*
                       ;

updateSetValue         : expression
                       | column=(ID | QNAME)
                       | hasDefault=DEFAULT
                       ;

//------
//-- DELETE STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/sql-delete.html
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-statements.html  "9.5.3. Executing a Query with a Single-row Result"
// TODO: cursors ignored for now
//------

deleteStmt : delete ';'
           ;

// [ WITH [ RECURSIVE ] with_query [, ...] ]
// DELETE FROM [ ONLY ] table [ * ] [ [ AS ] alias ]
//     [ USING using_list ]
//     [ WHERE condition | WHERE CURRENT OF cursor_name ]
//     [ RETURNING * | output_expression [ [ AS ] output_name ] [, ...] ]
delete : withClause?
	     DELETE FROM hasOnly=ONLY? table=(ID | QNAME) (areDescendantTablesIncluded='*')? (AS tableAliasName=ID)?
         deleteUsingClause?
         whereClause?
         returningClause?
       ;

deleteUsingClause : USING deleteUsingTable (',' deleteUsingTable)*
                  ;

deleteUsingTable : tableName=( QNAME | ID)
                 ;


//------
//-- RETURN STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-control-structures.html
//-- RETURN expression;
//-- RETURN NEXT expression;
//-- RETURN QUERY query;
//-- RETURN QUERY EXECUTE command-string [ USING expression [, ... ] ];
//------

returnStmt : (returnSimple | returnNext | returnQuery | returnQueryExecute ) ';'
           ;

returnSimple : RETURN expression?
             ;

returnNext   : RETURN NEXT expression
             ;

returnQuery  : RETURN QUERY select
             ;

returnQueryExecute : RETURN QUERY execute
                   ;

//------
//-- IF STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-control-structures.html
//-- IF ... THEN ... END IF;
//-- IF ... THEN ... ELSE ... END IF;
//-- IF ... THEN ... ELSIF ... THEN ... ELSE ... END IF;
//------

ifStmt : IF ifCondition THEN stmts (ELSIF elsifCondition THEN stmts)*  (ELSE stmts)?  END IF ';'
       ;

ifCondition : condition
            ;

elsifCondition : condition
               ;
//------
//-- CASE STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-control-structures.html
//-- CASE ... WHEN ... THEN ... ELSE ... END CASE
//-- CASE WHEN ... THEN ... ELSE ... END CASE
//------

caseStmt : caseExpr ';'
         ;

caseExpr : CASE searchExpr? ( WHEN  whenExpressions THEN stmts)+ (ELSE stmts)? END CASE
         ;

whenExpressions : whenExpr (',' whenExpr)*
                ;

searchExpr : expression
           ;

whenExpr : expression
         ;

//------
//-- LOOP STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-control-structures.html
//   [ <<label>> ]
//   LOOP
//     statements
//   END LOOP [ label ];
//------

loopStmt : ( '<<' firstLabel=ID '>>' )?
           LOOP
             stmts
           END LOOP lastLabel=ID? ';'
         ;

//------
//-- EXIT STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-control-structures.html
//   EXIT [ label ] [ WHEN boolean-expression ];
//------

exitStmt : EXIT targetLabel=ID? exitWhenClause? ';'
         ;

exitWhenClause : WHEN condition
               ;

//------
//-- EXIT STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-control-structures.html
//   CONTINUE [ label ] [ WHEN boolean-expression ];
//------

continueStmt : CONTINUE targetLabel=ID? continueWhenClause? ';'
             ;

continueWhenClause : WHEN condition
                   ;

//------
//-- WHILE STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-control-structures.html
//   [ <<label>> ]
//   WHILE boolean-expression LOOP
//       statements
//   END LOOP [ label ];
//------------

whileStmt : ( '<<' firstLabel=ID '>>' )?
            WHILE condition
            LOOP
               stmts
            END LOOP lastLabel=ID? ';'
           ;


//------
//-- FOR (Integer Variant) LOOP STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-control-structures.html
//   [ <<label>> ]
//   FOR name IN [ REVERSE ] expression .. expression [ BY expression ] LOOP
//       statements
//   END LOOP [ label ];
//------------

forInIntStmt :  ( '<<' firstLabel=ID '>>' )?
                FOR varExpr IN reverseKeyword=REVERSE? forInIntFromExpression '..' forInIntToExpression  (BY forInIntByExpression)?
                LOOP
                  stmts
                END LOOP lastLabel=ID? ';'
             ;

forInIntByExpression : expression
                     ;

forInIntFromExpression : expression
                       ;

forInIntToExpression : expression
                     ;


//------
//-- FOR (Query Variant) LOOP STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-control-structures.html
//   [ <<label>> ]
//   FOR target IN query
//   LOOP
//       statements
//   END LOOP [ label ];
//------------

forInQueryStmt : ( '<<' firstLabel=ID '>>' )?
                 FOR varExpr IN forInQuery
                 LOOP
                   stmts
                 END LOOP lastLabel=ID? ';'
               ;

// TODO could be defined nicer?
forInQuery : L_BRACKET forInQuery R_BRACKET
           | select
           ;


//------
//-- FOR (EXECUTE Variant) LOOP STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-control-structures.html
//  [ <<label>> ]
//  FOR target IN EXECUTE text_expression [ USING expression [, ... ] ] LOOP
//      statements
//  END LOOP [ label ];
//------
forInExecuteStmt : ( '<<' firstLabel=ID '>>' )?
                   FOR varExpr IN execute
                   LOOP
                     stmts
                   END LOOP lastLabel=ID? ';'
                 ;

//------
//-- FOREACH LOOP STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-control-structures.html
//   [ <<label>> ]
//   FOREACH target [ SLICE number ] IN ARRAY expression LOOP
//       statements
//   END LOOP [ label ];
//------

forEachStmt : ( '<<' firstLabel=ID '>>' )?
              FOREACH varExpr (SLICE sliceValue=INTEGER_VALUE)? IN ARRAY forEachArrayExpression
              LOOP
                 stmts
              END LOOP lastLabel=ID? ';'
            ;

// TODO can we be more restrictive here?
forEachArrayExpression : expression
                       ;

//------
//-- GET DIAGNOSTICS STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-statements.html
//   GET DIAGNOSTICS variable = item [ , ... ];
//------

getDiagnosticsStmt : GET DIAGNOSTICS assignExpr (',' assignExpr)* ';'
                   ;

//------
//-- RAISE STATEMENT GRAMMAR
//-- http://www.postgresql.org/docs/9.1/static/plpgsql-errors-and-messages.html
//   RAISE [ level ] 'format' [, expression [, ... ]] [ USING option = expression [, ... ] ];
//   RAISE [ level ] condition_name [ USING option = expression [, ... ] ];
//   RAISE [ level ] SQLSTATE 'sqlstate' [ USING option = expression [, ... ] ];
//   RAISE [ level ] USING option = expression [, ... ];
//   RAISE ;
//------

raiseStmt : RAISE 																	                                                                                              ';' # raiseStmtEmpty
          | RAISE level=( DEBUG1 | DEBUG2 | DEBUG3 | DEBUG4 | DEBUG5 | INFO | NOTICE | WARNING | ERROR | LOG | FATAL | PANIC )? format=STRING (',' expression)* raiseUsingClause? ';' # raiseStmtWithFormattedMsg
          | RAISE level=( DEBUG1 | DEBUG2 | DEBUG3 | DEBUG4 | DEBUG5 | INFO | NOTICE | WARNING | ERROR | LOG | FATAL | PANIC )? conditionName=ID raiseUsingClause? 				  ';' # raiseStmtWithConditionName
          | RAISE level=( DEBUG1 | DEBUG2 | DEBUG3 | DEBUG4 | DEBUG5 | INFO | NOTICE | WARNING | ERROR | LOG | FATAL | PANIC )? SQLSTATE sqlState=STRING raiseUsingClause?        ';' # raiseStmtWithSqlState
          | RAISE level=( DEBUG1 | DEBUG2 | DEBUG3 | DEBUG4 | DEBUG5 | INFO | NOTICE | WARNING | ERROR | LOG | FATAL | PANIC )? raiseUsingClause?						          ';' # raiseStmtWithOptionsOnly
          ;

raiseUsingClause  : USING raiseOptionAssign (',' raiseOptionAssign)*
                  ;

raiseOptionAssign : option=ID '=' expression
                  ;

//------------


stmts 	: stmt*; // we allow empty functions

stmt  	: selectStmt
		| insertStmt
		| updateStmt
		| deleteStmt
		| blockStmt
		| assignStmt
		| performStmt
		| executeStmt
		| returnStmt
		| ifStmt
		| caseStmt
		| loopStmt
		| exitStmt
		| continueStmt
		| whileStmt
		| forInIntStmt
		| forInQueryStmt
		| forInExecuteStmt
		| forEachStmt
		| getDiagnosticsStmt
		| raiseStmt
		;

