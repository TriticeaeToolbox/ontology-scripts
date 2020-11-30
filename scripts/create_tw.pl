#!/usr/bin/env perl

=head1 NAME

create_tw.pl

=head1 SYNOPSIS

Usage: perl create_tw.pl -d namespace -n name -r root -o output [-v] [input]

Options/Arguments:

=over 8

=item -d

the default ontology namespace.  This will be used when generating an obo file (ex sugar_kelp_trait).

=item -n 

the ontology display name.  A human-readable name for the ontology (ex Sugar Kelp Traits).

=item -r

the ontology root id.  Most likely the Crop Ontology ID (ex CO_360).

=item -o

the output location of the trait workbook excel file (xlsx extension).

=item -v

verbose output

=item input

specify the Crop Ontology Root ID (ex: CO_360) to download the trait 
dictionary from cropontology.org OR the file path to an existing 
trait dictionary.  If no input is provided, a new trait workbook will 
be created containing an example variable, trait, and scale.

=back

=head1 DESCRIPTION

This will create a 'Trait Workbook' Excel file from an existing Crop 
Ontology 'Trait Dictionary'.  A Trait Dictionary is a flat text file 
containing all of the trait information available on the Crop Ontology website.
The Trait Dictionary can be specified by it's CO ID (such as CO_360) and 
downloaded from the Crop Ontology website OR by a file path to an existing 
Trait Dictionary file.

The resulting Trait Workbook will contain the worksheets 'Variables', 'Traits', 
'Methods', 'Scales', 'Trait Classes' and 'Root'.  Some columns will have 
conditional formatting applied that will highlight duplicated values.  The 
'Trait name', 'Method name' and 'Scale name' columns in the 'Variables' 
worksheet will highlight names of elements that do not match existing elements.

The Trait Workbook file can be used by the build_traits.pl script to build 
a Trait Dictionary and/or OBO file.

=head1 AUTHOR

David Waring <djw64@cornell.edu>

=cut



use strict;
use warnings;
use Getopt::Std;
use File::Fetch;
use Excel::Writer::XLSX;
use Excel::Writer::XLSX::Utility;
use DateTime::Format::Excel;
use Scalar::Util qw(looks_like_number);
use Data::Dumper;


# Download URL for CO Trait Dictionary
my $CO_DOWNLOAD_URL = "http://www.cropontology.org/report?ontology_id={{CO_ROOT_ID}}";


# Trait Workbook Headers
my @TW_VARIABLE_HEADERS = ("Curation", "Variable ID", "Variable name", "Variable synonyms", "Variable label", 
    "Context of use", "Growth stage", "Variable status", "Variable Xref", "Institution", "Scientist", 
    "Date", "Language", "Crop", "Trait name", "Method name", "Scale name", "VARIABLE KEY");
my @TW_TRAIT_HEADERS = ("Trait ID", "Trait name", "Trait class", "Trait description", "Trait synonyms",
    "Main trait abbreviation", "Alternative trait abbreviations", "Entity", "Attribute", 
    "Trait status", "Trait Xref");
my @TW_METHOD_HEADERS = ("Method ID", "Method name", "Method class", "Method description", "Formula", "Method reference");
my @TW_SCALE_HEADERS = ("Scale ID", "Scale name", "Scale class", "Decimal places", "Lower limit", "Upper limit",
    "Scale Xref");
my $TW_SCALE_CATEGORY_COUNT = 10;
my @TW_TRAIT_CLASS_HEADERS = ("Trait class ID", "Trait class name");
my @TW_ROOT_HEADERS = ("Root ID", "Root name", "namespace");

# Max number of rows for conditional formatting
my $CF_MAX_ROW = 9999;


