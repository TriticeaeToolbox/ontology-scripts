#!/usr/bin/env perl

=head1 NAME

build_traits.pl 

=head1 SYNOPSIS

Usage: perl build_traits.pl [-o output -u username] [-t output] [-i institution] [-c category count] [-fv] file 

Options/Arguments:

=over 8

=item -o

specify the output location for the generic obo file

=item -u

specify the username of the person generating the file(s)
required when generating an obo file

=item -t

specify the output location for the trait dictionary file

=item -i

filter the output to contain only the variables used by the specified institution

=item -c

specify the number of scale categories that are defined in the trait workbook (default=10)

=item -f

force the generation of the files (ignore the unique and required checks)

=item -v

verbose output

=item file

file path to the trait workbook

=back

=head1 DESCRIPTION

Build a trait dictionary and/or standard obo file from a "trait workbook" (an Excel workbook 
containing worksheets for a trait ontology's "Variables", "Traits", "Methods", "Scales", 
"Trait Classes" and "Root" information).

=head1 AUTHOR

David Waring <djw64@cornell.edu>

=cut


######
## TODO:
##      - check ids across worksheets for duplicates
##      - check names across worksheets for duplicates 
##          (Variable name, Variable label, Trait name, Method name, Scale name)
######


use strict;
use warnings;
use Getopt::Std;
use Spreadsheet::Read;
use JSON;
use Data::Dumper;

# PROGRAM INFORMATION
my $PROGRAM_NAME = "build_traits.pl";
my $PROGRAM_VERSION = "1.1";


# Set Trait Workbook Sheet Names
my @TW_SHEETS = ("Variables","Traits","Methods","Scales","Trait Classes","Root");

# Set Trait Workbook Required and Unique Columns
my %TW_RULES;
$TW_RULES{"Variables"}{required} = ["Variable ID","Variable name","Trait name","Method name","Scale name"];
$TW_RULES{"Variables"}{unique} = ["Variable ID","Variable name","Variable synonyms","VARIABLE KEY"];
$TW_RULES{"Traits"}{required} = ["Trait ID","Trait name","Trait class"];
$TW_RULES{"Traits"}{unique} = ["Trait ID","Trait name"];
$TW_RULES{"Methods"}{required} = ["Method ID","Method name","Method class"];
$TW_RULES{"Methods"}{unique} = ["Method ID","Method name"];
$TW_RULES{"Scales"}{required} = ["Scale ID","Scale name"];
$TW_RULES{"Scales"}{unique} = ["Scale ID","Scale name"];
$TW_RULES{"Trait Classes"}{required} = ["Trait class ID","Trait class name"];
$TW_RULES{"Trait Classes"}{unique} = ["Trait class ID","Trait class name"];
$TW_RULES{"Root"}{required} = ["Root ID","Root name","namespace"];

# Set the Trait Dictionary Headers
my @TD_VARIABLE_HEADERS = ("Curation","Variable ID","Variable name","Variable synonyms",
    "Context of use","Growth stage","Variable status","Variable Xref",
    "Institution","Scientist","Date","Language","Crop");
my @TD_TRAIT_HEADERS = ("Trait ID","Trait name","Trait class","Trait description",
    "Trait synonyms","Main trait abbreviation","Alternative trait abbreviations",
    "Entity","Attribute","Trait status","Trait Xref");
my @TD_METHOD_HEADERS = ("Method ID","Method name","Method class","Method description",
    "Formula","Method reference");
my @TD_SCALE_HEADERS = ("Scale ID","Scale name","Scale class","Decimal places","Lower limit",
    "Upper limit","Scale Xref");
my $DEFAULT_TD_SCALE_CATEGORY_COUNT = 10;

# Crop Ontology ID Number Length
my $CO_ID_LENGTH = 7;

# OBO File Info
my $OBO_VERSION = 1.2;
my @OBO_TERM_TAGS = ("id","is_anonymous","name","namespace","alt_id","def","comment","subset",
    "synonym","xref","is_a","intersection_of","union_of","disjoint_from","relationship","is_obsolete",
    "replaced_by","consider","created_by","creation_date");



#######################################
## PARSE INPUT 
#######################################

# Get command line flags/options
my %opts=();
getopts("c:i:o:t:u:fv", \%opts);

my $verbose = $opts{v};
my $obo_output = $opts{o};
my $obo_user = $opts{u};
my $td_output = $opts{t};
my $filter_institution = $opts{i};
my $ignore_checks = $opts{f};
my $td_scale_category_count = $opts{c} ? $opts{c} : $DEFAULT_TD_SCALE_CATEGORY_COUNT;


