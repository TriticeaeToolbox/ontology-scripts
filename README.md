Ontology Scripts
======

These are some general-purpose utility scripts that can be used to 
convert trait ontologies between various different formats that are 
used internally to manage the traits, by the Crop Ontology website, 
and by the breeDBase backend.

## File Formats

**Trait Workbook:** An Excel workbook containing separate worksheets for 
each data type: Variables, Traits, Methods, Scales, Trait Classes, and 
Ontology Root Information.  This file is used internally to edit and/or 
add new traits.

**Trait Dictionary:** A semi-colon separated flat text file used by the Crop 
Ontology website.  Each row of a Trait Dictionary is an observation 
variable and contains the complete trait, method and scale information 
for the variable.

**OBO:** A text file format used by OBO-Edit to store ontology information.
Each data type (Variable, Trait, Method, Scale) is represented by a 
`[Term]` block and their relationships are defined by `is_a`, `method_of`, 
`scale_of` and `variable_of` terms.

  * The standard-obo file contains separate namespaces for each data type
    
  * The sgn-obo file uses a single namespace for the root elements, variables 
    and traits
    
## Documentation

### Workflows

The following documents contain information on the general steps and workflow of
creating a new ontology from scratch or working with an existing 

- [Creating an ontology from scrach](WORKFLOW_NEW.md)
- [Working with an existing ontology](WORKFLOW_EXISTING.md)
    
### Scripts

**create_tw.pl** - Create a Trait Workbook from an existing Trait Dictionary

```
NAME
    create_tw.pl

SYNOPSIS
    Usage: perl create_tw.pl -d namespace -n name -r root -o output [-v] [input]

    Options/Arguments:

    -d      the default ontology namespace. This will be used when
            generating an obo file (ex sugar_kelp_trait).

    -n      the ontology display name. A human-readable name for the
            ontology (ex Sugar Kelp Traits).

    -r      the ontology root id. Most likely the Crop Ontology ID (ex
            CO_360).

    -o      the output location of the trait workbook excel file (xlsx
            extension).

    -v      verbose output

    input   specify the Crop Ontology Root ID (ex: CO_360) to download the
            trait dictionary from cropontology.org OR the file path to an
            existing trait dictionary. If no input is provided, a new trait
            workbook will be created containing an example variable, trait,
            and scale.

DESCRIPTION
    This will create a 'Trait Workbook' Excel file from an existing Crop
    Ontology 'Trait Dictionary'. A Trait Dictionary is a flat text file
    containing all of the trait information available on the Crop Ontology
    website. The Trait Dictionary can be specified by it's CO ID (such as
    CO_360) and downloaded from the Crop Ontology website OR by a file path
    to an existing Trait Dictionary file.

    The resulting Trait Workbook will contain the worksheets 'Variables',
    'Traits', 'Methods', 'Scales', 'Trait Classes' and 'Root'. Some columns
    will have conditional formatting applied that will highlight duplicated
    values. The 'Trait name', 'Method name' and 'Scale name' columns in the
    'Variables' worksheet will highlight names of elements that do not match
    existing elements.

    The Trait Workbook file can be used by the build_traits.pl script to
    build a Trait Dictionary and/or OBO file.

AUTHOR
    David Waring <djw64@cornell.edu>
```

**build_traits.pl** - Build a Trait Dictionary and/or Standard-OBO file from a Trait Workbook

```
NAME
    build_traits.pl

SYNOPSIS
    Usage: perl build_traits.pl [-o output -u username] [-t output] [-i
    institution] [-c category count] [-fv] file

    Options/Arguments:

    -o      specify the output location for the generic obo file

    -u      specify the username of the person generating the file(s)
            required when generating an obo file

    -t      specify the output location for the trait dictionary file

    -i      filter the output to contain only the variables used by the
            specified institution

    -c      specify the number of scale categories that are defined in the
            trait workbook (default=10)

    -f      force the generation of the files (ignore the unique and
            required checks)

    -q      trait dictionary file: enclose the values with double quotes
            (and change double quotes in the value to two double quotes)

    -v      verbose output

    file    file path to the trait workbook

DESCRIPTION
    Build a trait dictionary (a flat text file containg all of the trait
    information used by the Crop Ontology website) and/or standard obo file
    (generalized ontology text file) from a "trait workbook" (an Excel
    workbook containing worksheets for a trait ontology's "Variables",
    "Traits", "Methods", "Scales", "Trait Classes" and "Root" information).

AUTHOR
    David Waring <djw64@cornell.edu>
```

**convert_obo.pl** - Convert a Standard-OBO file to an SGN-OBO file

```
NAME
    convert_obo.pl

SYNOPSIS
    Usage: perl convert_obo.pl -d namespace [-n namespace] -o output [-v]
    input

    Example: perl convert_obo.pl -d barley_traits -n barley_traits_trait -n
    barley_traits_variable -o sgn.obo standard.obo

    Options/Arguments:

    --default, -d
            The default / root namespace. This is the namespace that the
            other namespaces ([{default}_trait, {default}_variable] or
            namespaces provided as -n args) will be converted to. This is
            the namespace that will have to be given to the gmod scriptswhen
            loading an ontology into breedbase.

    --namespace, -n
            The namespace(s) from the standard-obo file to renamed to the
            default (-d) namespace in the output obo file. This option can
            be used more than once to specify multiple namespaces to
            include. To load an ontology into breedbase, this should include
            the namespaces of the ontology root term, trait classes, traits,
            and variables.

            By default, this script will use the {default namespace},
            {default namespace}_trait, and {default namepspace}_variable
            namespaces to convert if none are given here.

    --output, -o
            specify the output location for the sgn-obo file

    --verbose, -v
            verbose output

    input   specify the location of the input standard-obo file

DESCRIPTION
    Convert a standard-obo file into an sgn-obo file to be loaded into a
    breeDBase instance.

    This will rename all of the specified standard-obo namespaces into the
    single default namespace.

AUTHOR
    David Waring <djw64@cornell.edu>
```

### Perl Dependencies

- Excel::Writer::XLSX
- Excel::Writer::XLSX::Utility
- Spreadsheet::Read
- Spreadsheet::ParseXLSX
- Text::CSV_XS
- DateTime::Format::Excel
- `curl` must be installed to download a Trait Dictionary from the Crop Ontology website.