# Example Row for Blank Workbook
my $BLANK_HEADER = '"Curation";"Variable ID";"Variable name";"Variable synonyms";"Context of use";"Growth stage";"Variable status";"Variable Xref";"Institution";"Scientist";"Date";"Language";"Crop";"Trait ID";"Trait name";"Trait class";"Trait description";"Trait synonyms";"Main trait abbreviation";"Alternative trait abbreviations";"Entity";"Attribute";"Trait status";"Trait Xref";"Method ID";"Method name";"Method class";"Method description";"Formula";"Method reference";"Scale ID";"Scale name";"Scale class";"Decimal places";"Lower limit";"Upper limit";"Scale Xref";"Category 1";"Category 2";"Category 3";"Category 4";"Category 5";"Category 6";"Category 7";"Category 8";"Category 9";"Category 10"';
my $BLANK_ROW = '"";"CO_999:0000004";"PH_M_cm";"";"Trial evaluation";"Harvest";"";"";"Cornell University";"";"15-Feb-2018";"English";"Crop";"CO_999:000003";"Plant Height";"Morphological trait";"The observed height of the plant";"";"PH";"";"Stem";height";"";"";"CO_360:0000002";"Plant Height - Measurement";"Measurement";"Direct measurement of the plant height from the ground level to the tallest part of the plant";"";"";"CO_360:0000001";"cm";"Numerical";"2";"";"";"";"";"";"";"";"";"";"";"";"";""';


#######################################
## PARSE INPUT 
#######################################

# Get command line flags/options
my %opts=();
getopts("d:n:r:o:v", \%opts);

my $verbose = $opts{v};
my $output = $opts{o};
my $root = $opts{r};
my $name = $opts{n};
my $namespace = $opts{d};


# Get Input
my $input = shift;
if ( !$input ) {
    $input = "_BLANK_";
}

# Make sure output is specified
if ( !defined($output) ) {
    die "==> ERROR: Output file location (-o) must be specified.\n";
}

# Make sure root information is specified
if ( !defined($root) || !defined($name) || !defined($namespace) ) {
    die "==> ERROR: The root id (-r), ontology name (-n) and default namespace (-d) must be specified\n";
}




# Print Input Info
message("Command Inputs:");
message("   Input: $input");
message("   Output Location: $output");
message("   Root ID: $root");
message("   Ontology Name: $name");
message("   Default Namespace: $namespace");


# Get the Trait Dictionary
my $td = getTD($input);

# Create the Trait Workbook
create($output, $td);




#######################################
## TRAIT WORKBOOK FUNCTIONS
## Download and Create a Trait Workbook
#######################################



######
## getTD()
##
## Get the trait dictionary of the specified ontology
##      - read file input OR
##      - download the trait dictionary
##
## Arguments:
##      $input: file path OR CO Root ID (ex: CO_360)
##
## Returns: Trait Dictionary contents
######
sub getTD {
    my $input = shift;
    my $contents;

    # Start with Blank TD
    if ( $input eq "_BLANK_" ) {
        message("Creating Blank Trait Workbook...");
        $contents = $BLANK_HEADER . "\n" . $BLANK_ROW;
    }

    # Input File Exists
    elsif ( -s $input ) {
        message("Using existing TD file [$input]...");
        open my $fh, '<', $input or die "Can't open input file [$input] $!";
        $contents = do { local $/; <$fh> };
    }

    # Download from CO
    else {

        # Set URL
        my $url = $CO_DOWNLOAD_URL;
        $url =~ s/\{\{CO_ROOT_ID\}\}/$input/;

        # Download TD from CO
        message("Downloading Trait Dictionary [$url]...");
        my $ff = File::Fetch->new(uri => $url);
        my $file = $ff->fetch(to => \$contents) or die $ff->error;

    }

    # return file contents
    return $contents;
}