# Get trait workbook file location
my $wb_file = shift;
if ( !$wb_file ) {
    die "==> ERROR: A trait workbook file is a required argument.\n";
}

# Make sure at least one output is given
if ( !defined($obo_output) && !defined($td_output) ) {
    die "==> ERROR: At least one output (-o or -t) must be specified.\n";
}

# Make sure username is given for obo file
if ( defined($obo_output) ) {
    if ( !defined($obo_user) ) {
        die "==> ERROR: Username (-u) must be specified when creating obo file.\n";
    }
}

# Print Input Info
message("Command Inputs:");
message("   Trait Workbook File: $wb_file");
if ( defined($filter_institution) ) {
    message("   Filter Traits By Institution: $filter_institution");
}
if ( $obo_output ) { 
    message("   OBO Output File: $obo_output");
    message("   Username: $obo_user");
}
if ( $td_output ) { message("   TD Output File: $td_output"); }






#######################################
## READ TRAIT WORKBOOK
#######################################

# Read the Trait Workbook File
my $sheets = readTraits($wb_file);



#######################################
## WRITE TRAIT DICTIONARY
#######################################

# Build and Write the Trait Dictionary File
if ( defined($td_output) ) {
    my $td = buildTraitDictionary($sheets);
    writeTraitDictionary($td, $td_output);
}



#######################################
## WRITE OBO FILE
#######################################

# Write the standard obo file
if ( defined($obo_output) ) {
    writeOBOFile($sheets, $obo_output);
}








#######################################
## TRAIT WORKBOOK FUNCTIONS
## Reading and Parsing the Excel file
#######################################


######
## readTraits()
##
## Read each of the worksheets from the specified 
## "Trait Workbook" Excel file
##
## Arguments:
##      $file: file path to excel workbook
##
## Returns: A reference to a hash containing all of the 
## parsed worksheets from the workbook.  The hash key is 
## the name of the worksheet and the hash value is an array 
## of parsed rows.
######
sub readTraits {
    my $file = shift;
    message("Reading Trait Workbook File [$file]:");

    # Read the workbook from the specified file
    my $book = Spreadsheet::Read->new($file);

    # Hash to hold each of the sheets
    my %sheets;

    # Read Variables
    $sheets{'Variables'} = parseSheet($book, 'Variables');

    # Read Traits
    $sheets{'Traits'} = parseSheet($book, 'Traits', $sheets{'Variables'}, 'Trait name');

    # Read Methods
    $sheets{'Methods'} = parseSheet($book, 'Methods', $sheets{'Variables'}, 'Method name');

    # Read Scales
    $sheets{'Scales'} = parseSheet($book, 'Scales', $sheets{'Variables'}, 'Scale name');

    # Read Trait Classes
    $sheets{'Trait Classes'} = parseSheet($book, 'Trait Classes');

    # Read Root
    $sheets{'Root'} = parseSheet($book, 'Root');
    
    # Return the parsed sheets
    return \%sheets;
}


