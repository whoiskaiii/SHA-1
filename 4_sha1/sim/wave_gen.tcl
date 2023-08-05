call {$fsdbDumpfile("./sha1_core_tb.fsdb")}
call {$fsdbDumpvars(0, sha1_core_tb, "+all")}
call {$fsdbDumpMDA}

run
