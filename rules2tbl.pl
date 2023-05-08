#!/usr/bin/perl
##########################################################################
# 09/26/2015                  Daniel L. Needles              Version 0.9 #
# PROGRAM: rules2tbl.pl                                                  #
# PURPOSE:                                                               #
#          IBM Tivoli Netcool rules are usually in an "evolved" state.   #
#          1.  Accumulated Entropy due to syntax flexibility.            #
#          2.  Keep state for external products (ITNM, ITM, TBSM,Impact) #
#          3.  Keep state for automation or Impact notifications,        #
#              enrichments, and event automations.                       #
#          This program only converts the fields required for MOOG which #
#          fixes much of #2 and #3 but some #1 entropy will remain.      #
#          The functionality of #2 and #3 is provided via adding canned  #
#          solutions via the Product Function Catalog.                   #
# DESCRIPTION:                                                           #
#          The rules2tbl program converts Netcool rules files into two   #
#          components:                                                   #
#          1. Table consisting of a sequential list of                   #
#             Conditions => Assignments(Fields,Variables,Properties,FXs) #
#          2. Equation determining the AND/OR and grouping () of #1.     #
#             Processing the equation and applying the table rows will   #
#             result in the equivallent result of processing the rules.  #
#             The terse and consistent rendering via the equation+table  #
#             enables: analysis and clean up.                            #
#          NOTE: The rules use a very "loose" syntax. As such parsing    #
#             doesn't always work. However the script can be corrected   #
#             as these come up based on full out put from the log        #
#               ./rules2tbl.pl -debug 4095 -input ((master-rule-file))   #
#          NOTE: The program works on a subset of the rules as well:     #
#               ./rules2tbl.pl -input ((rule-file))                      #
# PSUDO CODE:                                                            #
# 1  - Includes and Init vars                                            #
# 2  - Commandline processing and open files                             #
# 3  - Loop 1: Rules Aggregation into @lines.                            # 
# 4  - Clean whitespace and basic lookup table normalization             #
# 5  - Loop 2: Tokenize, remove comments, memorize tables                #
# 6  - Loop 3: Create SQL, buffer tables in $table                       #
# 7  - Normalize aggregate file via regular expressions                  #
# 8  - Create EXCEL workbook template                                    #
# 9  - Loop 4: Output JAVASCRIPT -- CURRENTLY NOT IMPLEMENTED            #
# 10 - Loop 5: Convert SWITCH statements to IF-THEN-ELSE                 #
# 11 - Loop 6: Build Truth Table                                         #
# 12 - Output EXCEL Statistics Tab                                       #
# 13 - Process Equation                                                  #
# INSTALLATION:                                                          #
#   WINDOWS                                                              #
#     1. Install PERL such as cygwin's or ActiveState                    #
#     2. Install PERL module SpreadSheet::WriteExcel                     #
#        If using Active State PERL use:                                 #
#          ppm                                                           #
#          ppm> install SpreadSheet::WriteExcel                          #
#        If using cygwin's PERL, the installion can be done via CPAN     #
#        NOTE: nmake and gcc are required when going to cygwin route.    #
#          cpan Spreadsheet::WriteExcel                                  #
#     3. If needed, install Open Office (free)                           #
#     4.  Install package. For example, with tar from cygwin:            #
#           tar -zxvf DNA.tar.gz                                         #
#   LINUX RedHat/CentOS:                                                 #
#     1. Install PERL and the PERL module Spreadsheet::WriteExcel.       #
#           yum -y install perl "perl(Spreadsheet::WriteExcel)"          #
#     2. If needed, install Open Office (free)                           #
#     3. Install DNA package.                                            #
#           tar -zxvf DNA.tar.gz                                         #
#   APPLE/MAC:                                                           #
#     1. Install the PERL module Spreadsheet::WriteExcel.                #
#     2. If needed, install either MS Office or Open Office (free)       #
#     3. Install PERL module SpreadSheet::WriteExcel                     #
#           sudo cpan Spreadsheet::WriteExcel                            #
#        The above command will generate a GUI prompt to install the XS  #
#        libs (if you have not already done so). If prompted, repeat     #
#        the command:                                                    #
#           sudo cpan Spreadsheet::WriteExcel                            #
#        Make sure the module compiles. Watch the output look for "OK"   #
#        or just check return level.                                     #
#     4. Install DNA package.                                            #
#           tar -zxvf DNA.tar.gz                                         #
# PACKAGE USAGE:                                                         #
#     The package contains the self contained script rules2tbl.pl and    #
#     this readme as well as three example sets of rules:                #
#        * NcKL3.7 - IBM's older NcKL rules                              #
#        * NcKL4.3 - IBM's newer NcKL rules                              #
#        * YahooRules - Yahoo's syslog rules                             #
#     To run the script and examine the output perform the following     #
#     steps:                                                             #
#     1. Copy the script to the root of the rules directory.             #
#       scp rules2tbl.pl ((rule-root-directory))                         #
#     2. Run the script from the directory and save the log output       #
#       cd ((rule-root-directory))                                       #
#       ./rules2tbl.pl -input snmptrap.rules > snnptrap.log              #
#     3. Use either Excel or Open Office (free) to examine the xls file  #
#        The program will create four files:                             #
#        snmptrap.xls : MS Office file containing statistics, raw table, #
#                       and equation.  Excel or OpenOffice can be used.  #
#        snmptrap.eqn : Holds the number of paths as well as the rules   #
#                       equation.                                        #
#        snmptrap.tbl : Holds a tab delimited output of the table.       #
#        snmptrap.log : The log file used to debug issues.               #
#        Rules Saved After Each Stage:                                   #
#           snmptrap.loop1-concat-all-rules                              #
#           snmptrap.loop2-tokenize-remove-comments                      #
#           snmptrap.loop3-buffer-tables                                 #
#           snmptrap.loop4-convert-to-javascript                         #
#           snmptrap.loop5-convert-switchstmts-to-if-then-else           #
# Install OpenOffice -                                                   #
#       See http://www.if-not-true-then-false.com/                       #
#             2010/install-openoffice-org-on-fedora-centos-red-hat-rhel/ #
# PROGRAM USAGE:                                                         #
# rules2tbl.pl                                                           #
#                  [-debug <debug number 1-2047>]  (($DEBUG))            #
#                    1   - Track program's progress.                     #
#                    2   - Detailed logging of loop 1                    #
#                    4   - Detailed logging of loop 2                    #
#                    8   - Detailed logging of loop 3                    #
#                    16  - Detailed logging of loop 4                    #
#                    32  - Detailed logging of loop 5                    #
#                  [-excel <fullpath to Excel output file>]              #
#                  [-help]                                               #
#                  [-input <rulesfile>]                                  #
#                  [-nul <Character(s) to use for null value>]           #
#                  [-order]                                              #
#                  [-output none|<fullpath to raw CVS output file>]      #
#                  [-mvdir <reference directory>]                        #
#   NOTE: Run program at rule root (i.e. $OMNIHOME\probes\linux2x86\)    #
#         If the files have been moved, use mvdir to map the directory   #
#         references to the local directory                              #
#                                                                        #
# EXAMPLE: rules2tbl.pl -input syslog.rules -mvdir /home/y/conf/netcool_rules/  > syslog.output
##########################################################################
# DLN20150709: Release without bells and whistles.                       #
# THE FOLLOWING ARE KNOW "FEATURES" THAT WERE PROVIDED BUT NOT ASKED FOR #
# 1. Limited simplification of rules                                     #
# 2. Nested values not addressed.                                        #
##########################################################################
my $start=time();

##########################################################################
## 1 - INCLUDES, INITALIZE VARAIBLES
##########################################################################
($DEBUG & 1) && print "//1: INCLUDES AND INIT VARS AND COMMAND LINE OPTONS.",&runtimer,"\n";
use strict;                 ## TRAINING WHEELS ON
use Getopt::Long;           ## HANDLES COMMAND LINE OPTIONS
use IO::File;               ## EXCEL COLUMN MAX WORKAROUND
use Spreadsheet::WriteExcel;## EXCEL DIRECT WRITE
$|=1;                       ## DO NOT BUFFER OUTPUT
my $FILENAME='snmptrap.rules'; ## DEFAULT SOURCE FILE
my $SFD='snmptrap.xls';     ## STATISTICAL OUTPUT FILE
my $AFD='snmptrap.tbl';     ## ONE FILE TO HOLD THEM ALL
my $EQN='snmptrap.eqn';     ## EQUATION OUTPUT FILE
my $SQL='snmptrap.sql';     ## SQL FILE
my $JS='snmptrap.js';       ## JAVASCRIPT FILE
my $LOOP1='snmptrap.loop1-concat-all-rules'; ## RULES AFTER LOOP1
my $LOOP2='snmptrap.loop2-tokenize-remove-comments'; ## RULES AFTER LOOP2
my $LOOP3='snmptrap.loop3-buffer-tables'; ## RULES AFTER LOOP3
my $LOOP4='snmptrap.loop4-convert-to-javascript'; ## RULES AFTER LOOP4
my $LOOP5='snmptrap.loop5-convert-switchstmts-to-if-then-else'; ## RULES AFTER LOOP4
my $MVDIR=':';              ## REPLACE DIRECTORY REFERENCE
my $SRCDIR='';              ## DERIVED FROM MVDIR -- SRC DIR TO REPLACE
my $DSTDIR='';              ## DERIVED FROM MVDIR -- DST DIR TO REPLACE WITH
my $ORDER = 0;              ## ADD ORDER OF ASSIGNMENT INFO
my $UNASSIGNED='';          ## INITIAL VALUE IN TABLE
my $NOBUFFER=0;             ## BUFFER ENTIRE TABLE OR NOT
my $DEBUG=1;                ## DEBUGING
my $space;                  ## PRETTY RULE FORMATTING (CORRECT NO OF SPACES)
my @lines;                  ## $LINES SPLIT ALONG NEW LINES
my $lines;                  ## SINGLE STRING HOLDS ENTIRE RULES FILE
my @switch;                 ## BUFFER SWITCHES TO CONVERT TO IF CLAUSES
my $switch;                 ## SWITCH INDEX
my @conditions;             ## ARRAY OF CONDITIONS
my %taxonomy;                  ## HASH OF FIELDS

## FOR LOOP 3: BUILDING TRUTH TABLE
my $endconds;               ## END OF ARRAY: LIST OF CONDITIONS
my $endvars=0;              ## END OF ARRAY: LIST OF VARS
my @vars;                   ## ASSIGNED VARS FOR A RULE OUTPUT LINE
my @conds;                  ## NESTED CONDITIONS FOR A RULE OUTPUT LINE
my $endequation=1;          ## END OF ARRAY: LIST OF RULES
my $was;                    ## PREVIOUS EQUATION ELEMENT
my $equation='';            ## EQUATION OF HOW INDIVIDUAL ROWS SHOULD APPLY
my $currfile='';            ## FILE OF ORIGIN
my $ocurrfile='';           ## USED IN SPECIAL CASE WHERE CASES SPLIT 1 PER FILE
my @colcnt;                 ## FIELD COUNT

## EXCEL OUTPUT 
my $MAXROWS=64950;          ## EXCEL LIMIT OF 65535 (256*256-1)
my $MAXCOLS=250;            ## EXCEL LIMIT OF 255   (256-1)
my @wsdata;                 ## HOLDS EXCEL SPREADSHEETS
my $COLBANDS=0;
my $wsold=0;                ## COUNTER USED IN DEBUGGING

## FORCE LOGGING TO BE UNBUFFERED
$|=1;

##########################################################################
## 2 - COMMANDLINE PROCESS AND OPEN FILES
##########################################################################
commandline();        ## PARSE COMMANDLINE OPTIONS

## OPEN SQL, JAVASCRIPT, OUTPUT, EQUATION, EXCEL FILES
if ( lc($SQL) ne 'none' ) { 
  if (!(open(SQL, "> $SQL"))) {
    print "E: Failed to open SQL output file: $SQL\n";
  }
}
if ( lc($JS) ne 'none' ) { 
  if (!(open(JS, "> $JS"))) {
    print "E: Failed to open JAVASCRIPT output file: $JS\n";
  }
}
if ( lc($AFD) ne 'none' ) { 
  if (!(open(ALL, "> $AFD"))) {
    print "E: Failed to open TAB DELIMITED TABLE output file: $AFD\n";
  }
}
if ( lc($EQN) ne 'none' ) { 
  if (!(open(EQN, "> $EQN"))) {
    print "E: Failed to open EQUATION output file: $EQN\n";
  }
}
if ( lc($LOOP1) ne 'none' ) { 
  if (!(open(LOOP1, "> $LOOP1"))) {
    print "E: Failed to open LOOP1 Script output file: $LOOP1\n";
  }
}
if ( lc($LOOP2) ne 'none' ) { 
  if (!(open(LOOP2, "> $LOOP2"))) {
    print "E: Failed to open LOOP2 Script output file: $LOOP2\n";
  }
}
if ( lc($LOOP3) ne 'none' ) { 
  if (!(open(LOOP3, "> $LOOP3"))) {
    print "E: Failed to open LOOP3 Script output file: $LOOP3\n";
  }
}
if ( lc($LOOP4) ne 'none' ) { 
  if (!(open(LOOP4, "> $LOOP4"))) {
    print "E: Failed to open LOOP4 Script output file: $LOOP4\n";
  }
}
if ( lc($LOOP5) ne 'none' ) { 
  if (!(open(LOOP5, "> $LOOP5"))) {
    print "E: Failed to open LOOP5 Script output file: $LOOP5\n";
  }
}
my $statworkbook = Spreadsheet::WriteExcel->new($SFD); ## CMDLINE SETS $SFD
my $wsstats = $statworkbook->add_worksheet('Statistics');
my $format = $statworkbook->add_format();
($DEBUG & 1) && print "//1: INCLUDES AND INIT VARS AND COMMAND LINE OPTIONS.",&runtimer,"\n";  ## AFTER --help / USAGE()

##########################################################################
## 3 - LOOP 1: FOLLOW ALL INCLUDE FILES AND STORE LOCALLY IN @LINES 
##             AND COVERT INCLUDE TBL TO EMBEDDED TBLS
##########################################################################
($DEBUG & 1) && print "//2: Loop 1: GATHER RULES.",&runtimer,"\n";
($DEBUG & 1) && print "//  a. Collect rules and includes, convert include tbls to embedded tbl format, and store everything in \@lines.",&runtimer,"\n";
my $i=0;              ## FILE NESTING DEPTH
my $badincludenum=0;  ## TALLY MISSING FILES
my $f=$FILENAME;      ## DISCARD FULL PATH (FILE ONLY)
if ($f =~ /^.*\/(.*)/) {
  $f=$1;
}

## PROCESS ALL RULES AND INCLUDE. NOTE: tblmode is used to 
##  mark included tables which get converted to embedded tables.
my $tblmode='';
my $rulesnum=processfile($FILENAME,$i,0,'','root',$tblmode);
if (! $rulesnum) {
  print "E: No lines to process. This program must be run from the directory where the master rule file is located.\n";
  usage();
}

##########################################################################
## 4 - CLEAN WHITESPACE AND BASIC LOOKUP TABLE NORMALIZATION
##########################################################################
## AFTER PROCESS THE MASSIVE RULES BY CLEANING UP WHITESPACE AT A FILE AND LINE LEVEL
## ALSO PREP THE TABLES FOR PROCESSING (A BIT OF A CLUDGE)
## CLEAN FILE SCOPE WHITE SPACE
($DEBUG & 1) && print "//  a. Clean whitespace lines (file scope.)",&runtimer,"\n";
my $blanknum=$lines=~s/^\s*\n//sgm;       ## RM EMPTY LINES

## CLEAN LINE SCOPE WHITE SPACE
($DEBUG & 1) && print "//  b. Clean leading and trailing whitespace (line scope.)",&runtimer,"\n";
$lines=~s/^\s+(.*?)$/\1/gm; ## RM LEADING SPACES
$lines=~s/^(.*?)\s+$/\1/gm; ## RM TRAILING SPACES