######
## create()
##
## Create the Trait Workbook and populate each of the 
## various worksheets
##
## Arguments:
##      $file: output file path to Excel file (xlsx)
##      $td: contents of the trait dictionary
######
sub create {
    my $file = shift;
    my $td = shift;

    # Parse the Trait Dictionary
    my $parsed = parseTD($td);

    # Set up Workbook with worksheets
    my $wb = Excel::Writer::XLSX->new($file);
    my $v = $wb->add_worksheet('Variables');
    my $t = $wb->add_worksheet('Traits');
    my $m = $wb->add_worksheet('Methods');
    my $s = $wb->add_worksheet('Scales');
    my $c = $wb->add_worksheet('Trait Classes');
    my $r = $wb->add_worksheet('Root');

    # Set Error Formatting
    my $error_format = $wb->add_format(
        bold => 1,
        color => 'red',
        bg_color => 'black'
    );

    # Add Variables, Traits, Methods, Scales
    addVariables($v, $parsed, $error_format);
    addTraits($t, $parsed, $error_format);
    addMethods($m, $parsed, $error_format);
    addScales($s, $parsed, $error_format);
    addTraitClasses($c, $parsed, $error_format);
    addRoot($r, $root, $name, $namespace);
}


######
## parseTD()
##
## Parse the Trait Dictionary contents into a list of hashes, 
## where each row of the TD is a hash with the key set to 
## the column name
##
## Arguments:
##      $td = Trait Dictionary contents, lines of a semi-colon
##          separated and quoted file
##
## Returns: reference to array of parsed lines
######
sub parseTD {
    my $td = shift;
    my @parsed = ();

    # Split TD by Line
    my @lines = (split /\n/, $td);

    # Get Headers from TD, first line
    my $headers = parseTDLine($lines[0]);

    # Parse each additional line in the TD
    for my $i (1 .. $#lines) {
        my $line = parseTDLine($lines[$i], $headers);
        push(@parsed, $line);
    }

    # Return parsed Lines
    return(\@parsed);
}


#######
## parseTDLine()
##
## Parse the Trait Dictionary Line into a hash with the 
## keys set to the column names
##
## Arguments:
##      $line: semi-colon, quoted line from the TD
##      [$headers]: reference to hash of header names with keys 
##          set to column index
##
## Returns: hash of line contents
#######
sub parseTDLine {
    my $line = shift;
    my $headers = shift;
    my %item;

    my @parts = split('";', $line);
    my $i = 0;
    my $cat_count = 11;
    for (@parts) {
        my $value = $_;
        $value =~ s/^"//;
        $value =~ s/;$//;
        $value =~ s/"$//;
        $value =~ s/\r[\n]*//gm;

        if ( defined($value) && !($value eq "") && !($value eq "\"") ) {
            if ( defined($headers) ) {
                if ( defined($headers->{$i}) ) {
                    my $header = $headers->{$i};
                    $item{$header} = $value;
                    if ( index($header, "Category") != -1 ) {
                        my $cat_index = $header;
                        $cat_index =~ s/[Cc]ategory[ ]*//;
                        if ( $cat_index > $TW_SCALE_CATEGORY_COUNT ) {
                            $TW_SCALE_CATEGORY_COUNT = $cat_index;
                        }
                    }
                }
                else {
                    if ( $cat_count > $TW_SCALE_CATEGORY_COUNT) { $TW_SCALE_CATEGORY_COUNT = $cat_count; }
                    $item{"Category $cat_count"} = $value;
                    $cat_count++;
                }
            }
            else {
                $item{$i} = $value;
            }
        }

        $i++;
    }

    return \%item;
}


