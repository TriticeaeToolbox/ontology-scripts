#!/usr/bin/env perl

=head1 NAME

build_trait_props.pl

=head1 SYNOPSIS

Usage: perl build_trait_props.pl [-o output] [-i institution] [-v] file

Options/Arguments:

=over 8

=item -o

specify the output location for the trait props xlsx file

=item -i

filter the output to contain only the variables used by the specified institution

=item -v

verbose output

=item file

file path to the trait workbook

=back

=head1 DESCRIPTION

Build a trait props file that contains additional information about trait variables that 
will be loaded into a breedbase database using the `load_trait_props.pl` script.

=head1 AUTHOR

David Waring <djw64@cornell.edu>

=cut


use strict;
use warnings;
use Getopt::Long;
use Spreadsheet::Read;
use Excel::Writer::XLSX;
use Data::Dumper;


#
# MAP OF TRAIT ONTOLOGY SCALE CLASSES -> BREEDBASE TRAIT FORMATS
# The supported breedbase types: numeric, qualitative, date or boolean
#
my %TRAIT_FORMATS = (
    'Numerical' => 'numeric',
    'Duration' => 'numeric',
    'Nominal' => 'qualitative',
    'Ordinal' => 'qualitative',
    'Text' => 'qualitative',
    'Time' => 'date',
    'Boolean' => 'boolean'
);

my @OUTPUT_HEADER = qw \trait_name trait_format trait_default_value trait_minimum trait_maximum trait_categories trait_details trait_repeat_type\;



#######################################
## PARSE INPUT
#######################################

# Get command line flags/options
my $verbose;
my $output;
my $filter_institution;
GetOptions("v" => \$verbose,
           "o=s" => \$output,
           "i=s" => \$filter_institution);
my $wb_file = shift;


# Make sure workbook file is given
if ( !$wb_file ) {
    die "==> ERROR: A trait workbook file is a required argument.\n";
}

# Make sure the output file is given
if ( !$output ) {
    die "==> ERROR: The output file is a required argument.\n";
}


# Print Input Info
message("Command Inputs:");
message("   Trait Workbook File: $wb_file");
if ( defined($filter_institution) ) {
    message("   Filter Traits By Institution: $filter_institution");
}
message("   Output File: $output");


# Read the trait workbook file
message("Opening Trait Workbook File [$wb_file]:");
my $book = Spreadsheet::Read->new($wb_file) or die $@;
my $variables_sheet = $book->sheet('Variables');
my $scales_sheet = $book->sheet('Scales');

# Loop through each variable
message("Reading Variables...");
my @variables;
my @variable_headers = $variables_sheet->row(1);
for ( my $i = 2; $i <= $variables_sheet->maxrow; $i++ ) {
    my @row = $variables_sheet->row($i);
    my %variable;

    # Parse the columns in each row
    while ( my ($index, $value) = each(@row) ) {
        my $key = $variable_headers[$index];
        $variable{name} = $value if $key eq 'Variable label';
        $variable{repeat} = $value if $key eq 'Repeat type';
        $variable{institution} = $value if $key eq 'Institution';
        $variable{trait} = $value if $key eq 'Trait name';
        $variable{method} = $value if $key eq 'Method name';
        $variable{scale} = $value if $key eq 'Scale name';
    }

    # Include variable if no filter institution of if institution matches
    my $include = 1;
    if ( defined $filter_institution ) {
        $include = 0;
        my $institution = $variable{institution};
        if ( defined $institution && $institution ne '' ) {
            for (split(/\s*\,\s*/, $institution)) {
                if ( $_ eq $filter_institution ) {
                    $include = 1;
                }
            }
        }
    }

    # Add the variable to all variables, if included
    if ( $include ) {
        push(@variables, \%variable);
    }
}
message("..." . scalar(@variables) . " Variables read");


# Loop through each scale
message("Reading Scales...");
my %scales;
my @scale_headers = $scales_sheet->row(1);
for ( my $i = 2; $i <= $scales_sheet->maxrow; $i++ ) {
    my @row = $scales_sheet->row($i);
    my %scale;
    my @categories;

    # Parse the columns in each row
    while ( my ($index, $value) = each(@row) ) {
        my $key = $scale_headers[$index];
        $scale{name} = $value if $key eq 'Scale name';
        $scale{class} = $value if $key eq 'Scale class';
        $scale{minimum} = $value if $key eq 'Lower limit';
        $scale{maximum} = $value if $key eq 'Upper limit';
        if ( defined $value && $value ne '' && index($key, "Category") != -1 ) {
            push(@categories, $value);
        }
    }

    # Parse categories into keys
    my @parsed_categories;
    foreach (@categories) {
        my @items = split('=', $_);
        push(@parsed_categories, $items[0]);
    }

    $scale{categories} = join('/', @parsed_categories);
    $scales{$scale{name}} = \%scale;
}
message("..." . scalar(keys %scales) . " Scales read");



# Parse each variable
my @rows;
push(@rows, \@OUTPUT_HEADER);
foreach my $variable (@variables) {
    my $trait_name = $variable->{name};
    my $trait_details = "TRAIT: " . $variable->{trait} . " ::: METHOD: " . $variable->{method} . " ::: SCALE: " . $variable->{scale};
    my $trait_repeat_type = $variable->{repeat};

    my $scale = $scales{$variable->{scale}};
    if ( ! defined $scale ) {
        print STDERR "WARNING: Variable $trait_name does not have a matching scale!\n";
        next;
    }

    my $trait_format = $TRAIT_FORMATS{$scale->{class}} || "";
    my $trait_minimum = $scale->{minimum};
    my $trait_maximum = $scale->{maximum};
    my $trait_categories = $scale->{categories};

    my @row = (
        $trait_name,
        $trait_format,
        "",
        $trait_minimum,
        $trait_maximum,
        $trait_categories,
        $trait_details,
        $trait_repeat_type
    );
    push(@rows, \@row);
}


# Write to output file
message("Writing to output file [$output]");
my $wb = Excel::Writer::XLSX->new($output);
my $ws = $wb->add_worksheet('Traits');

my $r = 0;
foreach my $row (@rows) {
    my $c = 0;
    foreach my $value (@$row) {
        $ws->write($r, $c, $value);
        $c++;
    }
    $r++;
}
message("All Done!");


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