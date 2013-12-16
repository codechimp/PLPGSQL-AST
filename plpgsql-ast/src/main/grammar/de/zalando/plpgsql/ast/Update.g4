//
// Grammar for UPDATE
//

// -- my entry point
unit        : sqlUpdate; // at least one UPDATE command must exist


sqlUpdate   : (WITH (RECURSIVE)? withQuery)? UPDATE (ONLY)? tableName ('*')? ((AS)? aliasName)?
