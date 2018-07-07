# NetcoolRuleParser
Analytics for Netcool Rules and converts the functionality to javascript to run under nodejs.

# PROGRAM: 

rules2tbl.pl                                                 

# PURPOSE:                                                              

          IBM Tivoli Netcool rules are usually in an "evolved" state.  
          1.  Accumulated Entropy due to syntax flexibility.           
          2.  Keep state for external products (ITNM, ITM, TBSM,Impact)
          3.  Keep state for automation or Impact notifications,       
              enrichments, and event automations.                      
          This program only converts the fields required for MOOG which
          fixes much of 2 and 3 but some 1 entropy will remain.     
          The functionality of 2 and 3 is provided via adding canned 
          solutions via the Product Function Catalog.                  

# DESCRIPTION:                                                          

          The rules2tbl program converts Netcool rules files into two  
          components:                                                  
          1. Table consisting of a sequential list of                  
             Conditions => Assignments(Fields,Variables,Properties,FXs)
          2. Equation determining the AND/OR and grouping () of 1.    
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

# PSUDO CODE:                                                           

 1  - Includes and Init vars                                           
 2  - Commandline processing and open files                            
 3  - Loop 1: Rules Aggregation into @lines.                            
 4  - Clean whitespace and basic lookup table normalization            
 5  - Loop 2: Tokenize, remove comments, memorize tables               
 6  - Loop 3: Create SQL, buffer tables in $table                      
 7  - Normalize aggregate file via regular expressions                 
 8  - Create EXCEL workbook template                                   
 9  - Loop 4: Output JAVASCRIPT                                        
 10 - Loop 5: Convert SWITCH statements to IF-THEN-ELSE                
 11 - Loop 6: Build Truth Table                                        
 12 - Output EXCEL Statistics Tab                                      
 13 - Process Equation                                                 

# INSTALLATION:                                                         

## WINDOWS                                                             

     1. Install PERL such as cygwin's or ActiveState                   
     2. Install PERL module SpreadSheet::WriteExcel                    
        If using Active State PERL use:                                
          ppm                                                          
          ppm> install SpreadSheet::WriteExcel                         
        If using cygwin's PERL, the installion can be done via CPAN    
        NOTE: nmake and gcc are required when going to cygwin route.   
          cpan Spreadsheet::WriteExcel                                 
     3. If needed, install Open Office (free)                          
     4. Copy the script to the root of the rules file to be analyzed.

## LINUX RedHat/CentOS:                                                

     1. Install PERL and the PERL module Spreadsheet::WriteExcel.      
           yum -y install perl "perl(Spreadsheet::WriteExcel)"         
     2. If needed, install Open Office (free)                          
     3. Copy the script to the root of the rules file to be analyzed.

## APPLE/MAC:                                                          

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
     4. Copy the script to the root of the rules file to be analyzed.

## RUNNING THE CODE:                                                        

     Locate the Netcool rules files to analyze. As a test you can
     use IBM's default rules:
        * NcKL3.7 - IBM's older NcKL rules                             
        * NcKL4.3 - IBM's newer NcKL rules                             
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

## Install OpenOffice -                                                  

       See http://www.if-not-true-then-false.com/                      
             2010/install-openoffice-org-on-fedora-centos-red-hat-rhel/

# PROGRAM USAGE:                                                        

   rules2tbl.pl                                                          
                  [-debug <debug number 1-2047>]  (($DEBUG))           
                    1   - Track program's progress.                    
                    2   - Tracing in program.                          
                    4   - Print out the interum rules before and after 
	                   switch stmts are converted to if-then-else.  
                          Also dump all tokens.                        
                  [-excel <fullpath to Excel output file>]             
                  [-help]                                              
                  [-input <rulesfile>]                                 
                  [-nul <Character(s) to use for null value>]          
                  [-order]                                             
                  [-output none|<fullpath to raw CVS output file>]     
                  [-mvdir <reference directory> <new directory>]       
     NOTE: Run program at rule root (i.e. \$OMNIHOME\\probes\\linux2x86\\)

# FEATURES

 THE FOLLOWING ARE KNOW "FEATURES" THAT WERE PROVIDED BUT NOT ASKED FOR
 1. Limited simplification of rules                                    
 2. Nested values not addressed.                                       