## FINAL TABLE NORMALIZATION HACK
## IDEALLY: TOKENIZE COMMENTS & STRINGS, THEN BUILD TABLES AND DETOKENIZE
##          BUT THAT WOULD REQUIRE ANOTHER REWRITE.
($DEBUG & 1) && print "//  c: Table normalization.",&runtimer,"\n";
#$lines=~s:^ARRAY:array:gmi;      ## LOWER CASE ARRAYS
$lines=~s:^TABLE:table:gmi;      ## LOWER CASE TABLES
#$lines=~s:^INCLUDE:include:gmi;  ## LOWER CASE INCLUDES 
$lines=~s:^DEFAULT:default:gmi;  ## LOWER CASE DEFAULT (CASE STMT & TABLE)
$lines=~s:^CASE:case:gmi;  ## LOWER CASE DEFAULT (CASE STMT & TABLE)
$lines=~s:^case\":case ":gmi;  ## LOWER CASE DEFAULT (CASE STMT & TABLE)
$lines=~s/^(table\s+[\w\-_]+)\s*=\s*\".*?\"/\1 =/mg;  ## REMOVE EMBEDDED TABLE FILE REFERENCE AS WELL AS COMMENTS
$lines=~s/^(table\s+[\w\-_]+\s*=\s*\{)$/(my $subscope=$1)=~s:\n: :g; $subscope;/smge; ## CONCAT SPLIT 'table . = {'
my $includenum=$lines=~s/^include .*$//igm; ## CNT INCLUDES
my $arraynum=$lines=~s/^array\s+.*?;\n//igms; ## CNT AND REMOVE ARRAY DCLS

## SAVE CODE
print LOOP1 $lines;
close(LOOP1);

##########################################################################
## 5 - LOOP 2: TOKENIZE, REMOVE COMMENTS, MEMORIZE TABLES
##########################################################################
($DEBUG & 1) && print "//3: Loop 2: Tokenize strings, comments. Drop comments and memorize tables.",&runtimer,"\n";
my @lines = split /\n/,$lines;   ## CONVERT TO ARRAY FOR LINE CENTRIC PROCESSING
my @strings;                     ## TOKENIZE STRINGS
my $stringidx=0;                 ## TOP OF STRINGS STACK
my @tbls;                        ## TOKENIZE TABLES
my $tblidx=0;                    ## TOP OF TABLES STACK
my @flds;                        ## TOKENIZE FIELDS
my $fldidx=0;                    ## TOP OF FIELDS STACK
my @vars;                        ## TOKENIZE VARIABLES
my $varidx=0;                    ## TOP OF VARIABLE STACK
my @props;                       ## TOKENIZE PROPERTIES 
my $propidx=0;                   ## TOP OF PROPERTIES STACK
my @fxs;                         ## TOKENIZE FUNCTION CALLS
my $fxidx=0;                     ## TOP OF FUNCTION STACK
my $fxnest;                      ## NESTING OF FUNCTIONS. 0 is none.

my $commentnum=0;                ## COMMENT COUNT
my $tbl='';                      ## CURRENT TABLE (NULL IF NOT IN TABLE)
my %table;                       ## MEMORIZE LOOKUP TABLES
my @rowtype;                     ## TABLE COLUMN: CHARACTER OR INTEGER

## LOOKUPS CAN SPAN MORE THAN 1 LINE
my $lookupnest=0;     # What level does lookup nest start at? (Diff used between fxnest)
my $lookupfields='';  # x;   x=lookup(key,tbl) [ OPTIONAL ]
my $lookupkeyidx=0;      # Key; x=lookup(^key,tbl);
my $lookupcomma=0;    # Tbl; x=lookup(key,^tbl);

for (my $i=0; $i<=$#lines; $i++) {
  ## WHERE ARE WE AT?
  if ($DEBUG & 2) {
    print "LOOP 2: $i: $lines[$i]\n";
  } elsif ($DEBUG & 1) {
    if ($i % 50000 == 0) {
      print "LOOP 2: $i of $#lines\n";
    }
  }

  ## BUG FIX. BRACKET WITH COMMENT SOMEHOW SLIPPED THROUGH
  if ($lines[$i] =~ /^}\s+#/) {
    $lines[$i] = '}';
  }

  ## PRE-PROCESS TABLE BY LINE.  
  ## 1. TOGGLE IN AND OUT OF TABLE TO TURN OFF AND ON '\' ESCAPING
  ## 2. TOKENIZE THE TABLE
  if ($lines[$i]=~/^table\s+(.*?)\s+=(.*)/) {
    my $oldtbl=$tbl;
    $tbl=$1;
    $tbl=~ s:-:_:g;  ## NAME SPACE DIFFERENCE BETWEEN RULES AND JAVASCRIPT
    $tbls[$tblidx]=$tbl;
    $lines[$i]="table ~$tblidx~ = $2\n";
    if ($oldtbl) {
      print "E: Nested table detected '$tbl' is inside '$oldtbl.'\n";
    } 
    $taxonomy{"~$tbls[$tblidx]"}=$tblidx; ## INSTEAD OF TALLY, REVERSE INDEX TO TABLE FOR LOOKUP
    $tblidx++;
    #print "I: Entering table.\n";
  ## IF IN TABLE AND HIT '}' THIS IS THE END OF THE TABLE -- SAVE IT
  } elsif ($tbl && ($lines[$i] =~ /^}$/)) {
  # print "I: Exiting table.\n";
    for (my $j=0; $j<=$#rowtype; $j++) {
      $table{$tbl}{'Type'}.= $rowtype[$j] . "\t";
    }

    ## NO EMPTY LINES BETWEEN TABLE AND DEFAULT
    $i++;   ## SKIP ENDING '}' NO TOKENIZATION NEEDED AND SEE IF WE HAVE DEFAULT
    if ($lines[$i]=~/^\s*default\s*=\s*\{\s*(\".*?\")\s*\}/) {
      #my $tmp=$1;
      #$tmp=~ s:\"\s*,\s*\"::g;
      #$table{$tbl}{'Data'}.='defaultlookup' . $lines[$i] . "\n";
      $table{$tbl}{'Default'}=$1;
      $table{$tbl}{'Default'} =~ s:\{::g;
      $table{$tbl}{'Default'} =~ s:\}::g;
#print "DEFAULT FOR $tbl $lines[$i]\n";
    } else {
      #print "//W: No default found: $lines[$i]\n";
      $table{$tbl}{'Default'}='NONE';
    }
    $tbl='';  ## EXITING CURRENT TABLE.

  ## REMOVE COMMENTS INSIDE TABLES
  #} elsif ($tbl && ($lines[$i] =~ /^({(\".*?\")(,\".*?\")+},?)\s*#/)) {
  #  $lines[$i]=$1;

  ## PRE-PROCESS LOOKUP() BY LINE. GET THE FIELDS ASSIGNED. LOOKUPS CAN BE:
  ## 1. Multiple assignment (Netcool $Var and @taxonomys are used to name SQL table taxonomys)
  ## 2. Single assignment (Netcool $Var or @taxonomy is used to name SQL table taxonomys)
  ## 3. No assignment in string building or condition checking (SQL table taxonomy is called EMBEDDED)
  ## VARABLES AND FIELD ARE USED TO NAME COLUMN HEADINGS
  ## MORE PROCESSING FURTHER DOWN.
  ## IDEALLY: TOKENIZE COMMENTS & STRINGS, THEN BUILD TABLES AND DETOKENIZE
  ##          BUT THAT WOULD REQUIRE ANOTHER REWRITE.
  ## NOTE: This assumes no nested or parallel lookups
  } elsif ($lines[$i]=~/^\[?\s*(.*?)\s*\]?\s*=\s*lookup\s*\(/ ) {
    $lookupfields=$1;
  ## FOR EMBEDDED LOOKUPS IN AN EQUATION OR CONDITION
  } elsif ($lines[$i]=~/lookup\s*\(\s*/ ) {
    $lookupfields="EMBEDDED";
  }

  ## ON A LINE BASIS IF IN THE TABLE, MEMORIZE AND FIGURE OUT COLUMN TYPES
  ## IDEALLY: TOKENIZE COMMENTS & STRINGS, THEN BUILD TABLES AND DETOKENIZE
  ##          BUT THAT WOULD REQUIRE ANOTHER REWRITE.
  if ($tbl) {
#print "TABLE LINE: $lines[$i]\n";
    ## STRIP ANY COMMENTS
    if ($lines[$i]=~ /^(\{\".*\"\},?)\s*#/) {
      $lines[$i]=$1;
#print "  FOUND $lines[$i]\n";
    }
    my $tmpline=$lines[$i];
    ## IS THE TABLE ENTRY WELL FORMED?
    if ($tmpline=~ /^\{\"(.*?)\"\},?/) {
      $tmpline=$1;
      my @row= split /\"\s*,\s*\"/,$tmpline;
#print "  ROWS: $#row $lines\n";

      ## DETERMINE TYPE AND SIZE OF LOOKUP FIELDS
      for (my $j=0; $j<=$#row; $j++) {
        if ($row[$j]=~ /^[ ]*\d+[ ]*$/ && $rowtype[$j] ne 'Char') {
          $rowtype[$j] = 0;
        } else {
          $rowtype[$j]=($rowtype[$j]>length($row[$j]))?$rowtype[$j]:length($row[$j]);
#print "CHAR $j '$row[$j]' '$rowtype[$j]'\n";
        }
      }
      #$table{$tbl}{'Data'}.=$lines[$i] . "~~$#rowtype" ."\n";
      $table{$tbl}{'Data'}.=$lines[$i] . "\n";
    ## REALLY SHOULD PARSE COMMENTS FIRST, THEN TABLE PARSE, THEN STRING PARSE,
    ## BUT THAT WOULD REQUIRE ANOTHER LOOP AND SO WE DO THE POOR MAN. 
    ## FOR NOW SKIP: NEW TABLE, COMMENT LINE, OR EMPTY LINE, 
    ##               OR COMMENT WITHIN TABLE DECL
    } elsif (($tmpline =~ /^\s*$/) || 
	     ($tmpline =~ /^#/) || 
	     ($tmpline=~/^table\s+.*?\s+=/) ||
             ($tmpline=~/^{$/ )) {
    ## WE HAVE NO IDEA WHAT HAPPENED HERE. FLAG AN ERROR
    } else {
      print "E: Invalid table entry detected: '$tmpline'\n";
    }
  }
#print "$lines[$i]\n";

  ## CHARACTER BY CHARACTER TOKENIZATION OF:
  ##   STRINGS,VARS,FIELDS,PROPS,FUNCTIONS, AND DISCARD COMMENTS
  for (my $j=0; $j<=length($lines[$i]); $j++) {
    my $a=substr($lines[$i],$j,1);
    ($DEBUG & 2) && print "  $lines[$i]\n";
    ($DEBUG & 2) && print "  At char $j '$a'\n";

    ## PROCESS STRING
    if (($a eq '"') || ($a eq "'")) {
      ($DEBUG & 2) && print "    STRING\n";
      my $k=$j+1;
      while (!(substr($lines[$i],$k,1) eq "$a") && $k<=length($lines[$i])) {
        ## IN STRING AND NOT TABLE NEXT CHARACTER NOT PROCESSED
	if (!$tbl && ($a eq '\\')) {
	  ## MAP OF NETCOOL ESCAPE TO JAVASCRIPT ESCAPE GOES HERE
	  $k++;
	}
        $k++;
      }
      if (substr($lines[$i],$k,1) ne "$a") {
        print "E: String failed to terminate. At $k found '" . substr($lines[$i],$k,1) . "' not $a\n"; 
	print "    On LINE: $lines[$i].\n";
      }
      $strings[$stringidx]=substr($lines[$i],$j,$k-$j+1);
      my $tmp=$a. $stringidx . $a;        ## REPLACE WITH INDEX & DELIMITERS
      substr($lines[$i],$j,$k-$j+1,$tmp);
      $j+=length($tmp)-1;
#print "  STRING: $strings[$stringidx]\n";
#print "  NEWLINE: $lines[$i]\n";
      $stringidx++;  ## NEXT STRING

    ## PROCESS FIELD
    } elsif ($a eq '@') {
      ($DEBUG & 2) && print "    FIELD\n";
      my $k=$j+1;
      while (substr($lines[$i],$k,1)=~/[A-Za-z0-9\_\-]/) {
        $k++;
      }
      $flds[$fldidx]=substr($lines[$i],$j,$k-$j);  ## GRAB FIELD NAME
      $flds[$fldidx]=~s:-:_:g;                     ## NAME SPACE DIFFERENCE VIA JAVASCRIPT
      $taxonomy{$flds[$fldidx]}++;            ## TALLY NEW INSTANCE OF THE FIELD
      my $tmp='@' . $fldidx . '@';         ## REPLACE WITH INDEX & DELIMITERS
      substr($lines[$i],$j,$k-$j,$tmp);    ## TOKENIZE INPUT
      $j+=length($tmp)-1;                  ## SKIP FORWARD IN PROCESSING
#print "  FIELD: $flds[$fldidx]\n";
#print "  NEWLINE: $lines[$i]\n";
      $fldidx++;                           ## NEXT SAVED FIELD
        
    ## PROCESS VARIABLE?  (special case $*)
    } elsif ($a eq '$') {
      ($DEBUG & 2) && print "    VARIABLE\n";
      my $k=$j+1;
      my $tmp;
      if(substr($lines[$i],$k,1) eq '*'){
        $vars[$varidx]='*';
        $tmp='$*$';
	$k++;
      } else {
        while (substr($lines[$i],$k,1)=~/[A-Za-z0-9\_\-]/) {
          $k++;
        }
        $vars[$varidx]=substr($lines[$i],$j,$k-$j);  ## GRAB VARIABLE NAME
        $vars[$varidx]=~s:-:_:g;                     ## NAME SPACE DIFFERENCE VIA JAVASCRIPT
        $tmp='$' . $varidx . '$';         ## ADD END DELIMITER (TO FIND EASIER LATER)
      }
      $taxonomy{$vars[$varidx]}++;            ## TALLY NEW INSTANCE OF THE VARIABLE
      substr($lines[$i],$j,$k-$j,$tmp);    ## TOKENIZE INPUT
      $j+=length($tmp)-1;                  ## SKIP FORWARD IN PROCESSING
#print "  VARIABLE: $vars[$varidx]\n";
#print "  NEWLINE: $lines[$i]\n";
      $varidx++;                           ## NEXT SAVED VARIABLE

    ## PROCESS PROPERTY?
    } elsif ($a eq '%') {
      ($DEBUG & 2) && print "    PROPERTY\n";
      my $k=$j+1;
      while (substr($lines[$i],$k,1)=~/[A-Za-z0-9\_\-]/) {
        $k++;
      }
      $props[$propidx]=substr($lines[$i],$j,$k-$j);
      $props[$propidx]=~s:-:_:g;           ## NAME SPACE DIFFERENCE VIA JAVASCRIPT
      $taxonomy{$props[$propidx]}++; 
      my $tmp='%' . $propidx . '%';
      substr($lines[$i],$j,$k-$j,$tmp);
      $j+=length($tmp)-1;
#print "  PROPERTY: $props[$propidx]\n";
#print "  NEWLINE:  $lines[$i]\n";
      $propidx++;                  ## NEXT STRING

    ## PROCESS END OF FUNCTION AND CHECK IF END OF LOOKUP
    } elsif ($a eq ')') {
      ($DEBUG & 2) && print "    END OF FUNCTION (NEST LEVEL OF $fxnest; LOOKUPNEST $lookupnest; LOOKUPCOMMA $lookupcomma)\n";
#print "  CLOSED BRACKET BEFORE  $fxnest\n"; 
      ## PROCESS LOOKUP
      if ($lookupnest == $fxnest && $lookupnest>0) {
	if (!$lookupcomma) {
	  print "E: Comma between key and tbl not found in lookup(key,tbl) on $lines[$i]\n";
	} else {
          my $newline='';
          my $lookupkey=substr($lines[$i],$lookupkeyidx+1,$lookupcomma-$lookupkeyidx-1);
	  my $lookuptbl=substr($lines[$i],$lookupcomma+1,$j-$lookupcomma-1);
	  $lookupkey=~s: ::g;
          $lookuptbl=~s: ::g;
          $lookuptbl=~s:-:_:g;  ## NAME SPACE DIFFERENCE BETWEEN RULES AND JAVASCRIPT
	  ## REPARSE TO GET THE TOKENIZED VERSION FOR ASSIGNMENTS AS THEY WERE NAMED BEFORE
          if ($lines[$i]=~/^\[?\s*(.*?)\s*\]?\s*=/ ) {
	    $lookupfields=$1;
	  }
          $table{$lookuptbl}{'Header'}=$lookupkey . ',' . $lookupfields; 
          my @tmpdef=($table{$lookuptbl}{'Default'} =~ /,/)?split /,/,$table{$lookuptbl}{'Default'}:$table{$lookuptbl}{'Default'};
          my @tmpvar=($lookupfields=~/,/)?split /,/,$lookupfields:$lookupfields;
          if ($tmpdef[0] eq 'NONE') {
            for (my $k=0; $k<=$#tmpvar; $k++) {
              $tmpdef[$k] = '""';
            }
          }
#print "  PRELINE:       $lines[$i]\n";
	  ## ONLY REPLACE LOOKUP()
#print "  LINE: $lines[$i]\n";
#print "  LOOKUPFIELDS: $lookupfields\n";
#print "  LOOKUPKEY: $lookupkey\n";
	  my $tmptbl= $taxonomy{"~$lookuptbl"};
	  $tmptbl='~' . $tmptbl . '~';
#print "  LOOKUPTBL: $lookuptbl $tmptbl\n";
          if ($lookupfields eq "EMBEDDED" ) {
            ($DEBUG & 2) && print "    EMBEDDED LOOKUP\n";
            $newline= "(" . $tmptbl . "\[$lookupkey\])?(" . $tmptbl . "\[$lookupkey\]\[$j\]?" . $tmptbl . "\[$lookupkey\]\[0\]:$tmpdef[0]):$tmpdef[0]";
	    substr($lines[$i],$lookupkeyidx-6,$j-$lookupkeyidx+6,$newline);
	    $j=$lookupkeyidx-6+length($newline);
	    $lines[$i]=$newline;
#print "  NEWLINE AT $j: $newline\n";
#print "  NOWLINE:       $lines[$i]\n";
#print "  REST         :" . substr($lines[$i],$j,length($lines[$i])-$j+1) . "\n";
	  ## ELSE REPLACE ENTIRE ASSIGNMENT EXPRESSION
          } else {
            ($DEBUG & 2) && print "    PRELINE:       $lines[$i] at $j '$a'\n";
	    $newline='';
            for (my $k=0; $k<=$#tmpvar; $k++) {
              #var test=(table['xxx'] )?(table['xxx'][0]?'Success':'default2'):'default1';
	      my $tmptbl= $taxonomy{"~$lookuptbl"};
	      $tmptbl='~' . $tmptbl . '~';
              ($DEBUG & 2) && print "    LOOKUPTBL2: $lookuptbl $tmptbl\n";
	      if ($k>0) {
                $newline.="\n";
	      }
              $newline.= "$tmpvar[$k] = (" . $tmptbl . "\[$lookupkey\])?(" . $tmptbl . "\[$lookupkey\]\[$k\]?" . $tmptbl . "\[$lookupkey\]\[$k\]:$tmpdef[$k]):$tmpdef[$k]";
            }
	    #$lines[$i]=$newline;
	    my $rest_line=substr($lines[$i],$j,length($lines[$i])-$j+1);
            ($DEBUG & 2) && print "    WAS AT $j '$a': $lines[$i] REMAINDER: $rest_line\n";
	    $lines[$i]=$newline . $rest_line;
	    $j=length($newline);
	    my $t=substr($lines[$i],$j,1); 
            ($DEBUG & 2) && print "    NOW AT $j '$t' : $lines[$i]\n";
	    #$lookupnest=0;  ## OUTSIDE LOOKUP
	    #$fxnest--;
#print "  CLOSED BRACKET  $fxnest\n"; 
	    #if ($fxnest<0) {
	    #  print "E: Too many ) found on $lines[$i]\n";
	    #}
	    #last;  ## ABORT ANY MORE PROCESSING
          }
	}
        ($DEBUG & 2) && print "    FUNCTION NEST LEVEL $fxnest\n";
        $lookupnest=0;  ## OUTSIDE LOOKUP
      }
      $fxnest--;
#print "  CLOSED BRACKET  $fxnest\n"; 
      if ($fxnest<0) {
        print "E: Too many ) found on $lines[$i]\n";
      }

    ## PROCESS MIDDLE OF LOOKUP
    } elsif (($lookupnest) && ($fxnest == $lookupnest) && ($a eq ',')) {
      ($DEBUG & 2) && print "    MIDDLE OF LOOKUP (NEST LEVEL $fxnest)\n";
      $lookupcomma=$j; 

    ## BRACKET
    } elsif ($a eq '(' ) {
      $fxnest++;
      ($DEBUG & 2) && print "    START OF CLAUSE. (NEST LEVEL $fxnest)\n";

    ## FUNCTION
    } elsif ($a =~ /[A-Za-z]/ ) {
#print "  OLDLINE:  NEST $fxnest $lines[$i]\n";
      ($DEBUG & 2) && print "    START OF FUNCTION (NEST LEVEL $fxnest)\n";
#print " OPEN BRACKET BEFORE  $fxnest\n"; 
      my $k=$j+1;
      while (substr($lines[$i],$k,1)=~/[A-Za-z0-9_\-]/) {
        $k++;
      }
      while (substr($lines[$i],$k,1) eq ' ') {
        $k++;
      }
      my $b=substr($lines[$i],$k,1);
      if ($b eq '(') {
        $fxnest++;
        ($DEBUG & 2) && print "    START OF CLAUSE OF A FUNCTION. (NEST LEVEL $fxnest)\n";
        while (substr($lines[$i],$k,1) eq ' ') {
          $k++;
        }
        $fxs[$fxidx]=lc(substr($lines[$i],$j,$k-$j)); ## NOTE: DO NOT TOKENIZE
#print "  FUNCTION: FXIDX $fxidx K $k FX '$fxs[$fxidx]' CNT $taxonomy{$fxs[$fxidx]} NEST $fxnest\n";
	my $dk=$fxs[$fxidx]=~s: ::g;  ## COUNT SPACES AND DECL END PTR
        $taxonomy{$fxs[$fxidx]}++; 
        substr($lines[$i],$j,$k-$j,$fxs[$fxidx]);
	$k-=$dk;  ## ADJUST END POINTER BACK FOR SPACES REMOVED
#print "  FUNCTION: FXIDX $fxidx K $k FX '$fxs[$fxidx]' CNT $taxonomy{$fxs[$fxidx]} NEST $fxnest\n";
#print "  NEWLINE:  $lines[$i]\n";
#print "  LOOKUP HERE? $fxnest : ",substr($lines[$i],$j,$k-$j)," \n";
        if (substr($lines[$i],$j,$k-$j) =~ /lookup/i) {
	  if ($lookupnest) {
            print "E: Nested lookup() calls detected. Skipping the inner lookup() calls.\nPlease modify rules to use temp variables with no nested lookup() calls and rerun the command for line:";
	    print "   $lines[$i]\n";
	  } else {
	    $lookupnest=$fxnest;
	    $lookupkeyidx=$k;
	  }
	}
        $fxidx++;
        $j=$k;
#print " OPEN BRACKET  $fxnest\n"; 
      } else {
        $j=$k-1;  ## REPROCESS LAST CHARACTER
      }

    ## DISCARD COMMENT
    } elsif ($a eq '#') {
      ($DEBUG & 2) && print "    COMMENT\n";
      $commentnum++;
      $lines[$i]=substr($lines[$i],0,$j);  ## NOTE -1 means whole string.
#print "COMMENT: $i:$j $lines[$i]\n";
      last; ## ABORT WITH NEWLINE UPTO, NOT INCLUDING COMMENT

    # INSIDE A STRING OR LOOKUP OR OTHER ... JUST KEEP TRUCKING.
    } else {
      ($DEBUG & 2) && print "    DEFAULT ACTION ON $a\n";
      ## DO NOT ADD IF INSIDE A STRING (WE NEVER ARE INSIDE A COMMENT)
#     if ($lookupnest>=1) {
#       print "    LOOKUP $lookupnest: '$a'\n";
#     }
    }

    ## CONCAT LINES WHERE PHRASES AND FUNCTIONS ARE SPLIT
    if ($j == length($lines[$i])) {
      if ($fxnest>0) {
	if ($i < $#lines) {   ## NEED AT LEAST ONE NEW LINE AHEAD TO CONCAT
	  if ($lines[$i+1] =~ /^if\(|^case |^default:|^switch|^log\(|^\\\\rules/) {
	    print "E: We hit a regular command while inside a function (i.e. '()') Stopping at line $i of $#lines.";
	    print "   Will not concatinate the second line to the first, because second looks like regular code.";
            print "   Check LOOP2 file. Nested function level $fxnest:\n  $lines[$i]\n  $lines[$i+1]\n";
            $lines=join("\n",@lines);
            print LOOP2 $lines;
            close(LOOP2);
	    exit;
	  }
          ($DEBUG & 2) && print "W: JOINING nested level $fxnest:\n  $lines[$i]\n  $lines[$i+1]\n";
          ($DEBUG & 2) && print "   $j:",substr($lines[$i],$j,1),"\n";
	  $j--;
          $lines[$i].=' ' . $lines[$i+1];
	  splice(@lines,$i+1,1);
          ($DEBUG & 2) && print "NOW: at line $i of $#lines at '$lines[$i]'\n";
        } else {
	  ($DEBUG & 2) && print "W: CANNOT JOIN nested level $fxnest as it is EOF:\n  $lines[$i]\n";
        }
      }
    }
  }
  if ($DEBUG & 2) {
    print "NOW: $i: $lines[$i]\n";
  }
}
if ($DEBUG & 1) {
  print "LOOP 2 COMPLETE\n";
}

if ($DEBUG & 128) {
  print "Loop 2 (POST): STRING ARRAY DUMP:\n";
  for (my $i=0; $i<=$#strings; $i++) {
    print "$i: $strings[$i]\n";
  }
  print "Loop 2 (POST): FIELD ARRAY DUMP:\n";
  for (my $i=0; $i<=$#flds; $i++) {
    print "$i: $flds[$i]\n";
  }
  print "Loop 2 (POST): VARIABLE ARRAY DUMP:\n";
  for (my $i=0; $i<=$#vars; $i++) {
    print "$i: $vars[$i]\n";
  }
  print "Loop 2 (POST): PROPERTY ARRAY DUMP:\n";
  for (my $i=0; $i<=$#props; $i++) {
    print "$i: $props[$i]\n";
  }
  print "Loop 2 (POST): FUNCTION ARRAY DUMP:\n";
  for (my $i=0; $i<=$#fxs; $i++) {
    print "$i: $fxs[$i]\n";
  }
  print "Loop 2 (POST): CODE ARRAY DUMP:\n";
  for (my $i=0; $i<=$#lines; $i++) {
    print "$i: $lines[$i]\n";
  }
  print "Loop 2 (POST): END OF ARRAY DUMPS\n";
}
($DEBUG & 1) && print "//  STRINGS:    $stringidx\n";
($DEBUG & 1) && print "//  TABLES:     $tblidx\n";
($DEBUG & 1) && print "//  FIELDS:     $fldidx\n";
($DEBUG & 1) && print "//  VARIABLES:  $varidx\n";
($DEBUG & 1) && print "//  PROPERTIES: $propidx\n";
($DEBUG & 1) && print "//  FUNCTIONS:  $fxidx\n";
($DEBUG & 1) && print "//  COMMENTS:   $commentnum\n";

$lines=join("\n",@lines);
my $commentlinenum=$lines=~s/^\s*\n//sgm; ## RM EMPTY LINES LEFT BY COMMENT LINES
my $tablenum=()=$lines=~/^table/gm;
$lines=~s/^table\s+~\d+~\s+=\s+\{.*?\n^\}\n(^default\s*=.*?\n)?//gms; ## CNT AND RM IMBEDDED TBLS AS THEY WILL BE REBUILT VIA %table
$lines=~ s:(//rulesfile\:.*?\n)(?=//rulesfile\:.*?\n)::g; ## REMEMBER LAST RULEFILE CASE 

## SAVE CODE
print LOOP2 $lines;
close(LOOP2);

##########################################################################
## 6 - Loop 3: CREATE SQL, BUFFER TABLES IN $TABLE
##########################################################################
## CREATE TBL STMTS
($DEBUG & 1) && print "//4: Loop 3: CREATE MYSQL FILE AND BUFFER TABLES INTO HASH.",&runtimer,"\n";
#print SQL "-- LOOKUP FILES AS TABLES\nDROP DATABASE IF EXISTS lookup;\nCREATE DATABASE lookup;\nUSE lookup;\n";
foreach my $item (sort keys %table) {
  print SQL "-- $item\n";
# print SQL "--      File: $table{$item}{'File'}\n";
  print SQL "--      Hdrs: $table{$item}{'Header'}\n";
  print SQL "--      Type: $table{$item}{'Type'}\n";
  my $rowcnt=$table{$item}{'Data'} =~ tr/\n//;
  print SQL "--      Rows: $rowcnt\n"; 
  if ($table{$item}{'Header'}) {
    #print "      Data: $table{$item}{'Data'}\n";
    $table{$item}{'Header'}=~ s:\$:Var_:g; # To keep from hitting key words
    $table{$item}{'Header'}=~ s:\@:Fld_:g; # To keep from hitting key words
    $table{$item}{'Header'}=~ s:\%:Prop_:g; # To keep from hitting key words
    my @hdr=split /,/,$table{$item}{'Header'};
    my @typ=split /\t/,$table{$item}{'Type'};
    print SQL "CREATE TABLE $item (\n";
    for (my $j=0; $j<=$#hdr; $j++) {
      if ($j>0) {
        print SQL ",\n";
      }
      print SQL " $hdr[$j]";
      if ($typ[$j]) {
        print SQL " CHAR($typ[$j])";
      } else {
        print SQL " INT";
      }
    }
    print SQL "\n);\n";
  }
}

## INSERT SQL STMTS & JAVASCRIPT HASH TABLES
foreach my $item (sort keys %table) {
  ## DO NOT ADD IF TABLE NOT REFERED TO IN RULES.
  if ($table{$item}{'Header'}) {
    my @data=split /\n/,$table{$item}{'Data'};
    my @typ=split /\t/,$table{$item}{'Type'};

    $table{$item}{'lookup'}="var Table_$item = \{";
#print "HERE $item\n $table{$item}{'Type'}\n";
    ## NOTE: First data item is NULL since CREATED VIA  .=\nDATA
    for (my $i=1; $i<=$#data; $i++) {
      if ($data[$i]=~ /^\{(.*)\},?$/ ) {
        $data[$i]="$1";
      } else {
        #print "W: Could not strip outside {} for row $i.\n";
      }
      $data[$i]=~s:^\"::g; #"
      $data[$i]=~s:\"$::g; #"
      my @datem=split /\"\s*,\s*\"/,$data[$i];
      my $vals;
      if ($i>1) {
        $table{$item}{'lookup'}.= ",";
      }
#print "DATAM B: $datem[0]\n";
      $datem[0]=~s/\\/\\\\/g;
      $datem[0]=~s/'/\\'/g;
#print "DATAM A: $datem[0]\n";
      $table{$item}{'lookup'}.= "\n'$datem[0]': \[";
#print "$i INSERT INTO $item ($table{$item}{'Header'}) VALUES ...\n";
      for (my $j=1; $j<=$#datem; $j++) {
#print "   $j $item: $datem[$j]: $data[$i]\n";
#print "DATAM B: $datem[$j]\n";
        $datem[$j]=~s/\\/\\\\/g;
        $datem[$j]=~s/'/\\'/g;
#print "DATAM A: $datem[$j]\n";
        if ($j>1) {
          $vals.=",";
          $table{$item}{'lookup'}.= ', ';
        }
        if ($typ[$j]>0) {
          $vals.="'$datem[$j]'";
          $table{$item}{'lookup'}.="'$datem[$j]'";
        } else {
          $vals.="$datem[$j]";
          $table{$item}{'lookup'}.="$datem[$j]";
        }
      }
      $table{$item}{'lookup'}.= "\]";
      print SQL "INSERT INTO $item ($table{$item}{'Header'}) VALUES ($vals);\n";
    }
    $table{$item}{'lookup'}.="\n};\n\n";  ## Close Javascript Hash object
  }
}
#foreach my $item (sort {$taxonomy{$b} <=> $taxonomy{$a}} keys(%taxonomy)) {
# if ($item=~/^[A-Za-z]/) {
#    print "$item $taxonomy{$item}\n";
# }
#}
#exit;

  
##########################################################################
## 7 - NORMALIZE AGGREGATE FILE VIA REGULAR EXPRESSIONS.
##########################################################################
## NOW THAT THINGS ARE TOKENIZED, IT IS MUCH EASIER TO NORMALIZE LANGUAGE
## MAKE HASH AND CNT UNIQUE VARIABLES, PROPERTIES, and OMNIBUS DATA FIELDS
## AS WELL AS UPDATE, DISCARD, LOG, AND DETAILS STATEMENTS
## NOTE: 
#   Trailing g will iterate globally through string
#   Trailing m = Treat string as multiple lines. That is, change "^" and 
#     "$" from matching the start of the string's first line and the end 
#     of its last line to matching the start and end of each line within 
#     the string.
#   Trailing s  = Treat string as single line. That is, change "." to match
#     any character whatsoever, even a newline, which normally it would 
#     not match.

($DEBUG & 1) && print "//5: NORMALIZE AGGREGATE FILE VIA REGULAR EXPRESSIONS.",&runtimer,"\n";
## TO ALLOW PROCESSING OF AN INCLUDE FILE BY FAKING AN INITIAL SWITCH STMT
## IF WE ARE IN THE MIDDLE OF ONE OR CONVERT ELSIF (...) TO IF (...)
if ( ($lines=~/^(elsif|if|switch|case)/)) {
  my $grab=$1;
  if ( $grab eq 'case' ) {
    s:^(case):switch\(DUMMY\) \{\n\1:sm;
  } elsif ( $grab eq 'elsif' ) {
    s:^(\s*)els(if):\1\2:sm;
  }
}

($DEBUG & 1) && print "//  a: Handle spacing",&runtimer,"\n";
my $assignmentnum=()=$lines=~/^[\@\$\%]/gm;
$lines=~ s/[\t ]+/ /g;      ## TRANSLATE MULTIPLE SPACES AND TABS TO A SPACE
#$lines=~ s/([^<>\!=])[ ]?=[ ]?([^<>\!=])/\1 = \2/g; ## ASIGNMENTS
$lines=~ s/[ ]?([<>\!=][<>\!=]?)[ ]?/\1/g;           ## 1-2 CHARS OPERATORS
$lines=~ s/[ ]?([\[\]\(\),\+:])[ ]?/\1/g;             ## 1 CHAR OPERATORS
$lines=~ s/[\n ]*\}[\n ]*/\n}\n/g;                   ## REMOVE EXTRA WHITESPACE AROUND }
$lines=~ s/[\n ]*\{[\n ]*/{\n/g;                     ## REMOVE EXTRA WHITESPACE AROUND {

($DEBUG & 1) && print "//  b: Force key words to lower case",&runtimer,"\n";
# FORCE TO LOWER CASE EXCEPT FILENAMES
$lines =~ s/^([^\/].*?)$/lc($1);/mge;

($DEBUG & 1) && print "//  c: Remember Rules File Names.",&runtimer,"\n";
$lines=~ s:(//rulesfile\:.*?\n)(?=//rulesfile\:.*?\n)::g; ## REMEMBER LAST RULEFILE CASE 
$lines=~ s:(}\s*\n+)(//rulesfile\:.*?\n)[\n\s]*(else.*?\n):\2\1\3:gm; ## IN CASE FILE NAME SPLITS } ELSE COMMAND
$lines=~ s:(^switch\s*\(.*?\n+[\s{\n]*)(//rulesfile\:.*?\n)[\n\s]*(case.*?\n):\2\1\3:gm; ## IN CASE FILE NAME SPLITS SWITCH CASE COMMAND

($DEBUG & 1) && print "//  d: Remove newlines within single statements",&runtimer,"\n";
$lines =~ s:(^table .*?\{\n\{)\n:\1:gm; ## TBL START
$lines =~ s:\n\}\n,\{\n:\},\n\{:g;      ## TBL MIDDLE
$lines =~ s:\"\n\}\n,\n\}\n:\"\},\n\}\n:g;  ## TBL END TYPE I

($DEBUG & 1) && print "//  e: Fix NcKL 4.3 bug of missing commas in table entries",&runtimer,"\n";
$lines =~ s:(^\s*(\{?\"\d+\",)*\"\d+\")\n\}\{\n:\1\},\n\{:gm; #NcKL4.3 Error
  ## SPECIFICALLY ERROR WITH MISSING COMMA AT END OF DATA ROW. FOR EXAMPLE:
  ##include-snmptrap\IETF\IETF-DISMAN-EVENT-MIB.include.snmptrap.lookup
  #table FailureReason =
  #{
  ##########
  # Reasons for failures in an attempt to perform a management
  # request.
  ##########
  #  {"-1","Local Resource Lack"}, ### localResourceLack
  #  {"-2","Bad Destination"} ### badDestination
  #  {"-3","Destination Unreachable"} ### destinationUnreachable
$lines =~ s:(^\s*\{(\"\d+\",)*\"\d+\")\n\}\n?\n\}\n:\1\}\n\}\n:gm; ## TBL END TYPE II
$lines =~ s:^\n::gm; ## Remove emptylines created by above stmt

($DEBUG & 1) && print "//  f: Remove newlines within if and switch clauses",&runtimer,"\n";
$lines =~ s/(^case .*?:)$/(my $subscope=$1)=~s:\n::g; $subscope;/smge; ## CONCAT SPLIT 'case .:'
my $elsifnum=$lines=~s/^}[\n\s]*else\s+if\(\s*/}else if\(/gms; ## CNT ELSE IF STMTS
my $elsenum =$lines=~s/(}[\n\s]*else[\s\n]*{)$/}else\{/gms; ## CONCAT SPLIT '} else {'
$lines=~s/((}\nelse )?if\(.*?{)$/(my $subscope=$1)=~s:\n: :g; $subscope=~s: $::g; $subscope;/smge; ## CONCAT SPLIT 'IF (.){'
$lines =~ s/\)\s*\{$/\)\{/gms; ## FIX PREVIOUS LINE SPECIAL CASE: 'if (.) {' => 'if (.){'

($DEBUG & 1) && print "//  g: Remove newlines within assignment and functions",&runtimer,"\n";
while ($lines =~ s/(^[\$\@\%][\w\-\_]+ = .*?[\,\+])\n(.*?)$/\1\2/mg) {};
while ($lines =~ s/(^[\$\@\%][\w\-\_]+ = .*?)\n([\,\+].*?)$/\1\2/mg) {};

($DEBUG & 1) && print "//  h: Recount brackets.",&runtimer,"\n";
my $b1=()=$lines =~/}$/gm; 
my $b2=()=$lines=~/} else/gm;
my $bracketend=$b1+$b2;
my $bracketstart=()=$lines=~/{$/gm;

##########################################################################
## 8 - CREATE EXCEL WORKBOOK TEMPLATE
##########################################################################
($DEBUG & 1) && print "//5: ORGANIZE DATA SCHEMA AND CREATE EXCEL WORKBOOK.",&runtimer,"\n";
## SORT COLUMNS FOR OUTPUT ACCORDING TO COUNTS
my $taxonomynum = scalar keys %taxonomy; 
my @colsrt;
my @colhdr= ( 'Conditions','Fields','Properties','Tables','Functions','Variables' );
foreach my $item (sort {$taxonomy{$b} <=> $taxonomy{$a}} keys(%taxonomy)) {
  if ($item =~ /^\@/ ) { # FIELDS 1st
    $colsrt[1][$colcnt[1]]=$item;
    $colcnt[1]++;
  } elsif ($item =~ /^\%/ ) { # PROPERTIES 2nd
    $colsrt[2][$colcnt[2]]=$item;
    $colcnt[2]++;
  } elsif ($item =~ /^\$/ ) { # VARIABLE 5th (LAST)
    $colsrt[5][$colcnt[5]]=$item;
    $colcnt[5]++;
  } elsif ($item =~ /^\~/ ) { # TABLE 3rd REMOVE LEADING ~
    if ($item=~/~(.*)/) {
      $item=$1;
    }
    $colsrt[3][$colcnt[3]]=$item;
    $colcnt[3]++;
  } else { # FUNCTIONS 4rd
    $colsrt[4][$colcnt[4]]=$item;
    $colcnt[4]++;
  }
  ($DEBUG & 4) && print "//  a. Add to PreExcel Tbl: $item\n";
}
#for (my $i=0; $i<$colcnt[3]; $i++) {
#   print "$i: $colsrt[3][$i]\n";
#}

($DEBUG & 1) && print "//  a. Completed Truth Table Columns. Fields: $colcnt[1]; Properties: $colcnt[2]; Tables $colcnt[3]; Variables: $colcnt[5]; Standing Functions: $colcnt[4]\n";

my $k=1;
$format->set_bold();
$format->set_color('blue');
for (my $i=1; $i<=5; $i++) {
  my $worksheet = $statworkbook->add_worksheet($colhdr[$i]);
  $worksheet->write(0,0,'#',$format);
  $worksheet->write(0,1,'Field',$format);
  $worksheet->write(0,2,'Cnt',$format);
  for (my $j=0; $j<$colcnt[$i]; $j++) {
    $worksheet->write($j+1,0,$j+1);
    $worksheet->write($j+1,1,$colsrt[$i][$j]);
    $worksheet->write($j+1,2,$taxonomy{$colsrt[$i][$j]});
  }
}
($DEBUG & 1) && print "//  b. Built Excel Workbook.",&runtimer,"\n";

## SPLIT CONCATENATED RULES FILES INTO INDIVIDUAL LINES
my @lines = split /\n/,$lines;
my $reallyprettylines='';

## BUILD PRETTY OUTPUT FOR RULES
for (my $i=0; $i <= $#lines; $i++ ) {
  my $line=$lines[$i];
  $space-=( $line =~ /^}/ )?1:0;
  for ( my $j=0; $j<$space; $j++) {
    $reallyprettylines.='  ';
  }
  $space+=( $line =~ /\{$/ )?1:0;
  $reallyprettylines.="$line\n";
}

## PRINT PRE-CASE LOOP 3: 
print LOOP3 "//****************** PRE-CASE CONVERSION RULES FILE ********************\n";
print LOOP3 $reallyprettylines;
close(LOOP3);
#exit;

##########################################################################
## 9 - LOOP 4: OUTPUT JAVASCRIPT (SKIP - NEEDS WORK.)
##########################################################################
if (1==2) {
($DEBUG & 1) && print "//6: BUILD JAVASCRIPT.",&runtimer,"\n";
## REDO TO GET RID OF SPACES
my $javascriptlines=$lines;
my $flddecl="";
my $vardecl="";
my $propdecl="";

($DEBUG & 1) && print "//  a. Javascriptified $i Identifiers.",&runtimer,"\n";

## PUT ; AT END OF EVERY NON CLAUSE LINE
($DEBUG & 1) && print "//  b. Append ; to each line",&runtimer,"\n";
$javascriptlines=~ s:([^{}])$:\1;:mg;

## FIX SWITCH STATEMENTS
## REMOVE THE ';' AND PRECEED WITH BREAK;
($DEBUG & 1) && print "//  c. Weak correct case statements",&runtimer,"\n";
$javascriptlines=~ s:^(case .*?);:break;\n\1:mg; ## REMOVE ';' and add BREAK;
$javascriptlines=~ s:^(default*\:.*?);:break;\n\1:mg; ## REMOVE ';' and add BREAK;
$javascriptlines=~ s:^(switch.*?\n)\s*break;:\1:mg;  ## REMOVE EXTRA BREAK AFTER SWITCH
#print "BEFORE:$javascriptlines\n";
$javascriptlines=~ s/(^case .*?:)$/(my $subscope=$1)=~s:\|:\:\ncase :g; $subscope;/smge; ## JAVASCRIPTIFY MULTI CASE STATEMENTS
#print "AFTER:$javascriptlines\n";

## CONVERT IF's  OR, AND, NOT
($DEBUG & 1) && print "//  d. Convert 'and','or', 'not' to javascript versions.",&runtimer,"\n";
$javascriptlines=~s/((}\nelse )?if\(.*?{)$/(my $subscope=$1)=~s:([\) ])and([ \(]):\1&&\2:g; $subscope=~s:([ \)])or([ \(]):\1||\2:g; $subscope=~s:([ \(])not([ \(]):\1\!\2:g; $subscope;/smge;

## CLEARS ARRAYS (CANNOT USE FUNCTION SINCE JAVASCRIPT PASSES VARNAME BY VALUE
##   So anything at the first level cannot be changed.
($DEBUG & 1) && print "//  e. Convert clear array functionality.",&runtimer,"\n";
$javascriptlines=~s:^clear\((.*?)\):\1.length=0;:gm;

## FUNCTIONS
## For function calls: update, remove, discard, setlog, details, setdefaulttarget, registertarget
## CAST CONSTANT/LITERALS TO STRING
#($DEBUG & 1) && print "//   Cast log level to a quoted litteral.",&runtimer,"\n";
$javascriptlines=~s:log\(\s*(\w+)\s*,\s*:log\('\1',:mg;
$javascriptlines=~s:setlog\(\s*(\w+)\s*\):setlog\('\1'\):g;

($DEBUG & 1) && print "//  f. Untokenize javascript.",&runtimer,"\n";
untokenize(\$javascriptlines,'Var_','Fld_','Prop_','Table_');

($DEBUG & 1) && print "//  g. Create Variable Declaration.",&runtimer,"\n";
foreach my $item (sort { length $b <=> length $a } keys(%taxonomy)) {
  ($DEBUG & 8) && print "//  Process $1 (count $taxonomy{$item}): $item\n";
  $i++;
  if ($item =~ /^\@/ ) { # FIELDS 1st
    my $newitem= 'Fld_' . substr($item,1);
    $flddecl.='var ' . $newitem . "='$i';\n";
    $javascriptlines=~s:$item:$newitem:gm;
  } elsif ($item =~ /^\%/ ) { # PROPERTIES 2nd
    my $newitem= 'Prop_' . substr($item,1);
    $propdecl.='var ' . $newitem . "='$i';\n";
    $javascriptlines=~s:$item:$newitem:gm;
  } elsif ($item eq '$*') { # $* (LAST)
    $javascriptlines=~s:\s*\$\*\$\s*:dumpallvars\(\):g;
  } elsif ($item =~ /^\$/ ) { # VARIABLE 4th (LAST)
    my $newitem= 'Var_' . substr($item,1);
    $newitem=~ s:-::g;
    $vardecl.='var ' . $newitem . "='$i';\n";
    $item= '\\' . $item;
    $javascriptlines=~s/$item/$newitem/gm;
  } elsif ($item =~ /^discard/ ) { # $* (LAST)
    my $newitem= 'return -1';  ## RETURN WITH -1 TO KILL INSERT
    $javascriptlines=~s:$item\n:$newitem\n:g;
  } else { # Functions and Tables 3rd or 5th
    ## No changes for functions or tables
  }
}

($DEBUG & 1) && print "//  h. Make the javascript have clause-based indentation.",&runtimer,"\n";
my $lines2=$javascriptlines;
my @lines = split /\n/,$lines2;
my $javascriptlines='';
for (my $i=0; $i <= $#lines; $i++ ) {
  my $line=$lines[$i];
  $space-=( $line =~ /^}/ )?1:0;
  for ( my $j=0; $j<$space; $j++) {
    $javascriptlines.='  ';
  }
  $space+=( $line =~ /\{$/ )?1:0;
  $javascriptlines.="$line\n";
}

print JS<<JAVASCRIPTCODE;
// FIELD DECLS
$flddecl

// VARIABLE DECLS
$vardecl

// PROPERTIES DECL
$propdecl

// NETCOOL TO MOOG FUNCTION MAP

//TRANSLATE \$\*
function dumpallvars() {
  console.log("Dumping all variables");
  return("Dump of all variables");
}

// HOSTNAME
function hostname() {
  console.log("HOSTNAME");
    return("localhost");
  }

// Lowercase(string)
function lower(c) {
  console.log("LOWER: Var:"+c+" TypeOf:" + typeof(c));
    return(c.toLowerCase());
  }

// Uppercase(string)
function upper(c) {
  console.log("UPPER: Var:"+c+" TypeOf:" + typeof(c));
  return(c.toLowerCase());
}

// Charcount(string)
function charcount(c) {
  console.log("CHARCOUNT (PROXY via length): Var:"+c+" TypeOf:" + typeof(c));
  return(c.length);
}

// Length(string)
function length(c) {
  console.log("LENGTH: Var:"+c+" TypeOf:" + typeof(c));
  return(c.length);
}

// STRING TO INTEGER CAST(string)
function int(i) {
  console.log("INT: Var:"+i+" TypeOf:" + typeof(c));
  return(i.parseInt); 
}

// ALL TRIM -- SAME IN MOOG AND NETCOOL
function trim(s) {
  console.log("TRIM: Var:"+s+" TypeOf:" + typeof(s));
  return s.replace(/^\\s+|\\s+\$/g,"");
}

// LEFT TRIM -- SAME IN MOOG AND NETCOOL
function ltrim(s) {
  console.log("LTRIM: Var:"+s+" TypeOf:" + typeof(s));
  return s.replace(/^\\s+/,"");
}

// RIGHT TRIM -- SAME IN MOOG AND NETCOOL
function rtrim(s) {
  console.log("RTRIM: Var:"+s+" TypeOf:" + typeof(s));
  return s.replace(/\\s+\$/,"");
}

// EXIST STRINGS
function exists(v) {
  console.log("EXISTS: Var1:"+v+" TypeOf1:" + typeof(v));
  if (typeof v == 'undefined' ) {
    return(0);
  } else {
    return 1;
  }
}

// MATCH STRINGS
function match(v,s) {
  console.log("MATCH: Var1:"+v+" Var2:"+s+" TypeOf1:" + typeof(v)+ " TypeOf2:" + typeof(s));
  if (v.val == s.val) {
    return(1);
  } else {
    return 0;
  }
}

// MATCH STRINGS UP TO MIN LENGTH OF EITHER
function nmatch(v,s) {
  console.log("NMATCH: Var1:"+v+" Var2:"+s+" TypeOf1:" + typeof(v)+ " TypeOf2:" + typeof(s));
  if (v.val == s.substring(0,v.length) ||
      v.substring(0,s.length) == s.val) {
    return(1);
  } else {
    return 0;
  }
}

// VALIDATEEXTRACT STRING FROM REGULAR EXPRESSION
function regmatch(v,re) {
  console.log("REGMATCH: Var1:"+v+" Var2:"+re+" TypeOf1:" + typeof(v)+ " TypeOf2:" + typeof(re));
  if (v.match(/re/)) {
    return 1;
  } else {
    return 0;
  }
}

// EXTRACT STRING FROM REGULAR EXPRESSION
function extract(v,re) {
  console.log("EXTRACT: Var1:"+v+" Var2:"+re+" TypeOf1:" + typeof(v)+ " TypeOf2:" + typeof(re));
  return v.match(/re/);
}

// ADD TO EXTRA FIELD (CURRENTLY DO NOTHING)
function nvp_add(f,b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11) {
  console.log("NVP_ADD: Var1:"+f+" Var2:"+b1+" TypeOf1:" + typeof(f)+ " TypeOf2:" + typeof(b1));
  return 1;
}

// SET LOG
function setlog(l,t) {
  console.log("SETLOG: LEVEL:"+l+" MESSAGE:"+t+" TypeOf1:" + typeof(l)+ " TypeOf2:" + typeof(t));
  return 1;
}

// LOG SOMETHING
function log(l,t) {
  console.log("LOG: LEVEL:"+l+" MESSAGE:"+t+" TypeOf1:" + typeof(l)+ " TypeOf2:" + typeof(t));
  return 1;
}

// DISCARD == return -1;
function discard() {
  console.log("DISCARD: WARNING - THIS SHOULD BE A return -1;");
  return 1;
}

// THIS IS HANDLED VIA NODE -- POINT TO THE RIGHT PLACE
function setdefaulttarget(t) {
  console.log("SETDEFAULTTARGET: (SKIPPED) TARGET:"+t+" TypeOf:" + typeof(t));
  return 1;
}

// THIS IS HANDLED VIA NODE -- POINT TO THE RIGHT PLACE
function registertarget(p,b,t) {
  console.log("SETREGISTERTARGET: (SKIPPED) PRIMARY:"+p+" TypeOf:" + typeof(p));
  return 1;
}

// DETAILS ARE SKIPPED
function details(t) {
  console.log("DETAILS: (SKIPPED) DETAILS:"+t+" TypeOf:" + typeof(t));
  return 1;
}

// UPDATE (FORCE UPDATE OF FIELD) SKIPPED
function update(t) {
  console.log("UPDATE: (SKIPPED) FIELD:"+t+" TypeOf:" + typeof(t));
  return 1;
}

// REMOVE ALSO SKIPPED
function remove(t) {
  console.log("REMOVE: (SKIPPED) REMOVE:"+t+" TypeOf:" + typeof(t));
  return 1;
}

// PRINTABLE ALSO SKIPPED
function printable(s) {
  console.log("PRINTABLE: (SKIPPED) REMOVE:"+s+" TypeOf:" + typeof(s));
  return 1;
}

//TABLE DEFINITIONS
JAVASCRIPTCODE
foreach my $item (sort keys %table) {
  print JS $table{$item}{'lookup'};
}
print JS "//MAIN CODE\n$javascriptlines";
#exit;
}

##########################################################################
## 10 - LOOP 5: CONVERT SWITCH STMTS TO IF-THEN-ELSE
##########################################################################
($DEBUG & 1) && print "//5: CONVERT SWITCH STMTS TO IF-THEN-ELSE",&runtimer,"\n";
my $level=0;
my $ttmp=int(($#lines-2)/10);
my @lines = split /\n/,$lines; # REVERT TO PRE JAVASCRIPT VERSION

$ttmp=($ttmp<1)?1:$ttmp;  ## PREVENT DIV BY 0 ON SMALL FILES

for (my $i=0; $i<=$#lines; $i++) {
  my $line=$lines[$i];

  if ($DEBUG & 1) {
    if (0==($i % $ttmp)) {
      print "//   Processed $i lines of $#lines",&runtimer,"\n";
    }
  }
  ($DEBUG & 16) && print "LOOP 5: $i: $line\n";

  ## CONVERT SWITCH AND FIRST CASE TO IF STMTSTMTS TO IF STMTS
  if ( $line =~ /^switch\s*\(\s*(.*)\s*\)/ ) {
    push(@switch,$1);
    splice(@lines,$i,1);
    $level++; $colcnt[0]=($level>$colcnt[0])?$level:$colcnt[0];
    my $caseid='';

    ($DEBUG & 16) && print "I: Level $level, Switch on $1 ColCnt $colcnt[0]";

    ## ADDED JUST IN CASE REGEX GOT CONFUSED
    if ($lines[$i]=~ /^case\s+(.*)\s*:$/) {
      $caseid=$1;
    } elsif ($lines[$i]=~ /^case\s+(.*)\s*:\s*(.*)$/) {
      $caseid=$1;
      print "W: IGNORING TAILING CASE INFO: '$2'\n" if ($2);
    } elsif ($lines[$i] =~ /^\/\/rulesfile:/ ) {
        $i++;  ## SKIP THIS LINE. IT IS OK
        if ($lines[$i]=~ /^case\s+(.*)\s*:\s*(.*)$/) {
          $caseid=$1;
          print "W: IGNORING TAILING CASE INFO: '$2'\n" if ($2);
        } else {
          print "E: NO MATCH FOR CASE: $lines[$i]:\n";
          $caseid='ERROR';
        }
    } else {
      print "W: SWITCH NOT FOLLOWED BY CASE:\n";
      print "W: ",$i,"'$lines[$i-1]'\n";
      print "W: ",$i,"'$line\n";
      print "W: ",$i+1,"'$lines[$i]'\n";
      print "W: ",$i+2,"'$lines[$i+1]'\n";

      ## REMOVE LINE AND TRY AGAIN
      splice(@lines,$i,1);
      if ($lines[$i]=~ /^case\s+(.*)\s*:\s*(.*)$/) {
        $caseid=$1;
        print "W: IGNORING TAILING CASE INFO: '$2'\n" if ($2);
      } else {
        print "E: NO MATCH FOR CASE: $lines[$i]:\n";
	$caseid='ERROR';

        # UG. FAIURE. PRINT OUT WHAT WE HAVE SO FAR 
        ($DEBUG & 16) && print "       FAILURE TO CREATE A CASEID FOR switch at line $i: $line\n";
	if ($DEBUG & 16) {
	  print LOOP5 "************** EXPANDED AND NORMALIZED RULES FILE ****************\n";
	  for (my $j=0; $j <= $#lines; $j++ ) {
	    my $line=$lines[$i];
	 
	    $space-=( $line =~ /^}/ )?1:0;
	    for ( my $k=0; $k<$space; $k++) {
	      print LOOP5 '  ';
	    }
	    $space+=( $line =~ /\{$/ )?1:0;
	    print LOOP5 "$line\n";
	  }
	}
	close(LOOP5);
        exit;
      }
    }
    $line="if($switch[$#switch] = $caseid){";
    ($DEBUG 16& 4) && print "       CREATE FOR $caseid => switch: $line\n";

# CONVERT OTHER CASES to ELSE IF.
  } elsif ( $line=~ /^case\s+(.*)\s*:\s*(.*)$/) {
    ## NOTE NEED TO SAVE $2 IN THIS CASE
    my $caseid=$1;
    print "W: IGNORING TAILING CASE INFO: '$2'\n" if ($2);
    $line= "} else if($switch[$#switch] = $caseid){";
    ($DEBUG & 16) && print "       LEVEL $level THIS IS case: $caseid => $line\n";

## CONVERT DEFAULT
  } elsif ( $line=~ /^default:/) {
    $line='} else {';
    pop(@switch);
    ($DEBUG & 16) && print "       default: ADD ELSE STMT\n";
  } elsif ($line =~ /^}$/) {
    $level--;
    ($DEBUG & 16) && print "       CLOSE BRACKET: Take it down a level to $level\n";
  } elsif ($line =~ /^if\(.*\){/) {
    $level++; $colcnt[0]=($level>$colcnt[0])?$level:$colcnt[0];
    ($DEBUG & 16) && print "       IF: Take it up a level to $level\n";
  } elsif ($line =~ /^table .*{/) {
    $level++; $colcnt[0]=($level>$colcnt[0])?$level:$colcnt[0];
    ($DEBUG & 16) && print "       TABLE: Take it up a level to $level\n";
  } else {
    ($DEBUG & 16) && print "       Not SWITCH, CASE, IF, ELSE, DEFAULT, or TABLE STATEMENT CHECK.\n";
  }  
    

# SAVE SWITCH CONVERTED TO IF STMTS LINE
  $lines[$i]=$line;
  ($DEBUG & 16) && print "NOW: $i: $line\n";
}

$lines=join("\n",@lines); ## REBUILD CONCATENTATED RULES FILES
($DEBUG & 1) && print "//  a. Untokenize code.",&runtimer,"\n";
my $emptyelse = $lines =~ s/} else {\n*}/}/gms; # RM EMPTY ELSE GLOBALLY
untokenize(\$lines,'$','@','%','');  ## UNTOKENIZE
my @lines = split /\n/,$lines; ## SPLIT RULES BACK OUT

($DEBUG & 16) && print "******************  CONVERT SWITCH STMTS ********************\n";
## INCASE VARS AT START OR END BEFORE CASES, WRAP ENTIRE RULES IN 
## TRUE CONDITION TO FORCE PROCESSING OF THE ENTIRE THING
splice(@lines,0,0,'if(NOP){');
$lines[$#lines+1]='}';

# PRINT OUT UPDATED RULES 
print LOOP5 "************** EXPANDED AND NORMALIZED RULES FILE ****************\n";
for (my $i=0; $i <= $#lines; $i++ ) {
  my $line=$lines[$i];

  $space-=( $line =~ /^}/ )?1:0;
  for ( my $j=0; $j<$space; $j++) {
    print LOOP5 '  ';
  }
  $space+=( $line =~ /\{$/ )?1:0;
  print LOOP5 "$line\n";
}
close(LOOP5);
#exit;

# PRINT OUT TRUTH TABLE STATISTICS
my $state=0;  ## TRACKS CURRENT STAGE
$colcnt[0]+=1; ## ADD IN FIRST ASSUMED CONDITION (NOP)

##########################################################################
## 11 - LOOP 6: BUILD TRUTH TABLE
##########################################################################
my $ROWBANDS = int($#lines / (4 * $MAXROWS)) +1; ## HOW MANY SHEET DEEP (ROWS)
$COLBANDS = int($colcnt[0] / $MAXCOLS)+int($taxonomynum/$MAXCOLS) +1; ## HOW MANY SHEET DEEP (ROWS)
($DEBUG & 1) && print "//7: BUILD TRUTH TABLE: $#lines lines; $colcnt[0] conditions; $taxonomynum elements. With an Excel workbook $ROWBANDS worksheets deep by $COLBANDS worksheets wide.",&runtimer,"\n";
#exit;

## HEADER: BUILD HEADER TO FILES (NOTE NOT IN PROCEDURE DUE TO BUG)
my $wscnt=0;
my $a=$colcnt[0]-1; ## DO NOT COUNT FIRST ASSUMED CONDITION (NOP)
print ALL "HEADER=2\tCONDITIONS=$a\tFIELDS=$colcnt[1]\tPROPERTIES=$colcnt[2]\tTABLES=$colcnt[3]\tFUNCTIONS=$colcnt[4]\tVARIABLES=$colcnt[5]\n";
#   print ALL "#\tFile\tCount\t";  ## RULESANALYSIS FIX
print ALL "#\tFile";
for (my $l=0; $l<$ROWBANDS; $l++) {
  my $ccnt=0;
#print "ADD1: Data$wscnt\n";
  $wsdata[$wscnt] = $statworkbook->add_worksheet("Data$wscnt");
  $wsdata[$wscnt]->write(0,0,"#",$format);
  $wsdata[$wscnt]->write(0,1,"File",$format);
  $wsdata[$wscnt]->write(1,0,"Count",$format);
  $ccnt=1;

  ## OUTPUT CONDITION, FIELDS, VARIABLES, PROPERTIES, TABLES, AND FUNCTIONS
  for (my $i=0; $i<=5; $i++) {
    if ($i != 3) {
      my $a=($i==0)?1:0; ## IGNORE FIRST ASSUMED CONDITION (NOP)
      $colcnt[$i]=($colcnt[$i])?$colcnt[$i]:0; ## MAKE SURE 0 NOT NULL
      for (my $j=$a; $j<$colcnt[$i]; $j++) {
        $ccnt++;
        if ($ccnt > $MAXCOLS) {
            $ccnt=0;
          $wscnt++;
  #print "ADD2: $l:$i:$j Data$wscnt\n";
          $wsdata[$wscnt] = $statworkbook->add_worksheet("Data$wscnt");
        }
        if ($i==0) {
            $wsdata[$wscnt]->write(0,$ccnt,"Cond-$j",$format);
          (!$l) && print ALL "\tCond-$j";
        } else {
#print " BUILD ROW: $wsdata[$wscnt]->write(0,$ccnt,\"$colsrt[$i][$j]\");\n";
#print " BUILD ROW: $wsdata[$wscnt]->write(1,$ccnt,\"$taxonomy{$colsrt[$i][$j]}\");\n";
          $wsdata[$wscnt]->write(0,$ccnt,"$colsrt[$i][$j]");
          $wsdata[$wscnt]->write(1,$ccnt,"$taxonomy{$colsrt[$i][$j]}");
          $colsrt[$i][$j]=~tr/\t/;/;
          (!$l) && print ALL "\t$colsrt[$i][$j]";
        }
      }
    }
  }

  ## UPDATE EXCEL FILE POINTER (NEW BAND OF ROWS TO BEGIN SINCE MAX ROWS
  #  PER FILE WAS HIT)
  $wscnt++;
}
print ALL "\n";

### END OF HEADER

## FORCE PROCESS LAST LINE
# NO LONGER NEEDED? IF SO, UPDATE LEFT/RIGHT BRACKET COUNTS
#$lines[$#lines]='}';
my $empelseidx=1000000000;
my @empelsecond;
my $varidx=0;
my $lb=0;
my $ttmp=int(($#lines-2)/10);  # FOR PROGRESS BAR
$ttmp=($ttmp<1)?1:$ttmp;

for (my $i=0; $i<=$#lines; $i++) {
#print "\nLINE3 BEFORE: $i: $state\n  COND $endconds $conds[$endconds]\n  VARS $endvars $vars[$endvars]\n  LINE3:'$lines[$i]'\n";
  ($DEBUG & 32) && print "\nLINE3 BEFORE: $i: $state\n  COND $endconds $conds[$endconds]\n  VARS $endvars $vars[$endvars]\n  LINE3:'$lines[$i]'\n";
  if ($DEBUG & 1) {
    if (0==($i % $ttmp)) {
      print "//  Processed $i lines",&runtimer,"\n";
    }
  }

  ## TRACK WHICH FILE WE ARE IN
  if ( $lines[$i]=~/^\/\/rulesfile:(.*)/ ) {
#print "  DO rulesfile\n";
    $ocurrfile=$currfile;
    $currfile=$1;
    if ( $lines[$i+1]=~ /^}\s*else if\s*\((.*)\)\{/ ) {
      $currfile.=";TMP";
    }
    
  ## IF or FIRST CASE in SWITCH
  } elsif ( $lines[$i]=~/^if\s*\((.*)\)\{/ ) {
#print "  DO if\n";
    my $tmpcond=$1;
    PrintOrBufferSingleRow();
    $varidx=0;
    if ($was eq 'var' || $was eq 'opend') { $equation.='x'; } 
    $was='op';
    $equation.="(("; 
    $state='IF';
    $endconds++;
    $endvars=0;
    $conds[$endconds]=$tmpcond;
    $empelsecond[$endconds]=0;  ## NO ELSE DETECTED YET
    $lb+=2;
    ($DEBUG & 32) && print "EQN: $i: +2 $lb: ((: $lines[$i]\n";

  # IF ELSE (or NON FIRST CASE in SWITCH)
  } elsif ( $lines[$i]=~ /^}\s*else if\s*\((.*)\)\{/ ) {
#print "  DO else if\n";
    my $tmpcond=$1;
    if ($currfile =~ /(.*);TMP$/) {
      my $tmp=$1;
      $currfile=$ocurrfile;
      PrintOrBufferSingleRow();
      $currfile=$tmp;
    } else {
      PrintOrBufferSingleRow();
    }
    $varidx=0;
    ## REMOVE BRACES AROUND VARIABLES
    $equation.=")+(";
    ($DEBUG & 32) && print "EQN: $i: $lb: )+(: $lines[$i]\n";
    $was='op';
    $state='ELSE IF';
    $endvars=0;
    $conds[$endconds]=$tmpcond;

  # ELSE (or DEFAULT in SWITCH)
  } elsif ($lines[$i] =~/^}\s*else\s*\{/ ) {
#print "  DO else\n";
    my $tmpcond='ELSE';
    PrintOrBufferSingleRow();
    $varidx=0;
    ## REMOVE BRACES AROUND VARIABLES
    $equation.=")+(";
    ($DEBUG & 32) && print "EQN: $i: $lb: )+(: $lines[$i]\n";
    $was='op';
    $state='ELSE';
    $endvars=0;
    $conds[$endconds]=$tmpcond;
    $empelsecond[$endconds]=1;  ## ELSE DETECTED NO NEED TO TAG ON ONE

  # END BRACKET (or end of CASE or DEFAULT in SWITCH)
  } elsif ($lines[$i] =~/^}/ ) {
#print "  DO }\n";
    PrintOrBufferSingleRow();
    $varidx=0;

    ## POPULATE EMPTY ELSE (NEEDED TO CALCULATE PATHS CORRECTLY)
    ## (NOTE: IGNORE THE OUTER if(NOP){} CLAUSE)
    if (!$empelsecond[$endconds] && $endconds>1) {
      $equation.=")+($empelseidx))";
      $empelseidx++;
    } else {
      $equation.="))";
    }
    $empelsecond[$endconds]='';
    $lb-=2;
    ($DEBUG & 32) && print "EQN: $i: -2 $lb: )): $lines[$i]\n";
    $was='opend';
    $state='ENDIF';
    $conds[$endconds]='';
    $endconds--;
    $endvars=0;

  # MULTI VARIABLE INTERPRETATIONS
  } elsif ($lines[$i] =~ /^\[\s*(.*?)\s*\]\s*=\s*(.*)/) {
#print "  DO MULTIPLE ASSIGNMENT\n";
    my $varlist=$1;
    my $value=$2;
    $state='MULTI VAR ASSIGN ';
    if ($was eq 'opend') { 
      $equation.="x$endequation"; 
      ($DEBUG & 32) && print "EQN: $i: $lb: x$endequation: $lines[$i]\n";
    } elsif ($was eq 'op') { 
      $equation.="$endequation"; 
      ($DEBUG & 32) && print "EQN: $i: $lb: $endequation: $lines[$i]\n";
    } elsif ($was ne 'var') { 
      print "W: $state: ($was) $lines[$i]\n"; 
    }
    $was='var';
    $varlist=~s: ::g; ## Remove space between vars to prevent inclusion in name
    my @varlist = split /,/,$varlist;
    foreach my $variable (@varlist) {
      $endvars++;
      if ( $ORDER ) {
        $varidx++;
        $vars[$endvars]="$variable~~$varidx:$value";
      } else {
        $vars[$endvars]="$variable~~$value";
      }
      $state.="$variable=$value;";
    }
    if ($DEBUG & 32) {
      print "****  VARIABLE STACK ($endvars)  ****\n";
      for (my $i=0; $i<=$endvars; $i++) {
        print "  $i: $vars[$i]\n";
      }
      print "*************************************\n";
    }

  # SINGLE VARIABLE INTERPRETATIONS
  } elsif ($lines[$i] =~ /^(.*?)\s*=\s*(.*)/) {
#print "  DO SINGLE ASSIGNMENT\n";
    my $variable=$1;
    my $value=$2;
    $state="SINGLE VAR ASSIGN $variable=$value";
    if ($was eq 'opend') { 
      $equation.="x$endequation"; 
      ($DEBUG & 32) && print "EQN: $i: $lb: x$endequation: $lines[$i]\n";
    } elsif ($was eq 'op') { 
      $equation.="$endequation"; 
      ($DEBUG & 32) && print "EQN: $i: $lb: $endequation: $lines[$i]\n";
    } elsif ($was ne 'var') { 
      print "W: $state: ($was) $lines[$i]\n"; 
    }
    $was='var';

    $endvars++;
    if ( $ORDER ) {
      $varidx++;
      $vars[$endvars]="$variable~~$varidx:$value";
    } else {
      $vars[$endvars]="$variable~~$value";
    }
    if ($DEBUG & 32) {
      print "****  VARIABLE STACK ($endvars)  ****\n";
      for (my $i=0; $i<=$endvars; $i++) {
        print "  $i: $vars[$i]\n";
      }
      print "*************************************\n";
    }

  # GRAB SET LANGUAGE AND TREAT AS SPECIAL VARS TO STORE
  } elsif ( $lines[$i]=~ /(^[\@\$\%]\w+|^[Ee]xit|^[Uu]pdate\s*\(|^[Rr]emove\s*\(.*?\)|^[Dd]iscard\s*$|^[Ll]og\s*\(|^[Ss]etlog\s*\(.*?\)|^[Dd]etails\s*\(.*?\))|^setdefaulttarget\(.*?\)/) { 
#print "  DO SPECIAL FUNCTION\n";
    my $variable = $1;
    if ($variable =~ /(.*?)\s*[\(]/) {
      $variable=$1;
    }
    my $value=$lines[$i];
    chomp($value);
    $state="SPECIAL VAR ASSIGN $value";
    if ($was eq 'opend') { 
      $equation.="x$endequation"; 
      ($DEBUG & 32) && print "EQN: $i: $lb: x$endequation: $lines[$i]\n";
    } elsif ($was eq 'op') { 
      $equation.="$endequation"; 
      ($DEBUG & 32) && print "EQN: $i: $lb: $endequation: $lines[$i]\n";
    } elsif ($was ne 'var') { 
      print "W: $state: ($was) $lines[$i]\n"; 
    }
    $was='var';

    $endvars++;
    if ( $ORDER ) {
      $varidx++;
      $vars[$endvars]="$variable~~$varidx:$value";
    } else {
      $vars[$endvars]="$variable~~$value";
    }
    if ($DEBUG & 32) {
      print "****  VARIABLE STACK ($endvars)  ****\n";
      for (my $i=0; $i<=$endvars; $i++) {
        print "  $i: $vars[$i]\n";
      }
      print "*************************************\n";
    }

  # HANDLE EXCEPTIONS
  } else { 
#print "  DO EXCEPTION\n";
    if ($was eq 'var' ) {
      $vars[$endvars].=$lines[$i];
      ## KNOWN EQUATION PATTERNS SO IGNORE THESE
      if ($vars[$endvars] =~ /\~\~([\w\$\%\@\"\']+(\(.*?\))?\s*[\+\/\*\.\|\-]\s*)+[\w\$\%\@\"\(\)\']+(\(.*?\))?$/ ) {
      } elsif ($vars[$endvars] =~ /\~\~([\w\$\%\@\"\']+(\(.*?\))?\s*[\+\/\*\.\|\-]\s*)+$/ ) {
      ## OTHERWISE ASSUME IT IS AN EQUATION AND WARN USER
      } else {
        $state ="W: Assuming assignment runon. Appending: $vars[$endvars]\n";
        $state.="W: " . $i-2 . ":           : $lines[$i-2]\n";
        $state.="W: " . $i-1 . ":           : $lines[$i-1]\n";
        $state.="W: " . $i   . ":  >>>>>>>>>: $lines[$i]\n";
        $state.="W: " . $i+1 . ":           : $lines[$i+1]\n";
        print "$state\n";
	## EXAMINE STRING (SHOULD HAVE BEEN SUPRESSED.)
	for (my $q=0; $q<=length($vars[$endvars]); $q++) {
	  my $q1=substr($vars[$endvars],$q,1);
	  my $q2=ord($q1);
	  print "$q: $q1 ($q2)\n"; 
	}
      }
    } else {
      $equation.='?';
      $state ="E: INVALID STATE: Came from $was\n";
      $state.="E: " . $i-2 . ":           : $lines[$i-2]\n";
      $state.="E: " . $i-1 . ":           : $lines[$i-1]\n";
      $state.="E: " . $i   . ":  >>>>>>>>>: $lines[$i]\n";
      $state.="E: " . $i+1 . ":           : $lines[$i+1]\n";
      print "$state\n";
    }
    ($DEBUG & 32) && print "EQN: $i: $lb: ?: $lines[$i]\n";
  }
  ($DEBUG & 32) && print "EQUATION: $equation\n";

  ($DEBUG & 32) && print "\nLINE3 AFTER: $i: $state\n  COND $endconds $conds[$endconds]\n  VARS $endvars $vars[$endvars]\n  LINE:'$lines[$i]'\n";
#print "\nLINE3 AFTER: $i: $state\n  COND $endconds $conds[$endconds]\n  VARS $endvars $vars[$endvars]\n  LINE:'$lines[$i]'\n";
}
($DEBUG & 1) && print "//  Processing Complete of $#lines lines",&runtimer,"\n";

##########################################################################
## 12 - OUTPUT EXCEL STATISTICS TAB
##########################################################################
my $tmp= $colcnt[0] + $taxonomynum;
my $e1=$elsenum-$emptyelse;
$e1=$taxonomy{'if'}-$elsenum;
$wsstats->write(0,0,'Description',$format);
$wsstats->write(0,1,'Count',$format);
$wsstats->write(1,0,'Total Columns in Truth table');
$wsstats->write(1,1,$tmp);
$wsstats->write(2,0,'  Max Condition Depth');
$wsstats->write(2,1,$colcnt[0]);
$wsstats->write(3,0,'  Unique fields, props, tbls, vars, & functions');
$wsstats->write(3,1,$taxonomynum);
$wsstats->write(4,0,'    Variables');
$wsstats->write(4,1,$colcnt[5]);
$wsstats->write(5,0,'    Properties');
$wsstats->write(5,1,$colcnt[2]);
$wsstats->write(6,0,'    Fields');
$wsstats->write(6,1,$colcnt[1]);
$wsstats->write(7,0,'    Tables');
$wsstats->write(7,1,$colcnt[3]);
$wsstats->write(7,0,'    Functions');
$wsstats->write(7,1,$colcnt[4]);
$wsstats->write(8,0,'Total Rows in Truth table');
$wsstats->write(8,1,$endequation);
$wsstats->write(10,0,'Total include files');
$wsstats->write(10,1,$includenum);
$wsstats->write(11,0,'Total missing include files');
$wsstats->write(11,1,$badincludenum);
$wsstats->write(13,0,'Total rulesfile lines (expanded)');
$wsstats->write(13,1,$rulesnum);
$wsstats->write(14,0,'Total rulesfile lines (cleaned)');
$wsstats->write(14,1,$#lines);
$wsstats->write(15,0,'Total blank lines');
$wsstats->write(15,1,$blanknum);
$wsstats->write(16,0,'Total assignments');
$wsstats->write(16,1,$assignmentnum);
$wsstats->write(17,0,'Total tables');
$wsstats->write(17,1,$tablenum);
$wsstats->write(18,0,'Total arrays');
$wsstats->write(18,1,$arraynum);
$wsstats->write(19,0,'Total comments');
$wsstats->write(19,1,$commentnum);
$wsstats->write(20,0,'Total bracket starts');
$wsstats->write(20,1,$bracketstart);
$wsstats->write(21,0,'Total bracket end');
$wsstats->write(21,1,$bracketend);

##########################################################################
## 13 - PROCESS EQUATION
##########################################################################
## REMOVE SPACES AND MASTER () AROUND ENTIRE EQUATION DUE TO ADDED STANZA:
## if (NOP) {}
($DEBUG & 1) && print "//8: PROCESS EQUATION",&runtimer,"\n";

## CREATE PREFIX ARRAY
my @prefix;
push (@prefix,'(');
while ($equation =~ /(\d+|\/|x|\-|\+|\(|\))/g) {
  push (@prefix, $1);
}
push (@prefix,')');

## REMOVE IF/ELSIF/ELSE and CASE STMTS with NO ASSIGNMENTS
## MIGHT BE NESTED DEEP (i.e include of empty USER or ADV file)

## HASH OFFSET FOR CURRENT CHARACTER
my %current = (
  "+" => 0, 
  "x" => 1, 
  "(" => 2, 
  ")" => 3,
  "d" => 4 
);

# PREV VS CURRENT:          +  x  (  )  d
my %equation_trim= ("+" => [2, 2, 0, 2, 0],
                    "x" => [2, 2, 0, 2, 0],
                    "(" => [1, 1, 0, 3, 0],
                    ")" => [0, 0, 4, 0, 0],
                    "d" => [0, 0, 4, 0, 4]);
my $a; ## FOR DEBUGGING
my $b; ## FOR DEBUGGING
for (my $i=1; $i<=$#prefix; $i++) {
  my $prev=($prefix[$i-1]=~/\d+/)?'d':$prefix[$i-1];
  my $curr=($prefix[$i]=~/\d+/)?'d':$prefix[$i];
  
  if ($DEBUG & 64) {
    my $a=($i>=7)?$i-7:0;
    my $b=($i<=$#prefix-8)?$i+8:$#prefix;
    my $tmp; for (my $j=$a; $j<=$b; $j++) { $tmp.=$prefix[$j]; }
    print "$i:$prev$curr $a-$b:$tmp\n";
  }
  my $action=$equation_trim{$prev}->[$current{$curr}];
  if ($action == 1) {
    splice(@prefix,$i,1);
    $i--;
  } elsif ($action == 2 ) {
    splice(@prefix,$i-1,1);
    $i-=2;
  } elsif ($action == 3 ) {
    splice(@prefix,$i-1,2);
    $i-=3;
  } elsif ($action == 4 ) {
    print "E: Invalid $prefix[$i-1] $prefix[$i]\n";
  }
  if (($DEBUG & 64) && ($action > 0)) {
      my $tmp; for (my $j=$a; $j<=$b; $j++) { $tmp.=$prefix[$j]; }
      print "    $action: $a-$b:$tmp\n";
  }
}

## EQUATION BRACKET COUNT AND BALANCE
$equation=join('',@prefix);
my $leftcnt = $equation =~ tr/\(/\(/;
my $rightcnt = $equation =~ tr/\)/\)/;
# NOTE: AFTER REMOVING (\d+) BRACKETS, BRACKETS MATCH
#   cat s | tr -d -c '(' | wc -c
#     977
#   cat s | tr -d -c ')' | wc -c
#     977
if ( $leftcnt != $rightcnt) {
  print <<EOF;
W: Bracket mismatch left: $leftcnt while right: $rightcnt
   Check for '?' in the equation and W: or E: messages in the output.
   EQUATION: $equation
EOF
}
($DEBUG & 64) && print "TRIMMED EQUATION: $equation\n";

## DETECT AND REPORT WHERE EQUATON HAS TOO MANY OPERATORS/OPERANS
## Position hash with anony array
my %precedence = (
  "!" => 0, 
  "+" => 1, 
  "-" => 2,
  "x" => 3, 
  "/" => 4,
  "(" => 5, 
  ")" => 6 
);
# PREFIX VS OPSTACK VAL:   !  +  -  x  /  (  )
my %action_hash = ("!" => [4, 1, 1, 1, 1, 1, 5],
                   "+" => [2, 2, 2, 1, 1, 1, 2],
                   "x" => [2, 2, 2, 2, 2, 1, 2],
                   "(" => [5, 1, 1, 1, 1, 1, 3]
               );
my @postfix;
my @op_stack;
$op_stack[0] = "!";
my $num;
my $op;
my $wasOp=1;
for (my $i=0; $i<=$#prefix; $i++) {
  my $item=$prefix[$i];
  my $err=0;
  my $a=$i-10; $a=($a<0)?0:$a;
  my $b=$i+10; $b=($b>=$#prefix)?0:$b;
  if ($item =~ /\d+/ ) {
    $num++;
    if (!$wasOp) {
      print "W: Rule follows a rule '$item' at position $i.\n";
      $err++;
    }
    $wasOp=0;
  } elsif ($item eq '(' || $item eq ')') {
    ## IGNORE BRACES
  } elsif ($item eq 'x' || $item eq '+') {
    $op++;
    if ($wasOp) {
      $err++;
      print "W: Operator follows an operator '$item' at position $i.\n";
    }
    $wasOp=1;
    if (abs($num-$op)>1) {
      print "W: Operators ($op) out of sync with rules ($num) with '$item' at position $i.\n";
      $err++;
    }
  } else {
    print "W: Equation has unrecognized character '$item' at position $i.\n";
    $err++;
  }
  if ($err) {
    for (my $j=$a; $j<=$b; $j++) {
      print "  $j: (ERRs:$err) $prefix[$j]\n";
    }
  }
}
if ($num != $op+1) {
  print "E: Operator $op operan $num mismatch.\n";
}

## PARSE PREFIX ARRAY INTO POSTFIX NOTATION
for (my $i = 0; $i<=$#prefix; $i++) {
  my $action;
  my $cur_op_stack;

  ## SAVE VARS
  if ($prefix[$i] =~ /^\d+$/) {
    push(@postfix, "$prefix[$i]");

  ## PROCESS EVERYTHING ELSE
  } else {
    $action=$action_hash{"$op_stack[$#op_stack]"}->[$precedence{$prefix[$i]}];
    if ($action == 1) {
      push (@op_stack, $prefix[$i]);
    } elsif ($action == 2) {
      push(@postfix, pop(@op_stack));
      $i--;
    } elsif ($action == 3) {
      pop(@op_stack);
    } elsif ($action == 4) {
      last;
    } elsif ($action == 5) {
      print "W: Prefix to Postfix conversion problem: $op_stack[$#op_stack] preceeds $prefix[$i] at offset $i.\n";
    }
  }
}

## REBUILD PREFIX EQUATION FROM POSTFIX TO REMOVE EXTRA BRACKETS. IE (()) => ()
my @stack;
for (my $i=0; $i<=$#postfix; $i++) {
  my $op=$postfix[$i];
  if( $op eq '+' ) {
    my $b=pop( @stack );
    my $a=pop( @stack );
    if ($a=~ /^\(((\d+\+)+\d+)\)$/ ) {  ## KILL EXTRA BRACKETS IN PURE ADDITION
      $a=$1;
    }
    if ($b=~ /^\(((\d+\+)+\d+)\)$/ ) {  ## KILL EXTRA BRACKETS IN PURE ADDITION
      $b=$1;
    }
    push @stack, '(' . $a . $op . $b . ')';
  } elsif( $op eq 'x') {
    my $b=pop( @stack );
    my $a=pop( @stack );
    push @stack, '(' . $a . $op . $b . ')';
  } elsif( $op =~ m/^\d+$/ ) {
    push(@stack,$op);
  }
}

## REMOVE OUTER () THAT ENCOMPASS THE EQUATION
if ($stack[0]=~ /^\((.*)\)$/) {
  $equation=$1;
}
($DEBUG & 64) && print "BRACKET CLEANED EQUATION: $equation\n";

## TRANSLATE (1+(2+...N)) => (1+2+...N)
#while ($equation=~ /(.*?)(\(\d+)\+\(((\d+\+)+\d+\))\)(.*)/) {
#  $equation = "$1+$2+$3+$5";
#}

## TRANSLATE ((2+...N)+1) => (2+...N+1)
#while ($equation=~ /(.*?)\((\((\d+\+)+\d+)\+(\d+\).*)/) {
#  $equation = "$1+$2+$4";
#}

## OUTPUT EQUATION TO SEPARATE FILE
if ($#stack ne 0) {
  print EQN "W: Equation not fully calculated. There were $#stack missing operators.\n";
  print "W: Equation not fully calculated. There were $#stack missing operators.\n";
}
print EQN "EQN: $equation\n";
print EQN "EQN: @postfix\n";

## CALCULATE TOTAL NUMBER OF POSSIBLE PATHS
my @stack;
for (my $i=0; $i<=$#postfix; $i++) {
  my $op=$postfix[$i];
  if( $op eq 'x' ) {
    push @stack, pop( @stack ) * pop( @stack );
  } elsif( $op eq '+' ) {
    push @stack, pop(@stack) + pop(@stack);
  } elsif( $op =~ m/^\d+$/ ) {
    push(@stack,1);
  }
}
$wsstats->write(23,0,'Possible Paths');
$wsstats->write(23,1,$stack[0]);
$wsstats->write(24,0,'Rules Equation');
$wsstats->write(24,1,$equation);

## CALCULATE POSSIBLE PATH DISTRIBUTION
my @stack;
for (my $i=0; $i<=$#postfix; $i++) {
  my $op=$postfix[$i];
  if( $op eq 'x' ) {
    my $b=pop(@stack); my $a=pop(@stack);   ## GRAB LAST TWO VALUES
    my @b=split /;/,$b; my @a=split /;/,$a; ## ARRAY OF ELEMENTS
    my @c; ## BUILD NEW ARRAY
    for (my $k=0; $k<=$#a; $k++) {
      for (my $j=0; $j<=$#b; $j++) {
        my ($aa,$ab)=split /,/,$a[$k]; #Fx Length, Path Count
        my ($ba,$bb)=split /,/,$b[$j]; #Fx Length, Path Count
	$c[$aa+$ba]+=$ab*$bb;
      }
    }
    my $newelem;
    for (my $j=0; $j<=$#c; $j++) {
      if ($c[$j]) {
        $newelem.="$j,$c[$j];";
      }
    }
    push(@stack,$newelem);

  ## ADD TOGETHER DISTRIBUTIONS
  } elsif( $op eq '+' ) {
    my @c; ## BUILD NEW ARRAY
  
    ## DEDUPLICATE TOP TWO STACK ELEMENTS INTO C INDEXED BY FIELDASSIGNMENTCNT
    for (my $j=0; $j<=1; $j++) {
      my $a=pop(@stack); ## GRAB STACK ELEMENT
      my @a=split /;/,$a; ## BREAK INTO DISTRIBUTION
      for (my $k=0; $k<=$#a; $k++) {
        my ($aa,$ab)=split /,/,$a[$k]; #FieldAssigned?, Path Count
        $c[$aa]+=$ab; ## DEDUPLICATE DISTRIBUTION
      }
    }

    ## BUILD THE NEW POPULATION FROM C INDEXED BY FIELD ASSIGNMENT COUNTS.
    my $newelem;
    for (my $j=0; $j<=$#c; $j++) {
      if ($c[$j]) {  ## SKIP OVER FIELD ASSIGNMENT COUNTS VALUES WITH NO PATHS
        $newelem.="$j,$c[$j];";
      }
    }

    ## PUSH THE POPULATION, REPLACING TOP TWO STACK ELEMENTS WITH NEW ELEMENT
    push(@stack,$newelem);

  ## ENCOUNTERED A FX STATEMENT RATHER THAN AN ADDITION OR MULTIPLY.
  ## SO PUSH INITIAL ELEMENT ON STACK
  } elsif( $op =~ m/^\d+$/ ) {
    push(@stack,'1,1;');  ## Fx length, Count
  } else {
    print "$op  AREADY DONE.\n";
  }
}

## OUTPUT EQUATION TO SEPARATE FILE
if ($#stack ne 0) {
  print EQN "W: Equation not fully calculated. There were $#stack missing operators.\n";
  print "W: Equation not fully calculated. There were $#stack missing operators.\n";
} else {
  print EQN "\nSTACK DISTRIBUTION\nIDX,FX EVALUATIONS,# PATHS WITH FX EVALUATIONS\n";
  for (my $j=$#stack; $j>=0; $j--) {
    my @c = split /;/,$stack[$j];
    for (my $k=0; $k<=$#c; $k++) {
      print EQN "$k,$c[$k]\n";
    }
  }
}
($DEBUG & 1) && print "//9: COMPLETE",&runtimer,"\n";
exit;


###############################################################################
# PROCEDURE: runtimer
# PURPOSE: Reports the latest time.
###############################################################################
sub runtimer {

  my $curr=time();
  my @parts = gmtime($curr-$start);
  my $rtn=sprintf (" (%02d:%02d:%02d)",@parts[2,1,0]);
  return($rtn);
}

###############################################################################
# PROCEDURE: usage
# PURPOSE: Reports available usage parameters for the program to the
#          standard out.
###############################################################################
sub usage {
  print <<EOF;
09/26/2015                  Daniel L. Needles              Version 0.9
PROGRAM: rules2tbl.pl                                                 
PURPOSE:
         IBM Tivoli Netcool rules are usually in an "evolved" state.
         1.  Accumulated Entropy due to syntax flexibility.
         2.  Keep state for external products (ITNM, ITM, TBSM,Impact)
         3.  Keep state for automation or Impact notifications,
             enrichments, and event automations.
         This program only converts the fields required for MOOG which
         fixes much of
         The functionality of
         solutions via the Product Function Catalog.
DESCRIPTION:
         The rules2tbl program converts Netcool rules files into two
         components:
         1. Table consisting of a sequential list of
            Conditions => Assignments(Fields,Variables,Properties,FXs)
         2. Equation determining the AND/OR and grouping () of
            Processing the equation and applying the table rows will
            result in the equivallent result of processing the rules.
            The terse and consistent rendering via the equation+table
            enables: analysis and clean up.
         NOTE: The rules use a very "loose" syntax. As such parsing
            doesn't always work. However the script can be corrected
            as these come up based on full out put from the log
              ./rules2tbl.pl -debug 4095 -input ((master-rule-file))
         NOTE: The program works on a subset of the rules as well:
              ./rules2tbl.pl -input ((rule-file))
PSUDO CODE:
1  - Includes and Init vars
2  - Commandline processing and open files
3  - Loop 1: Rules Aggregation into \@lines.
4  - Clean whitespace and basic lookup table normalization
5  - Loop 2: Tokenize, remove comments, memorize tables
6  - Loop 3: Create SQL, buffer tables in \$table
7  - Normalize aggregate file via regular expressions
8  - Create EXCEL workbook template
9  - Loop 4: Output JAVASCRIPT
10 - Loop 5: Convert SWITCH statements to IF-THEN-ELSE
11 - Loop 6: Build Truth Table
12 - Output EXCEL Statistics Tab
13 - Process Equation
INSTALLATION:
  WINDOWS
    1. Install PERL such as cygwin's or ActiveState
    2. Install PERL module SpreadSheet::WriteExcel
       If using Active State PERL use:
         ppm
         ppm> install SpreadSheet::WriteExcel
       If using cygwin's PERL, the installion can be done via CPAN
       NOTE: nmake and gcc are required when going to cygwin route.
         cpan Spreadsheet::WriteExcel
    3. If needed, install Open Office (free)
    4.  Install package. For example, with tar from cygwin:
          tar -zxvf DNA.tar.gz
  LINUX RedHat/CentOS:
    1. Install PERL and the PERL module Spreadsheet::WriteExcel.
          yum -y install perl "perl(Spreadsheet::WriteExcel)"
    2. If needed, install Open Office (free)
    3. Install DNA package.
          tar -zxvf DNA.tar.gz
  APPLE/MAC:
    1. Install the PERL module Spreadsheet::WriteExcel.
    2. If needed, install either MS Office or Open Office (free)
    3. Install PERL module SpreadSheet::WriteExcel
          sudo cpan Spreadsheet::WriteExcel
       The above command will generate a GUI prompt to install the XS
       libs (if you have not already done so). If prompted, repeat
       the command:
          sudo cpan Spreadsheet::WriteExcel
       Make sure the module compiles. Watch the output look for "OK"
       or just check return level.
    4. Install DNA package.
        tar -zxvf DNA.tar.gz
PACKAGE USAGE:
    The package contains the self contained script rules2tbl.pl and
    this readme as well as three example sets of rules:
       * NcKL3.7 - IBM's older NcKL rules
       * NcKL4.3 - IBM's newer NcKL rules
       * YahooRules - Yahoo's syslog rules
    To run the script and examine the output perform the following
    steps:
    1. Copy the script to the root of the rules directory.
      scp rules2tbl.pl ((rule-root-directory))
    2. Run the script from the directory and save the log output
      cd ((rule-root-directory))
      ./rules2tbl.pl -input snmptrap.rules > snnptrap.log
    3. Use either Excel or Open Office (free) to examine the xls file
       The program will create four files:
       snmptrap.xls : MS Office file containing statistics, raw table,
                      and equation.  Excel or OpenOffice can be used.
       snmptrap.eqn : Holds the number of paths as well as the rules
                      equation.
       snmptrap.tbl : Holds a tab delimited output of the table.
       snmptrap.log : The log file used to debug issues.
Install OpenOffice -
      See http://www.if-not-true-then-false.com/
            2010/install-openoffice-org-on-fedora-centos-red-hat-rhel/
PROGRAM USAGE:
rules2tbl.pl
                 [-debug <debug number 1-2047>]  (($DEBUG))
                   1   - Track program's progress.
                   2   - Tracing in program.
                   4   - Print out the interum rules before and after
                         switch stmts are converted to if-then-else.
                         Also dump all tokens.
           switch stmts are converted to if-then-else.
                 [-excel <fullpath to Excel output file>]
                 [-help]
                 [-input <rulesfile>]
                 [-nul <Character(s) to use for null value>]
                 [-order]
                 [-output none|<fullpath to raw CVS output file>]
                 [-mvdir <reference directory>]
  NOTE: Run program at rule root (i.e. \$OMNIHOME\\probes\\linux2x86\\)
        If the files have been moved, use mvdir to map the directory   
        references to the local directory                              
  
  EXAMPLE: rules2tbl.pl -input syslog.rules -mvdir /home/y/conf/netcool_rules/  > syslog.output
EOF
  exit;
}

##########################################################################
# PROCEDURE: untokenize   
# PURPOSE: Untokenize code replacing numberic enumerated types by their
#          actual values. This is needed to keep regular expressions from
#          affecting free format strings and literals.
##########################################################################
sub untokenize {
my $code=shift;
my $varhdr=shift;
my $fldhdr=shift;
my $prophdr=shift;
my $tblhdr=shift;
  
  my $codecnt = length($$code);
  for (my $j=0; $j<=length($$code); $j++) {
    if (($DEBUG & 1) && 0 == ($j % 25000)) { 
      $codecnt = length($$code);
      print "Untokenize: $j of $codecnt",&runtimer,"\n";
    }
    my $a=substr($$code,$j,1);
    #my $b=substr($$code,0,$j-1);
    #my $c=substr($$code,$j+1,length($$code)-$j)
    my $c=(length($$code)-$j < 80)?substr($$code,$j+1,length($$code)-$j):substr($$code,$j+1,80);
    my $d=(split(/\n/,$c))[0];
    ($DEBUG & 8) && print "Untokenize: $j '$a' '$d'",&runtimer,"\n";
    if ($a eq '$') {
      my $sz=0;
      my $val='';
      if ($c=~ /^(\d+)/) {
        $val=$1;
        $sz=length($val);
        my $tmp=$varhdr . substr($vars[$val],1,length($vars[$val])-1);
        substr($$code,$j,$sz+2,$tmp);
        $j+=length($tmp);
        ($DEBUG & 8) && print "  Process string $tmp",&runtimer,"\n";
      } elsif ($c=~ /^\*/) {
    #   $tmp='dumpallvars()';
    #   substr($$code,$j,3,$tmp);
    #   $j+=length($tmp);
        $j+=2;
        ($DEBUG & 8) && print "  Process \$*",&runtimer,"\n";
      } else {
        print "W: Expected token variable but found nothing\n";
        print "   CONTEXT:\n    ",substr($$code,$j-60,120),"\n";
      }
    } elsif ($a eq '@') {
      my $sz=0;
      my $val='';
      if ($c=~ /^(\d+)/) {
        $val=$1;
        $sz=length($val);
        my $tmp=$fldhdr . substr($flds[$val],1,length($flds[$val])-1);
        substr($$code,$j,$sz+2,$tmp);
        $j+=length($tmp);
        ($DEBUG & 8) && print "  Process field $tmp",&runtimer,"\n";
      } else {
        print "W: Expected token field but found nothing\n";
        print "   CONTEXT:\n    ",substr($$code,$j-60,120),"\n";
      }
    } elsif ($a eq '%') {
      my $sz=0;
      my $val='';
      if ($c=~ /^(\d+)/) {
        $val=$1;
        $sz=length($val);
        my $tmp=$prophdr . substr($props[$val],1,length($props[$val])-1);
        substr($$code,$j,$sz+2,$tmp);
        $j+=length($tmp);
        ($DEBUG & 8) && print "  Process property $tmp",&runtimer,"\n";
      } else {
        print "W: Expected token property but found nothing\n";
        print "   CONTEXT:\n    ",substr($$code,$j-60,120),"\n";
      }
    } elsif ($a eq '~') {
      my $sz=0;
      my $val='';
      if ($c=~ /^(\d+)/) {
        $val=$1;
        $sz=length($val);
        my $tmp=$tblhdr . substr($tbls[$val],0,length($tbls[$val]));
  #print "LOOKUP $j $val of $sz replace with $tmp\n";
  #print "CONTEXT:\n    ",substr($$code,$j-60,120),"\n";
        substr($$code,$j,$sz+2,$tmp);
  #print "AFTER CONTEXT:\n    ",substr($$code,$j-60,120),"\n";
        $j+=length($tmp);
        ($DEBUG & 8) && print "  Process table $tmp",&runtimer,"\n";
      } else {
        print "W: Expected token table but found nothing\n";
        print "   CONTEXT:\n    ",substr($$code,$j-60,120),"\n";
      }
  
    } elsif ($a eq '"' || $a eq "'") {
      my $sz=0;
      my $val='';
      if ($c=~ /^(\d+)$a/) {
        $val=$1;
        $sz=length($val);
        substr($$code,$j,$sz+2,$strings[$val]);
        $j+=length($strings[$val]);
        ($DEBUG & 8) && print "  Process string $strings[$val]",&runtimer,"\n";
      } else {
        $j++;  ## SKIP SECOND QUOTE
        ($DEBUG & 8) && print "  Skip string's end quote $a",&runtimer,"\n";
      }
    }
  }
}

##########################################################################
# PROCEDURE: processfile
# PURPOSE: Recursively grab all lines into global buffer by following
#          include statements (LOOP 1)
#          For any included tables convert them to embedded table format
#          This is needed so string and comment parsing works as the
#          strings in included tables ARE NOT enclosed in quotes.
#          This is a much cheaper approach logically.
##########################################################################
sub processfile {
my $file=shift;
my $cnt=shift;
my $deep=shift;
my $deepnest=shift;
my $srcfile=shift;
my $tblmode=shift;
my $olddeepnest=$deepnest;

my $FH;

  ## PROPERLY REFERENCE FILE RELATIVE TO CURRENT STRUCTURE
  $file=~s:$SRCDIR:$DSTDIR:g;

  ## FILE NOT FOUND!! WARN AND CONTINUE
  if (!($FH = IO::File->new($file))) {
    $badincludenum++;
    print "W: $srcfile included a file that doesn't exist: $file\n";
  ## PROCESS FILE THAT WAS FOUND
  } else {
    ## PARSE OUT FILE NAME FROM FULL PATH INTO $f
    my $f=$file;
    if ($f =~ /^.*\/(.*)/) {
      $f=$1;
    }
    ($DEBUG & 2) && print "LINE 0: INCLUDE ENTER: \"$file\": \"$f\": Level: $deep Files: $cnt: LevelPath: $deepnest\n";

    my $enterfileflag=1;  ## NEEDED BECAUSE FIRST LINE DETERMINES IF 
                          ## WE MARK WE ENTERED THE FILE
    ## PROCESS EVERY LINE OF THE FILE
    while (my $line=<$FH>) {
      chomp($line);   ## End of file might miss \n so remove and force on \n.

      ## IF ENTERING FILE AND NOT INCLUDED TABLE, SAY SO
      if ($enterfileflag) {
        if (($tblmode ne "#TABLE\t" ) && 
            (!($line =~ /^\s*table\s+.*?\s*=\s*\".*?\"/i))) {
          $lines.="\n\/\/rulesfile:$file\n";
	}
        $enterfileflag=0;
      }

      ## ARE WE INSIDE AN INCLUDED TBL? CONVERT TO EMBEDDED TBL
      ## NO COMMENTS ARE ALLOWED IN THESE TABLES, SO CONVERSION WORKS
      ## BEFORE THE STRING AND COMMENT TOKENIZATION. SPECIFICALLY:
      ## 1. DELIMITER FROM \t TO ,
      ## 2. ADD:
      ##   FIELD ENCLOSE WITH "
      ##   LINE ENCLOSE WITH {}
      ##   TABLE ENCLOSE WITH {}
      if ($tblmode ne "#TABLE\t" ) {
        $lines.="$line\n";
      } else {
	$line=~s:\t:\",\":g;
	$line='"' . $line . '"';
        $lines.="\{$line\},\n";
      }
      $cnt++;
      ($DEBUG & 2) && print "LINE0: $f ADDED $cnt: \"$line\"\n";
      if ($DEBUG & 1) {
        if (0==($cnt % 100000)) {
	  print "//   Processed $cnt lines",&runtimer,"\n";
	}
      }

      ## IF INCLUDED RULES OR TABLES, FIND WHERE IT IS, AND PROCESS IT
      my $tmpinc;
      if (( $line =~ /^\s*include\s+\"(.*?)\"\s*$/i ) || 
          ( $line =~ /^\s*table\s+.*?\s*=\s*\"(.*?)\"/i)) {
#print "  ENTERING INCLUDE OR TABLE\n";

        ## MARK IF THIS IS AN INCLUDE TABLE AS IT NEEDS CONVERTING
        if ( $line =~ /^\s*table\s+.*?\s*=\s*\"(.*?)\"/i) {
	  $tblmode="#TABLE\t";
	  $lines.="\{\n";
	} else {
	  $tblmode='';
	}

	## GRAB TABLE FILE PATH AND CONVERT TO RELATIVE DIRECTORY
	## NOTE: NEED TO ADD AN OPTION TO PARAMETER PASS WHAT TO REMOVE
        $tmpinc = $1;
        $includenum++;
	if ( $tmpinc =~ /\$.*?\/(.*)/) {
	  $tmpinc=$1;
	  if ( $tmpinc =~ /probes\/(.*)/) {
	    $tmpinc=$1;
	    if ( $tmpinc =~ /linux2x86\/(.*)/) {
	      $tmpinc=$1;
	    }
	  }
        } elsif ( $tmpinc=~ /^\/opt\/netcool\/rules\/(.*)/) {
          $tmpinc=$1;
        } elsif ( $tmpinc=~ /^\/opt\/netcool\/(.*)/) {
          $tmpinc=$1;
        #} elsif ( $tmpinc=~ /^\/home\/y\/conf\/netcool_rules\/(.*)/) {
        #$tmpinc=$1;
        }

	## UPDATE TRACKING AND STATS
        $includenum++;
	$deep++;
	$deepnest.=":$f";

	## RECURSIVELY CALL THIS ON THIS INCLUDE OR TABLE
        $cnt=processfile($tmpinc,$cnt,$deep,$deepnest,$file,$tblmode);

	## WOW WE'RE BACK. ONLY LOG THAT IN IT WASN'T AN INCLUDED TABLE.
	## IF IT WAS INCLUDED WE FAKE THAT WE NEVER LEFT (WHICH MIRRORS
	## WHAT AN EMBEDDED TABLE IS.)
        if ($tblmode ne "#TABLE\t" ) {
          $lines.="\n\/\/rulesfile:$file\n";
	## IF IT IS AN INCLUDED TABLE, ENCLOSE ENTIRE TABLE IN {}.
	} else {
	  $lines.="\n\}\n";
	}
	$tblmode='';

	$deep--;
	$deepnest=$olddeepnest;
        ($DEBUG & 2) && print "LINE 0: INCLUDE EXIT: \"$file\": \"$f\": Level: $deep Files: $cnt: LevelPath: $deepnest\n";
      # NO WORK FOR NON TABLES
      #} else {
      }
    }
  }
  return($cnt);
}

###############################################################################
# PROCEDURE: commandline
# PURPOSE: Parses commandline parameters and sets their values
###############################################################################
sub commandline {
my $HELP;
my $order;

  GetOptions("debug=i"     => \$DEBUG,
	     "input=s" => \$FILENAME,
	     "order" => \$order,
             "output=s"   => \$AFD,
             "excel=s"   => \$SFD,
             "nul=s"   => \$UNASSIGNED,
             "mvdir=s" => \$MVDIR,
             'help|?' => \$HELP);
  if ( $order ) {
    $ORDER=1;
  }
  if ( $HELP ) {
    die usage();
  }
  if ($FILENAME ne 'snmptrap.rules') {
    my ($a,$b)= split /\./,$FILENAME,2;
    if ($SFD eq 'snmptrap.xls') {
      $SFD=$a . '.xls';
    }
    if ($AFD eq 'snmptrap.tbl') {
      $AFD=$a . '.tbl';
    }
    if ($EQN eq 'snmptrap.eqn') {
      $EQN=$a . '.eqn';
    }
    if ($SQL eq 'snmptrap.sql') {
      $SQL=$a . '.sql';
    }
    if ($JS eq 'snmptrap.js') {
      $JS=$a . '.js';
    }
  }
  if ($MVDIR) {
    ($SRCDIR,$DSTDIR)=split /:/,$MVDIR;
    $SRCDIR=~ s:\/:\\\/:g;
    $DSTDIR=~ s:\/:\\\/:g;
  }
}

##########################################################################
# PROCEDURE: PrintOrBufferSingleRow 
# PURPOSE: Buffer a single row of the output into the tables tblcondition
#          and tblfield (stored as arrays)
##########################################################################
sub PrintOrBufferSingleRow {

  ## ONLY SAVE ROWS THAT MATTER
  if ($endvars == 0 ) {
    return();
  }

  ## CLEAR BUFFER ROW FOR CONDITIONS, FIELDS, AND VARIABLES
  for (my $j=1; $j<= $colcnt[0]; $j++) {
    if ($j<=$endconds) { 
      $conditions[$j]=$conds[$j];
    } else {
      $conditions[$j]="$UNASSIGNED";
    }
  }
  foreach my $item (sort keys %taxonomy) {
    $taxonomy{$item}="$UNASSIGNED";
  }

  ## BUILD TRUTH TABLE: CONDITIONS
  if ($DEBUG & 2) {
    print "\n************* BUILD ROW #$endequation OF TRUTH TABLE *************\n";
    print "CONDITIONS:\n";
    for ($i=1; $i<=$endconds; $i++) { 
      print "    COND: $i:$conds[$i]\n";
    }
    print "\nVARIABLES:\n";
  }

  ## BUILD TRUTH TABLE: FIELDS AND VARIABLES 
  for ($i=1; $i<= $endvars; $i++) {
    my ($variable,$value)=split /~~/,$vars[$i];
    if ( !undef($taxonomy{ $variable  }) ) {
## FUTURE ENHANCEMENT
#     ## IF VARIABLE NESTED IN CURRENT VALUE, RECURSE
#     print "VAL=$value\n";
#     print "VAR=$variable\n";
#     if ($value =~ /$variable/) {
#	$value=~s:$variable:$taxonomy{$variable}:g;
#     }
      $taxonomy{$variable}=$value;
      ($DEBUG & 2) && print "    FIELD: $i: $variable=$value\n";
    } else {
      print "E: Unexpected field, variable, property, function, or table: '$variable'\n";
    } 
  } 

  ## CALCULATE FILE OFFSET DUE TO ROW NUMBER
  my $ccnt=0;
  my $wscnt=int($endequation/$MAXROWS)*$COLBANDS;
  my $wsrow=$endequation%$MAXROWS;
  print ALL "$endequation\t$currfile";

# ## OVER 50K ROWS, THEN CREATE NEW SPREADSHEETS
# ## BUG: add_worksheet() within a procedure zeros out file
# if (0 ==($endequation % $MAXROWS)) {
#   for (my $j=$wscnt; $j<$wscnt+$COLBANDS; $j++) {
#     $wsdata[$j] = $statworkbook->add_worksheet("Data$j");
#   }
# }
  (($DEBUG & 2) && ($wscnt != $wsold)) &&
    print "I: Worksheet: $wscnt, ($endequation / $MAXROWS )* $COLBANDS Row: $endequation Current File: $currfile\n";
  $wsold=$wscnt;
  $wsdata[$wscnt]->write($wsrow+1,0,$endequation);
  $wsdata[$wscnt]->write($wsrow+1,1,$currfile);
  $ccnt=1;
  for (my $j=2; $j<=$colcnt[0]; $j++) {
    print ALL "\t$conditions[$j]";
    $ccnt++;
    if ($ccnt > $MAXCOLS) {
      $ccnt=0;
      $wscnt++;
    }
    $wsdata[$wscnt]->write($wsrow+1,$ccnt,$conditions[$j]);
  }

# foreach my $item (sort keys %taxonomy) {
#   print ALL "\t$taxonomy{$item}";
# }
  for (my $l=1; $l<=5; $l++) {
    if ($l != 3) {
      for (my $j=0; $j<$colcnt[$l]; $j++) {
        print ALL "\t$taxonomy{$colsrt[$l][$j]}";
        $ccnt++;
        if ($ccnt > $MAXCOLS) {
          $ccnt=0;
          $wscnt++;
        }
        $wsdata[$wscnt]->write($wsrow+1,$ccnt,$taxonomy{$colsrt[$l][$j]});
      }
    }
  }
  print ALL "\n";
  ($DEBUG & 2) && print "EQUATION:\n    EQ ($endequation) $equation\n";
  ($DEBUG & 2) && print "\n**************************************************************\n";

  ## ADD BLANK ROW TO TABLE
  $endequation++;
}

