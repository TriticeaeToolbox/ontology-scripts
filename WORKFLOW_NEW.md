Creating a New Ontology
====

These instructions provide the basic steps for creating a new trait ontology.  The 
ontology will be managed in an Excel Workbook (referred to as a **Trait Workbook**) 
which will be used to generate a **Trait Dictionary** (used to update the 
croptontology.org website) and a **SGN-OBO File** (used to load the ontology 
into a breedbase instance).

## Create a New Trait Workbook

You can create a mostly blank Trait Workbook using the `create_tw.pl` script. 
You'll need to give the script the following parameters:

- `-d` = The default ontology namespace.  This namespace will be 
applied to all of the ontology terms loaded into breedbase. (tomato_trait)
- `-n` = The human-readable name for the ontology.  This name will 
be displayed on the bredebase website. (Tomato Traits)
- `-r` = The root ontology id, such as the Crop Ontology Identifier.  If 
you're creating a new ontology and this does not yet exist, you'll first 
need to get an ID from the curators of the cropontology.org website.  If you 
don't have one yet, you can use a placeholder (such as CO_999) and update it 
in the Trait Workbook later. (CO_999)
- `-o` = The path to the generated Trait Workbook .xlsx file. (./traits.xlsx)

When *not* providing the input argument, the script will create a new trait workbook 
file containing a single variable, trait, method and scale as an example.

```perl
perl create_tw.pl -d tomato_trait -n "Tomato Traits" -r CO_999 -o ./traits.xlsx -v
```

## Ontology Term Definitions

At this point, you should have a mostly blank Trait Workbook.  Each worksheet in the 
workbook contains information for each of the different types of ontology terms.  It is
important to know how the different ontology terms are defined and how they relate to 
each other:

- A **variable** is the term that actual phenotype observations are associated with. The 
variable is composed of a *trait*, *method*, and *scale*.  For example, when you 
go out into the field and measure plant height you will associate your measurement 
with a single variable that is composed of the trait for plant height, the method 
that describes the way you observed the trait (such as a direct measurement of plant 
height using a meter stick), and the scale used to record the measurmenet (such as cm).
- A **trait** is the entity that is observed.  In our plant height example, the 
trait would be plant height with a description of how plant height is defined 
for your crop.
- A **method** is the procedure for observing a trait.  In our example for plant height
we would create a method for the direct measurement of plant height that describes 
how to measure plant height directly in the filed using a meter stick.  A trait 
can have more than one method associated with it, if it is observed in different ways 
(such as the direct measurement of the height using a meter stick vs a calculated 
measurement of plant height using a clinometer).
- A **scale** is the units in which a trait is observed (such as cm).  A categorical 
scale can have descriptions for each of its categories.
- A **trait class** is a category of traits.  Each trait should be associated with 
a single trait class to keep similar traits together (such as Agronomic, Quality, 
Disease, etc).
- The single **root** term contains the Crop Ontology ID, the ontology name and its 
namespace.  This information will be used when generating the trait dictionary 
and obo files.


## Trait Workbook Usage

Each ontology data type has a separate worksheet in the Trait Workbook. Almost all of 
the columns come directly from the Crop Ontology Trait Dictionary format.  For more 
information and column descriptions, look at the README sheet in the Trait Dictionary 
template (such as the [Trait Dictionary template v5](http://www.cropontology.org/TD_template_v5.xls)) 
found on the cropontology.org website.

There are some columns that are not part of the Trait Dictionary format.  These are 
found on the **Variables** worksheet:

- **Variable label**: this is used as the name of the variable term in the generated 
obo files.  This name is then displayed as the variable name on the breedbase website.
In the Trait Dictionary of existing crops, the *Variable name* column often uses an 
abbreviated / coded form of the variable name (such as PH_M_cm) and is not very 
user-friendly for users of the breedbase website.  The *Variable label* column should 
use a human-readable name that describes the variable in a concise yet descriptive way.  
We have found that the form {trait name} - {scale name} (such as 'Plant Height - cm') 
works well for most variables.  If you have a trait that uses the same scale but 
different methods, you will need to include some short description of the method in 
the label name to differentiate them (such as 'Plant Height - measured - cm' and 'Plant 
Height - calculated - cm').
- The **Trait name**, **Method name**, and **Scale name** columns are used to identify 
the trait, method, and scale that compose the variable.  All three terms must be defined 
and must match the name of the term exactly as defined in their corresponding worksheets.
- The **VARIABLE KEY** column concatenates the trait, method, and scale names to check 
for duplicates of the same combination of trait, method and scale.  There should only be 
one variable for each combination of trait, method and scale.

**IDs**
- The **Variable ID**, **Trait ID**, **Method ID**, and **Scale ID** columns need to have 
an ID number that is unique across all of the data types (a scale and a method cannot 
have the same ID number).  This column should contain an integer and will be expanded 
into the full term ID (such as CO_999:0000001) when building the trait dictionary and 
obo files.

## Building Files

Once you have a Trait Workbook with your trait information filled in, you can follow 
the steps outlined in the [Loading an Existing Ontology into Breedbase](WORKFLOW_EXISTING.md) 
workflow to create an obo file and/or trait dictionary and load the obo file into 
a breedbase instance.