######
## addVariables()
## 
## Populate the 'Variables' worksheet
##
## Arguments:
##      $ws: Variables Excel::Writer::XLSX Worksheet
##      $rows: Parsed TD Rows
##      $error_format: The workbook error cell format
######
sub addVariables {
    my $ws = shift;
    my $rows = shift;
    my $error_format = shift;
    my $r = 0;
    my $c = 0;

    message("Writing Variables...");

    # Add Headers
    for (@TW_VARIABLE_HEADERS) {
        my $header = $_;
        $ws->write($r, $c, $header);
        $c++;
    }

    # Add Values
    for (@$rows) {
        my $row = $_;
        $r++;
        $c = 0;
        for (@TW_VARIABLE_HEADERS) {
            my $header = $_;
            my $value = $row->{$header};
            if ( !defined($value) ) {
                $value = "";
            }

            # Parse some column values
            if ( $header eq "Variable ID" ) {
                $value = reduceID($value);
            }
            elsif ( $header eq "Variable label" && $value eq "" ) {
                if ( defined($row->{'Trait name'}) && defined($row->{'Scale name'}) ) {
                    $value = $row->{'Trait name'} . " - " . $row->{'Scale name'};
                }
            }
            elsif ( $header eq "Date" ) {
                $value = formatDate($value);
            }
            elsif ( $header eq "VARIABLE KEY" ) {
                my $tn_cell = xl_rowcol_to_cell($r, $c-3);
                my $mn_cell = xl_rowcol_to_cell($r, $c-2);
                my $sn_cell = xl_rowcol_to_cell($r, $c-1);
                $value = "=CONCATENATE(" . $tn_cell . ", \"|\", " . $mn_cell . ", \"|\", " . $sn_cell . ")";
            }

            $ws->write($r, $c, $value);            
            $c++;
        }
    }

    # Add conditional formats
    $c = 0;
    for (@TW_VARIABLE_HEADERS) {
        my $header = $_;
        if ( $header eq "Variable ID" || $header eq "Variable name" || $header eq "Variable label" || $header eq "Variable synonyms" || $header eq "VARIABLE KEY" ) {
            $ws->conditional_formatting(1, $c, $CF_MAX_ROW, $c, {
                type => 'duplicate',
                format => $error_format
            });
        }
        elsif ( $header eq "Trait name" ) {
            $ws->conditional_formatting(1, $c, $CF_MAX_ROW, $c, {
                type => 'formula',
                criteria => '=AND(NOT(ISBLANK(O2)), ISERROR(MATCH(O2,Traits!B:B,0)))',
                format => $error_format
            });
        }
        elsif ( $header eq "Method name" ) {
            $ws->conditional_formatting(1, $c, $CF_MAX_ROW, $c, {
                type => 'formula',
                criteria => '=AND(NOT(ISBLANK(P2)), ISERROR(MATCH(P2,Methods!B:B,0)))',
                format => $error_format
            });
        }
        elsif ( $header eq "Scale name" ) {
            $ws->conditional_formatting(1, $c, $CF_MAX_ROW, $c, {
                type => 'formula',
                criteria => '=AND(NOT(ISBLANK(Q2)), ISERROR(MATCH(Q2,Scales!B:B,0)))',
                format => $error_format
            });
        }
        $c++;
    }

    message("   Wrote $r Variables");
}


######
## addTraits()
## 
## Populate the 'Traits' worksheet
##
## Arguments:
##      $ws: Traits Excel::Writer::XLSX Worksheet
##      $rows: Parsed TD Rows
######
sub addTraits {
    my $ws = shift;
    my $rows = shift;
    my $error_format = shift;
    my $r = 0;
    my $c = 0;

    message("Writing Traits...");

    # Add Headers
    for (@TW_TRAIT_HEADERS) {
        my $header = $_;
        $ws->write($r, $c, $header);
        $c++;
    }

    # Get Unique Traits
    my %traits;
    for (@$rows) {
        my $row = $_;
        $traits{$row->{'Trait name'}} = 1;
    }

    # Add Values
    for (@$rows) {
        my $row = $_;

        # Only add each trait once...
        if ( $traits{$row->{'Trait name'}} == 1) {
            $r++;
            $c = 0;
            $traits{$row->{'Trait name'}} = 0;

            for (@TW_TRAIT_HEADERS) {
                my $header = $_;
                my $value = $row->{$header};
                if ( !defined($value) ) {
                    $value = "";
                }

                # Parse some column values
                if ( $header eq "Trait ID" ) {
                    $value = reduceID($value);
                }

                $ws->write($r, $c, $value);            
                $c++;
            }
        }
    }

    # Add conditional formats
    $c = 0;
    for (@TW_TRAIT_HEADERS) {
        my $header = $_;
        if ( $header eq "Trait ID" || $header eq "Trait name" ) {
            $ws->conditional_formatting(1, $c, $CF_MAX_ROW, $c, {
                type => 'duplicate',
                format => $error_format
            });
        }
        elsif ( $header eq "Trait class" ) {
            $ws->conditional_formatting(1, $c, $CF_MAX_ROW, $c, {
                type => 'formula',
                criteria => "=AND(NOT(ISBLANK(C2)), ISERROR(MATCH(C2,'Trait Classes'!B:B,0)))",
                format => $error_format
            });
        }
        $c++;
    }

    message("   Wrote $r Traits");
}