######
## parseSheet()
##
## Parse the specified sheet into an array of hashes.  Each 
## array item represents a row with the key set to the header 
## name and the value set to the cell value.
##
## If $variables and $column are given as arguments, rows will 
## only be added if a value from the specified column name is 
## found in the column with the same name from the variables rows
##
## Arguments:
##      $book: Spreadsheet::Read workbook
##      $sheetName: name of worksheet to parse
##      $variables: an array ref to the variables rows, optional
##      $column: a column to match values from the variables, optional
##
## Returns: a reference to an array of parsed worksheet rows
######
sub parseSheet {
    my $book = shift;
    my $sheetName = shift;
    my $variables = shift;
    my $column = shift;
    message("   Parsing worksheet [$sheetName]");

    # Get filter values
    my $filter = 0;
    my %filter_values;
    if ( $variables && $column ) {
        $filter = 1;
        foreach my $row ( @{$variables} ) {
            my $v = $row->{$column};
            $filter_values{$v} = 1;
        }
    }

    # Get the worksheet
    my $sheet = $book->sheet($sheetName);

    # Get the header row
    my @header = $sheet->row(1);

    # Array of parsed rows to return
    my @rows = ();

    # Parse each additional row (after the header)
    for ( my $i = 2; $i <= $sheet->maxrow; $i++ ) {
        my @row = $sheet->row($i);
        my %row_items;
        my $include = 1;
        
        # Get the value of each row item (column)
        while ( my ($index, $value) = each(@row) ) {
            my $key = $header[$index];
            $row_items{$key} = $value;

            # Filter Variables by Institution, if requested
            if ( defined($filter_institution) ) {
                if ( $sheetName eq "Variables" && $key eq "Institution" ) {
                    $include = 0;
                    if ( defined $value && $value ne "" ) {
                        for (split(/\s*\,\s*/, $value)) {
                            if ( $_ eq $filter_institution ) {
                                $include = 1;
                            }
                        }
                    }
                }
            }

            # Filter other sheets by column from variables table
            if ( $filter ) {
                if ( $key eq $column ) {
                    if ( !exists($filter_values{$value}) ) {
                        $include = 0;
                    }
                }
            }
            
            # Update max category count
            if ( index($key, "Category") != -1 ) {
                my $i = $key;
                $i =~ s/Category[ ]*//;
                if ( $i > $td_scale_category_count ) {
                    $td_scale_category_count = $i;
                }
            }
        }

        # Add row items to list of parsed rows
        if ( $include == 1 ) {
            push(@rows, \%row_items);
        }
    }


    # Return the parsed row items
    message("      Read " . ($#rows+1) . " rows");
    return \@rows;
}


######
## checkSheet()
##
## Check the specified worksheet for missing required data and 
## duplicated unique values.  
##
## The script will die if it encounters any errors.
##
## Arguments:
##      $sheet: Spreadsheet::Read worksheet
##      $sheetName: name of the worksheet
######
sub checkSheet {
    my $sheet = shift;
    my $name = shift;

    # Sheet has defined rules
    if ( defined($TW_RULES{$name}) ) {
        
        # Sheet has defined required columns
        if ( defined($TW_RULES{$name}{required}) ) {
            my $required_cols = $TW_RULES{$name}{required};
            for (@$sheet) {
                my $row = $_;
                for (@$required_cols) {
                    my $col = $_;
                    my $value = $row->{$col};
                    if ( !defined($value) || $value eq '' ) {
                        message("==> ERROR: Required column [" . $col . "] does not have a value set in worksheet [" . $name . "]", 1);
                        message("    ROW: " . to_json($row));
                        die "    You must add the missing data before continuing.";
                    }
                }
            }
        }

        # Sheet has defined unique columns
        if ( defined($TW_RULES{$name}{unique}) ) {
            my $unique_cols = $TW_RULES{$name}{unique};
            for (@$unique_cols) {
                my $col = $_;
                my %values;
                for (@$sheet) {
                    my $row = $_;
                    my $value = $row->{$col};
                    if ( defined($value) && !($value eq "") ) {
                        if ( exists($values{$value}) ) {
                            message("==> ERROR: Unique column [" . $col . "] contains a duplicated value [" . $value . "] in worksheet [" . $name . "]", 1);
                            die "    You must remove the duplicate values before continuing.";
                        }
                        else {
                            $values{$value} = 1;
                        }
                    }
                }
            }
        }

    }
}






#######################################
## TRAIT DICTIONARY FUNCTIONS
## Building and Writing the Trait Dictionary
#######################################


######
## buildTraitDictionary
##
## Build the CO Trait Dictionary File
##
## Arguments:
##      $sheets: hash reference of trait workbook worksheets
##
## Returns: list of trait dictionary rows
######
sub buildTraitDictionary {
    my $sheets = shift;
    my $variables = $sheets->{'Variables'};
    my $traits = $sheets->{'Traits'};
    my $methods = $sheets->{'Methods'};
    my $scales = $sheets->{'Scales'};
    my $root = $sheets->{'Root'};
    message("Building Trait Dictionary:");

    # Parse each variable
    my @rows = ();
    foreach my $variable (@$variables) {
        
        # Hash to hold all variable information
        my %item = ();

        # Set variable-level information
        foreach my $variable_header (@TD_VARIABLE_HEADERS) {
            $item{$variable_header} = $variable->{$variable_header};
        }

        # Set scale headers
        my @scale_headers = @TD_SCALE_HEADERS;
        for my $i (1 .. $td_scale_category_count) {
            push(@scale_headers, "Category $i");
        }

        # Add trail-level, method-level, and scale-level information to item
        my $ts = addTraitDictionaryDetails(\%item, $variable, $traits, "Trait name", \@TD_TRAIT_HEADERS);
        my $ms = addTraitDictionaryDetails(\%item, $variable, $methods, "Method name", \@TD_METHOD_HEADERS);
        my $ss = addTraitDictionaryDetails(\%item, $variable, $scales, "Scale name", \@scale_headers);

        # Item has matching trait, method and scale...
        if ( $ts && $ms && $ss ) {
            my $root_id = @$root[0]->{'Root ID'};

            # Generate IDs
            $item{'Variable ID'} = generateID($root_id, $item{'Variable ID'});
            $item{'Trait ID'} = generateID($root_id, $item{'Trait ID'});
            $item{'Method ID'} = generateID($root_id, $item{'Method ID'});
            $item{'Scale ID'} = generateID($root_id, $item{'Scale ID'});

            # Add Item to list of rows
            push(@rows, \%item);
        }

    }

    # Return list of Trait Dictionary Rows
    message("   Created " . (scalar @rows) . " variables");
    return \@rows;
}


######
## addTraitDictionaryDetails()
##
## Add information from the matching details (trait, method, scale) element to
## the current item of the trait dictionary
##
## Arguments:
##      $item: hash reference of item to add information to
##      $variable: item's variable-level information
##      $details: list of trait, method or scales to get more information from
##      $key: key/header name to match variable to details
##      $headers: list of headers of information to add to item
######
sub addTraitDictionaryDetails {
    my $item = shift;
    my $variable = shift;
    my $details = shift;
    my $key = shift;
    my $headers = shift;

    my $match = findElement($details, $key, $variable->{$key});
    if ( !defined $match || $match eq "" ) {
        message("==> ERROR: could not match variable [" . $variable->{'Variable name'} . "] with '$key' [" . $variable->{$key} . "]", 1);
        return 0;
    }
    foreach my $header (@$headers) {
        $item->{$header} = $match->{$header};
    }
    return 1;
}


######
## writeTraitDictionary()
##
## Write the trait dictionary to the specified file
##
## Arguments:
##      $rows: list of rows to write to trait dictionary
##      $file: output file for trait dictionary
######
sub writeTraitDictionary {
    my $rows = shift;
    my $file = shift;
    message("Writing Trait Dictionary [$file]", 1);

    # Generate complete list of headers
    my @headers = ();
    push(@headers, @TD_VARIABLE_HEADERS);
    push(@headers, @TD_TRAIT_HEADERS);
    push(@headers, @TD_METHOD_HEADERS);
    push(@headers, @TD_SCALE_HEADERS);
    for my $i (1 .. $td_scale_category_count) {
        push(@headers, "Category $i");
    }

    # Build the content from each row
    my $content = createTraitDictionaryLine(\@headers);
    for ( @$rows ) {
        $content = $content . createTraitDictionaryLine(\@headers, $_);
    }

    # Write content to file
    open(my $fh, '>', $file);
    print $fh $content;
    close($fh);
}


######
## createTraitDictionaryLine()
##
## Create a quoted, semi-colon separated line from 
## the specified row and headers
##
## Arguments:
##      $headers: list of headers for the row
##      $row: row of trait dictionary
##
## Returns: a formatted line from the row's data
######
sub createTraitDictionaryLine {
    my $headers = shift;
    my $row = shift;

    my $line = '';
    foreach my $i (0 .. (scalar @{$headers})-1) {
        my $header = @$headers[$i];
        my $value = defined($row) ? $row->{$header} : $header;
        if ( !defined($value) ) {
            $value = '';
        }
        $line = $line . "\"" . $value . "\"";
        if ( $i < (scalar @{$headers})-1 ) {
            $line = $line . ";";
        }
    }
    $line = $line . "\n";

    return $line;
}







#######################################
## OBO FILE FUNCTIONS
## Building and Writing the OBO File
#######################################



######
## writeOBOFile()
##
## Write the OBO file
##
## Arguments:
##      $sheets: hash reference of trait workbook worksheets
##      $file: output file for obo file
######
sub writeOBOFile {
    my $sheets = shift;
    my $file = shift;
    my $variables = $sheets->{'Variables'};
    my $traits = $sheets->{'Traits'};
    my $methods = $sheets->{'Methods'};
    my $scales = $sheets->{'Scales'};
    my $classes = $sheets->{'Trait Classes'};
    my $root = $sheets->{'Root'};
    message("Writing OBO File [$file]");

    # Get Root Properties
    my $root_id = @$root[0]->{'Root ID'};
    my $root_name = @$root[0]->{'Root name'};
    my $root_namespace = @$root[0]->{'namespace'};

    # Init OBO file contents
    my $contents = '';

    # Add OBO Header Info
    $contents = OBOAddHeader($root_id, $root_namespace, $contents);

    # Add Typedefs
    $contents = OBOAddTypeDef("method_of", "method_of", 1, $contents);
    $contents = OBOAddTypeDef("scale_of", "scale_of", 1, $contents);
    $contents = OBOAddTypeDef("variable_of", "variable_of", 0, $contents);

    # Add Root Term
    $contents = OBOAddRoot($root_id, $root_namespace, $root_name, $contents);

    # Add Trait Classes
    $contents = OBOAddTraitClasses($root_id, $root_namespace, $classes, $contents);

    # Add Traits
    $contents = OBOAddTraits($root_id, $root_namespace . "_trait", $traits, $classes, $contents);

    # Add Methods
    $contents = OBOAddMethods($root_id, $root_namespace . "_method", $variables, $traits, $methods, $contents);

    # Add Scales
    $contents = OBOAddScales($root_id, $root_namespace . "_scale", $variables, $methods, $scales, $contents);

    # Add Variables
    $contents = OBOAddVariables($root_id, $root_namespace . "_variable", $variables, $traits, $methods, $scales, $contents);

    # Write contents to file
    open(my $fh, '>', $file);
    print $fh $contents;
    close($fh);
}


######
## OBOAddKey()
##
## Add a key: value pair to the OBO contents
##
## Arguments:
##      $key: item name
##      $value: item value
##      $contents: existing contents of file to append to
##
## Returns: updated contents with key: value pair added
######
sub OBOAddKey {
    my $key = shift;
    my $value = shift;
    my $contents = shift;

    # Remove index from duplicated keys
    if ( $key =~ /relationship[0-9]+/ ) {
        $key = "relationship";
    }
    elsif ( $key =~ /synonym[0-9]+/ ) {
        $key = "synonym";
    }
    elsif ( $key =~ /is_a[0-9]+/ ) {
        $key = "is_a";
    }

    $contents = $contents . $key . ": " . $value . "\n";
    return $contents;
}


######
## OBOAddTerm()
## 
## Add a Term block with the specified key: value pairs to the OBO contents
##
## Arguments:
##      $items: hash of key: value pairs to add
##      $contents: existing contents of file to append to
##
## Returns: updated contents with term block added
######
sub OBOAddTerm {
    my $items = shift;
    my $contents = shift;

    $contents = $contents . "\n[Term]\n";
    for (@OBO_TERM_TAGS) {
        my $tag = $_;
        while ( my ($key, $value) = each(%$items) ) {
            my $re = "^" . $tag . "[0-9]*\$";
            if ( $key =~ /$re/ ) {
                $contents = OBOAddKey($key, $value, $contents);
            }
        }
    }

    return $contents;
}


######
## OBOAddTypeDef()
##
## Add a Typedef block with the specified id, name, and is_transitive properties
##
## Arguments:
##      $id: typedef id
##      $name: typedef name
##      $is_transitive: flag to set the typedef as transitive
##
## Returns: updated contents with the typedef block added
######
sub OBOAddTypeDef {
    my $id = shift;
    my $name = shift;
    my $is_transitive = shift;
    my $contents = shift;

    $contents = $contents . "\n[Typedef]\n";
    $contents = OBOAddKey("id", $id, $contents);
    $contents = OBOAddKey("name", $name, $contents);
    if ( $is_transitive ) {
        $contents = OBOAddKey("is_transitive", "true", $contents);
    }

    return $contents;
}


######
## OBOAddHeader()
##
## Add the OBO file header key: value pairs to the contents
##
## Arguments:
##      $ont_id: ontology id (Root ID)
##      $dns: default namespace
##      $contents: exisiting contents of file to append to
##
## Returns: updated contents with header items added
######
sub OBOAddHeader {
    my $ont_id = shift;
    my $dns = shift;
    my $contents = shift;

    $contents = OBOAddKey("format-version", $OBO_VERSION, $contents);
    $contents = OBOAddKey("date", getTimestamp(), $contents);
    $contents = OBOAddKey("saved-by", $obo_user, $contents);
    $contents = OBOAddKey("auto-generated-by", "$PROGRAM_NAME/$PROGRAM_VERSION", $contents);
    $contents = OBOAddKey("remark", "This file was auto-generated from a 'Trait Workbook' [$wb_file]", $contents);
    $contents = OBOAddKey("default-namespace", $dns, $contents);
    $contents = OBOAddKey("ontology", $ont_id, $contents);

    return $contents;
}


######
## OBOAddRoot()
##
## Add the Root Term to the contents
##
## Arguments:
##      $root_id: ontology root id
##      $namespace: root namespace
##      $ont_name: ontology root name
##      $contents: existing contents of file to append to
##
## Returns: updated contents with root term added
######
sub OBOAddRoot {
    my $root_id = shift;
    my $namespace = shift;
    my $ont_name = shift;
    my $contents = shift;

    my %items = (
        id => "$root_id:ROOT",
        name => $ont_name,
        namespace => $namespace
    );
    $contents = OBOAddTerm(\%items, $contents);

    return $contents;
}


######
## OBOAddTraitClasses()
##
## Add Term blocks for each of the trait classes
##
## Arguments:
##      $root_id: onotology root id
##      $namespace: trait class namespace
##      $classes: reference to array of trait classes
##      $contents: existing contents of file to append to
##
## Returns: updated contents with trait class blocks added
######
sub OBOAddTraitClasses {
    my $root_id = shift;
    my $namespace = shift;
    my $classes = shift;
    my $contents = shift;

    for (@$classes) {
        my $class = $_;
        my %items = (
            id => "$root_id:" . $class->{'Trait class ID'},
            name => $class->{'Trait class name'},
            is_a => "$root_id:ROOT",
            namespace => $namespace
        );
        $contents = OBOAddTerm(\%items, $contents);
    }

    return $contents;
}


######
## OBOAddVariables()
##
## Add Term blocks for each of the observation variables
##
## Arguments:
##      $root_id: ontology root id
##      $namespace: variable namespace
##      $variables: reference to array of variables
##      $traits: reference to array of traits
##      $methods: reference to array of methods
##      $scales: reference to array of scales
##      $contents: exisiting contents of file to append to
##
## Returns: updated contents with variable blocks added
######
sub OBOAddVariables {
    my $root_id = shift;
    my $namespace = shift;
    my $variables = shift;
    my $traits = shift;
    my $methods = shift;
    my $scales = shift;
    my $contents = shift;

    for (@$variables) {
        my $variable = $_;
        my $trait = findElement($traits, "Trait name", $variable->{'Trait name'});
        my $method = findElement($methods, "Method name", $variable->{'Method name'});
        my $scale = findElement($scales, "Scale name", $variable->{'Scale name'});

        my $variable_xref = defined($variable->{'Variable Xref'}) ? $variable->{'Variable Xref'} : "";
        my $variable_def = "";
        if ( defined($trait->{'Trait description'}) ) {
            $variable_def .= "TRAIT: " . $trait->{'Trait description'};
        }
        if ( defined($method->{'Method description'}) ) {
            $variable_def .= " METHOD: " . $method->{'Method description'};
        }
        if ( defined($scale->{'Scale name'}) ) {
            $variable_def .= " SCALE: " . $scale->{'Scale name'};

            # Check for scale category definitions
            my @scale_cat_defs = ();
            foreach my $i (1 .. $td_scale_category_count) {
                my $scale_cat_header = "Category $i";
                my $scale_cat_value = $scale->{$scale_cat_header};
                if ( defined($scale_cat_value) ) {
                    push(@scale_cat_defs, $scale_cat_value);
                }
            }
            if ( @scale_cat_defs ) {
                $variable_def .= " (" . join(', ', @scale_cat_defs) . ")";
            }

        }

        my %items = (
            id => generateID($root_id, $variable->{'Variable ID'}),
            def => "\"" . $variable_def . "\" [" . $variable_xref . "]",
            namespace => $namespace,
            relationship1 => "variable_of " . generateID($root_id, $trait->{'Trait ID'}),
            relationship2 => "variable_of " . generateID($root_id, $method->{'Method ID'}),
            relationship3 => "variable_of " . generateID($root_id, $scale->{'Scale ID'})
        );

        # Use variable label as name, if defined, otherwise variable name
        if ( defined($variable->{'Variable label'}) && !($variable->{'Variable label'} eq "") ) {
            $items{'name'} = $variable->{'Variable label'};
        }
        else {
            $items{'name'} = $variable->{'Variable name'};
        }

        # Add Variable variable_synonyms
        if ( defined($variable->{'Variable synonyms'}) ) {
            my @variable_synonyms = split(/,/, $variable->{'Variable synonyms'});
            foreach my $i (0..$#variable_synonyms) {
                $items{'synonym' . ($i+1)} = "\"" . trimws($variable_synonyms[$i]) . "\" EXACT []";
            }
        }
        
        # Create Term Block
        $contents = OBOAddTerm(\%items, $contents);
    }

    return $contents;
}


######
## OBOAddTraits()
##
## Add Term blocks for each of the traits
##
## Arguments:
##      $root_id: ontology root id
##      $namespace: trait namespace
##      $traits: reference to array of traits
##      $classes: reference to array of trait classes
##      $contents: existing contents of file to append to
##
## Returns: updated contents with trait blocks added
######
sub OBOAddTraits {
    my $root_id = shift;
    my $namespace = shift;
    my $traits = shift;
    my $classes = shift;
    my $contents = shift;

    # Parse each individual trait
    for (@$traits) {
        my $trait = $_;

        # Get matching class
        my $class = findElement($classes, "Trait class name", $trait->{'Trait class'});

        my $trait_xref = defined($trait->{'Trait Xref'}) ? $trait->{'Trait Xref'} : "";

        # Set trait info
        my %items = (
            id => generateID($root_id, $trait->{'Trait ID'}),
            name => $trait->{'Trait name'},
            namespace => $namespace, 
            def => "\"" . $trait->{'Trait description'} . "\" [" . $trait_xref . "]",
            synonym1 => "\"" . $trait->{'Main trait abbreviation'} . "\" EXACT []",
            is_a => $root_id . ":" . $class->{'Trait class ID'}
        );

        # Add additional synonyms
        if ( defined($trait->{'Trait synonyms'}) ) {
            my @trait_synonyms = split(/,/, $trait->{'Trait synonyms'});
            foreach my $i (0..$#trait_synonyms) {
                $items{'synonym' . ($i+2)} = "\"" . trimws($trait_synonyms[$i]) . "\" EXACT []";
            }
        }

        # Add Trait Term
        $contents = OBOAddTerm(\%items, $contents);
    }

    return $contents;
}


######
## OBOAddMethods()
##
## Add Term blocks for each of the defined methods
##
## Arguments:
##      $root_id: ontology root id
##      $namespace: method namespace
##      $variables: reference to array of variables
##      $traits: reference to array of traits
##      $methods: reference to array of methods
##      $contents: existing contents of file to append to
##
## Returns: updated contents with method blocks added
######
sub OBOAddMethods {
    my $root_id = shift;
    my $namespace = shift;
    my $variables = shift;
    my $traits = shift;
    my $methods = shift;
    my $contents = shift;

    # Parse each individual method
    for (@$methods) {
        my $method = $_;

        my $method_ref = defined($method->{'Method reference'}) ? $method->{'Method reference'} : "";
        my $method_def = defined($method->{'Method description'}) ? $method->{'Method description'} : "";

        # Set method info
        my %items = (
            id => generateID($root_id, $method->{'Method ID'}),
            name => $method->{'Method name'},
            namespace => $namespace,
            def => "\"" . $method_def . "\" [" . $method_ref . "]"
        );

        # Get Trait IDs of traits using the current method
        my $count = 1;
        for (@$variables) {
            my $variable = $_;
            if ( $variable->{'Method name'} eq $method->{'Method name'} ) {
                my $trait = findElement($traits, "Trait name", $variable->{'Trait name'});
                my $trait_id = generateID($root_id, $trait->{'Trait ID'});
                my $trait_value = "method_of " . $trait_id;
                
                # Add Trait ID as a relationship of the method
                if ( (grep { $_ eq $trait_value } values %items) == 0 ) {
                    $items{"relationship" . $count} = $trait_value;
                    # $items{"is_a" . $count} = $trait_id;
                    $count++;
                }
            }
        }

        # Add Method Term
        $contents = OBOAddTerm(\%items, $contents);
    }

    return $contents;
}


######
## OBOAddScales()
##
## Add Term blocks for each of the defined scales, including 
## a separate term block for each of the scale category definitions
##
## Arguments:
##      $root_id: ontology root id
##      $namespace: scale namespace
##      $variables: reference to array of variables
##      $methods: reference to array of methods
##      $scales: reference to array of scales to add
##      $contents: existing contents of file to append to
##
## Returns: updated contents with scale blocks added
######
sub OBOAddScales {
    my $root_id = shift;
    my $namespace = shift;
    my $variables = shift;
    my $methods = shift;
    my $scales = shift;
    my $contents = shift;

    # Parse each individual scale
    for (@$scales) {
        my $scale = $_;
        my $scale_id = generateID($root_id, $scale->{'Scale ID'});

        # Set scale info
        my %items = (
            id => $scale_id,
            name => $scale->{'Scale name'},
            namespace => $namespace
        );

        # Get Method IDs of methods using the current scale
        my $count = 1;
        for (@$variables) {
            my $variable = $_;
            if ( $variable->{'Scale name'} eq $scale->{'Scale name'} ) {
                my $method = findElement($methods, "Method name", $variable->{'Method name'});
                my $method_id = generateID($root_id, $method->{'Method ID'});
                my $method_value = "scale_of " . $method_id;
                
                # Add Method ID as a relationship of the scale
                if ( (grep { $_ eq $method_value } values %items) == 0 ) {
                    $items{"relationship" . $count} = $method_value;
                    # $items{"is_a" . $count} = $method_id;
                    $count++;
                }
            }
        }

        # Check for scale category definitions
        my $scale_cat_count = 0;
        my @scale_cat_items = ();
        my @scale_cat_defs = ();
        foreach my $i (1 .. $td_scale_category_count) {
            my $scale_cat_header = "Category $i";
            my $scale_cat_value = $scale->{$scale_cat_header};
            if ( defined($scale_cat_value) ) {
                push(@scale_cat_defs, $scale_cat_value);
                my @scale_cat_value_parts = split(/=/, $scale_cat_value, 2);
                my $scale_cat_syn = trimws($scale_cat_value_parts[0]);
                my $scale_cat_name = trimws($scale_cat_value_parts[1]);

                # Add Scale Category Term
                my %scale_cat_items = (
                    id => $scale_id . "/" . $scale_cat_count,
                    name => $scale_cat_name ? $scale_cat_name : $scale_cat_syn,
                    namespace => $namespace,
                    synonym => "\"" . $scale_cat_syn . "\" EXACT []",
                    is_a => $scale_id
                );
                push(@scale_cat_items, \%scale_cat_items);
                $scale_cat_count++;
            }
        }

        # Add Scale Term
        if ( @scale_cat_defs ) {
            $items{'def'} = "\"" . join(', ', @scale_cat_defs) . "\" []";
        }
        $contents = OBOAddTerm(\%items, $contents);

        # Add Scale Category Terms
        for (@scale_cat_items) {
            $contents = OBOAddTerm($_, $contents);
        }

    }

    return $contents;
}





#######################################
## UTILITY FUNCTIONS
#######################################



######
## generateID()
##
## Generate a CO ID from the CO Root and ID Number
##
## Arguments:
##      $root: CO Root Name
##      $id: Element ID Number
##
## Returns: A CO ID (CO_322:0000245)
######
sub generateID {
    my $root = shift;
    my $id = shift;
    return $root . ":" . "0" x ($CO_ID_LENGTH-length($id)) . $id;
}


######
## findElement()
##
## Find an element (the first) in an array of hashes that has 
## a matching key and value
##
## Arguments:
##      $a: array reference
##      $key: hash key name
##      $value: hash key value
##
## Returns: (the first) matching element from array
######
sub findElement {
    my $a = shift;
    my $key = shift;
    my $value = shift;
    for (@$a) {
        my %e = %$_;
        if ( $e{$key} eq $value ) {
            return \%e;
        }
    }
}


######
## startsWith()
##
## Check if the provided string starts with the substring
## 
## Arguments:
##      $haystack
##      $needle
##
## Returns: true if haystack starts with needle
######
sub startsWith {
    return substr($_[0], 0, length($_[1])) eq $_[1];
}


######
## trimws()
##
## Remove leading and trailing whitespace
##
## Arguments:
##      $string
##
## Returns: trimmed string
######
sub trimws {
    if ( defined($_[0]) ) {
        (my $s = $_[0]) =~ s/^\s+|\s+$//g;
        return $s;
    }
    else {
        return "";
    }
}


######
## getTimestamp()
## 
## Get a timestamp in the OBO format of:
##      dd:MM:yyyy HH:mm
##
## Returns: formatted timestamp
######
sub getTimestamp {
    my ($SEC,$MIN,$HOUR,$MDAY,$MON,$YEAR,$WDAY,$YDAY,$ISDST) = localtime();

    my $d = "0" x (2-length($MDAY)) . $MDAY;
    my $m = $MON + 1;
    $m = "0" x (2-length($m)) . $m;
    my $y = $YEAR + 1900;
    my $h = "0" x (2-length($HOUR)) . $HOUR;
    my $i = "0" x (2-length($MIN)) . $MIN;

    return "$d:$m:$y $h:$i";
}


######
## message()
##
## Print log message, if set to verbose
##
## Arguments:
##      $msg: Message to print
##      $force: force print the message
######
sub message {
    my $msg = shift;
    my $force = shift;
    if ( $verbose || $force ) { print STDOUT "$msg\n"; }
}


1;