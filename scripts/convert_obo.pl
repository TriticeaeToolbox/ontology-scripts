#!/usr/bin/env perl

=head1 NAME

convert_obo.pl

=head1 SYNOPSIS

Usage: perl convert_obo.pl -d namespace [-n namespace] -o output [-v] input

Example: perl convert_obo.pl -d barley_traits -n barley_traits_trait -n barley_traits_variable -o sgn.obo standard.obo

Options/Arguments:

=over 8

=item --default, -d

The default / root namespace.  This is the namespace that the other namespaces 
([{default}_trait, {default}_variable] or namespaces provided as -n args) will 
be converted to.  This is the namespace that will have to be given to the gmod 
scriptswhen loading an ontology into breedbase.

=item --namespace, -n

The namespace(s) from the standard-obo file to renamed to the default (-d) namespace 
in the output obo file. This option can be used more than once to specify multiple 
namespaces to include. To load an ontology into breedbase, this should include the 
namespaces of the ontology root term, trait classes, traits, and variables.

By default, this script will use the {default namespace}, {default namespace}_trait, 
and {default namepspace}_variable namespaces to convert if none are given here.

=item --output, -o

specify the output location for the sgn-obo file

=item --verbose, -v

verbose output

=item input

specify the location of the input standard-obo file

=back

=head1 DESCRIPTION

Convert a standard-obo file into an sgn-obo file to be loaded 
into a breeDBase instance.

This will rename all of the specified standard-obo namespaces into 
the single default namespace.

=head1 AUTHOR

David Waring <djw64@cornell.edu>

=cut


######
## TODO:
##      - Add scale definition (particulary for categorical scales) to variable definition
######


use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;


# PROGRAM INFORMATION
my $PROGRAM_NAME = "convert_obo.pl";
my $PROGRAM_VERSION = "1.1";





#######################################
## PARSE INPUT 
#######################################

# Get command line flags/options
my $default_namespace;
my $namespaces;
my $output;
my $verbose;
GetOptions("default=s" => \$default_namespace,
           "namespace=s@" => \$namespaces,
           "output=s" => \$output,
           "verbose" => \$verbose);
my $input = shift;


# Make sure input file is given
if ( !defined($input) ) {
    die "==> ERROR: The location of the standard-obo file must be specified.";
}

# Make sure output file is given
if ( !defined($output) ) {
    die "==> ERROR: The output file location (-o) must be specified.";
}

# Make sure a default namespace is given
if ( !defined($default_namespace) ) {
    die "==> ERROR: A default namespace (-d) must be specified.";
}

# Use default namespaces, if none provided
if ( !defined($namespaces) ) {
    $namespaces = [$default_namespace . "_trait", $default_namespace . "_variable"];
}


# Print Input Info
message("Command Inputs:");
message("   Standard-OBO File: $input");
message("   SGN-OBO File: $output");
message("   Default Namespace: $default_namespace");
message("   Namespaces to Convert: " . join(',', @$namespaces));



#######################################
## READ OBO FILE
#######################################

# Read the input file
my $contents = readInput($input);


#######################################
## CONVERT OBO FILE
#######################################

# Update Header Information
$contents = updateHeader($contents);

# Convert the namespaces
$contents = convertNamespaces($default_namespace, $namespaces, $contents);

# Replace `name: 0`
$contents = replaceNameZero($contents);

# Remove DBXrefs
$contents = removeDBXrefs($contents);

# Write File
writeFile($output, $contents);




#######################################
## CONVERSION FUNCTIONS
#######################################


######
## readInput()
##
## Read the contents of the specified file
##
## Arguments:
##      $file: input file
##
## Returns: string of file contents
######
sub readInput {
    my $file = shift;

    open my $fh, '<', $file or die "Can't open input file [$file] $!";
    my $contents = do { local $/; <$fh> };

    return $contents;
}   


######
## updateHeaderKey
## 
## Update the value of the specified header key
##
## Arguments:
##      $key: header key
##      $value: header value
##      $contents: file contents to be updated
##
## Returns: updated file contents
######
sub updateHeaderKey {
    my $key = shift;
    my $value = shift;
    my $contents = shift;

    if ( $contents =~ /\n$key\:.*\n/ ) {
        $contents =~ s/\n$key\:.*\n/\n$key: $value\n/;
    }
    else {
        $contents =~ s/\n\n/\n$key: $value\n\n/;
    }

    return $contents;
}


######
## updateHeader()
##
## Update the header of the OBO file
##
## Arguments:
##      $contents: file contents to be updated
##
## Returns: updated file contents
######
sub updateHeader {
    my $contents = shift;

    $contents = updateHeaderKey("date", getTimestamp(), $contents);
    $contents = updateHeaderKey("auto-generated-by", $PROGRAM_NAME . "/" . $PROGRAM_VERSION, $contents);
    $contents = updateHeaderKey("remark", "This file was converted to an SGN-compatible obo file from a standard obo file [$input]", $contents);
    $contents = updateHeaderKey("default-namespace", $default_namespace, $contents);

    return $contents;
}


######
## convertNamespaces()
##
## Convert the list of namespaces to the default one
## 
## Arguments:
##      $keep: the default namespace to keep
##      $convert: reference to array of namespaces to convert
##      $contents: file contents to be updated
##
## Returns: updated file contents
######
sub convertNamespaces {
    my $keep = shift;
    my $convert = shift;
    my $contents = shift;

    for (@$convert) {
        my $ns = $_;
        $contents =~ s/\nnamespace:[ ]*$ns\n/\nnamespace: $keep\n/g;
    }

    return $contents;
}


######
## replaceNameZero()
##
## Replace `name: 0` with `name: null` in all Term blocks since  
## this throws an error in the Chado gmoad_load_cvterms.pl script
## 
## Arguments:
##      $contents: file contents to be updated
##
## Returns: updated file contents
######
sub replaceNameZero {
    my $contents = shift;
    $contents =~ s/^name: 0$/name: null/gm;
    return $contents;
}


#######
## removeDBXrefs()
##
## Remove DBX refs from the def line since SGN requires
## a specific format that may not be followed
##
## Arguments
##      $contents: file contents to be updated
##
## Returns: updated file contents
######
sub removeDBXrefs {
    my $contents = shift;
    $contents =~ s/^def: (.*) \[.*\]$/def: $1 \[\]/gm;
    return $contents;
}


######
## writeFile()
##
## Write the file contents to the specified file
##
## Arguments:
##      $file: file path to output file
##      $contents: file contents to write
######
sub writeFile {
    my $file = shift;
    my $contents = shift;

    message("Writing SGN-OBO file [$file]...");

    open(my $fh, '>', $file);
    print $fh $contents;
    close($fh);
}



#######################################
## UTILITY FUNCTIONS
#######################################



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