######
## addMethods()
## 
## Populate the 'Methods' worksheet
##
## Arguments:
##      $ws: Methods Excel::Writer::XLSX Worksheet
##      $rows: Parsed TD Rows
######
sub addMethods {
    my $ws = shift;
    my $rows = shift;
    my $error_format = shift;
    my $r = 0;
    my $c = 0;

    message("Writing Methods...");

    # Add Headers
    for (@TW_METHOD_HEADERS) {
        my $header = $_;
        $ws->write($r, $c, $header);
        $c++;
    }

    # Get Unique Methods
    my %methods;
    for (@$rows) {
        my $row = $_;
        $methods{$row->{'Method name'}} = 1;
    }

    # Add Values
    for (@$rows) {
        my $row = $_;

        # Only add each method once...
        if ( $methods{$row->{'Method name'}} == 1) {
            $r++;
            $c = 0;
            $methods{$row->{'Method name'}} = 0;

            for (@TW_METHOD_HEADERS) {
                my $header = $_;
                my $value = $row->{$header};
                if ( !defined($value) ) {
                    $value = "";
                }

                # Parse some column values
                if ( $header eq "Method ID" ) {
                    $value = reduceID($value);
                }

                $ws->write($r, $c, $value);            
                $c++;
            }
        }
    }

    # Add conditional formats
    $c = 0;
    for (@TW_METHOD_HEADERS) {
        my $header = $_;
        if ( $header eq "Method ID" || $header eq "Method name" ) {
            $ws->conditional_formatting(1, $c, $CF_MAX_ROW, $c, {
                type => 'duplicate',
                format => $error_format
            });
        }
        $c++;
    }

    message("   Wrote $r Methods");
}


######
## addScales()
## 
## Populate the 'Scales' worksheet
##
## Arguments:
##      $ws: Scales Excel::Writer::XLSX Worksheet
##      $rows: Parsed TD Rows
######
sub addScales {
    my $ws = shift;
    my $rows = shift;
    my $error_format = shift;
    my $r = 0;
    my $c = 0;

    message("Writing Scales...");

    # Add Headers
    for (@TW_SCALE_HEADERS) {
        my $header = $_;
        $ws->write($r, $c, $header);
        $c++;
    }

    # Add Scale Category Columns
    for my $i (1 .. $TW_SCALE_CATEGORY_COUNT) {
        $ws->write($r, $c, "Category $i");
        $c++;
    }

    # Get Unique Scales
    my %scales;
    for (@$rows) {
        my $row = $_;
        if ( defined($row->{'Scale name'}) ) {
            $scales{$row->{'Scale name'}} = 1;
        }
    }

    # Add Values
    for (@$rows) {
        my $row = $_;

        # Only add each scale once...
        if ( defined($row->{'Scale name'}) && $scales{$row->{'Scale name'}} == 1 ) {
            $r++;
            $c = 0;
            $scales{$row->{'Scale name'}} = 0;

            # Add Known Headers
            for (@TW_SCALE_HEADERS) {
                my $header = $_;
                my $value = $row->{$header};
                if ( !defined($value) ) {
                    $value = "";
                }

                # Parse some column values
                if ( $header eq "Scale ID" ) {
                    $value = reduceID($value);
                }

                $ws->write($r, $c, $value);            
                $c++;
            }

            # Parse Scale Categories
            my %parsed_scales;
            for (keys %$row) {
                my $key = $_;
                if ( rindex($key, "Category") == 0 ) {
                    my @cat_parts = split(/=/, $row->{$key});
                    my $cat_key = trimws($cat_parts[0]);
                    my $cat_value = trimws($cat_parts[1]);
                    $parsed_scales{$cat_key} = $cat_value;
                }
            }

            # Add Scale Categories, sorted by key
            foreach my $key (sort sortKeys (keys(%parsed_scales))) {
                $ws->write($r, $c, $key . "= " . $parsed_scales{$key});
                $c++;
            }
        }
    }

    # Add conditional formats
    $c = 0;
    for (@TW_SCALE_HEADERS) {
        my $header = $_;
        if ( $header eq "Scale ID" || $header eq "Scale name" ) {
            $ws->conditional_formatting(1, $c, $CF_MAX_ROW, $c, {
                type => 'duplicate',
                format => $error_format
            });
        }
        $c++;
    }

    message("   Wrote $r Scales");
}


######
## addTraitClasses()
##
## Populate the 'Trait Classes' worksheet
## Arguments:
##      $ws: Trait Classes Excel::Writer::XLSX Worksheet
##      $rows: Parsed TD Rows
######
sub addTraitClasses {
    my $ws = shift;
    my $rows = shift;
    my $error_format = shift;
    my $r = 0;
    my $c = 0;

    message("Writing Trait Classes...");

    # Add Headers
    for (@TW_TRAIT_CLASS_HEADERS) {
        my $header = $_;
        $ws->write($r, $c, $header);
        $c++;
    }

    # Get Unique Trait Classes
    my %classes;
    for (@$rows) {
        my $row = $_;
        if ( defined($row->{'Trait class'}) ) {
            $classes{$row->{'Trait class'}} = 1;
        }
    }

    # Add Values
    for (keys %classes) {
        my $class = $_;
        $c = 0;
        $r++;
        if ( !($class eq "") ) {
            my $id = $class;
            $id =~ s/[ ]*[Tt]rait[s]?//g;
            $id =~ s/ /_/g;
            
            $ws->write($r, $c, $id);
            $c++;
            $ws->write($r, $c, $class);
        }
    }

    message("   Wrote $r Trait Classes");
}


######
## addRoot()
##
## Populate the 'Root' worksheet
##
## Arguments:
##      $ws: Scales Excel::Writer::XLSX Worksheet
##      $root: Root ID
##      $name: Root name
##      $namespace: Default namespace
######
sub addRoot {
    my $ws = shift;
    my $root = shift;
    my $name = shift;
    my $namespace = shift;

    message("Writing Root Info...");

    # Add Headers
    my $c = 0;
    for (@TW_ROOT_HEADERS) {
        my $header = $_;
        $ws->write(0, $c, $header);
        $c++;
    }

    # Add Values
    $ws->write(1, 0, $root);
    $ws->write(1, 1, $name);
    $ws->write(1, 2, $namespace);
}



#######################################
## UTILITY FUNCTIONS
#######################################


######
## reduceID()
##
## Reduce Variable ID:
## Convert CO_xxx:000000n to a simple integer of n
##
## Arguments:
##      $id
##
## Returns: reduced ID
######
sub reduceID {
    my $value = $_[0];
    if ( index($value, ":") != -1 ) {
        $value = (split /:/, $value)[1];
    }
    if ( $value =~ /0+[1-9]+/ ) {
        $value =~ s/^0*//g;
    }
    elsif ( $value =~ /^0+$/ ) {
        $value = 0;
    }
    return $value;
}


######
## sortKeys()
##
## Array Sort Function:
## Sort numerically, if both values are a number
## Otherwise, sort alphabetically
######
sub sortKeys {
    return looks_like_number($a) && looks_like_number($b) ? $a <=> $b : $a cmp $b;
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
## formatDate()
##
## Convert an Excel date number to YYYY-MM-dd format
##
## Arguments:
##      $date
##
## Returns: formatted date
######
sub formatDate {
    my $date = shift;
    if ( looks_like_number($date) ) {
        my $dt = DateTime::Format::Excel->parse_datetime($date);
        $date = $dt->ymd();
    }
    return $date;
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