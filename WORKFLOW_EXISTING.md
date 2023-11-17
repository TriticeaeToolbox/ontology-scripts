Loading an Existing Ontology into Breedbase
========

These steps outline the general workflow of updating an ontology (by modifying its 
Trait Workbook), creating the standard- and sgn-obo files, and loading the 
sgn-obo file into a breedbase instance.

1) Edit / Add Traits in the **Trait Workbook**

    > The **Trait Workbook** is an excel file containing separate 
    > worksheets for each data type: Variables, Traits, Methods, 
    > Scales, Trait Classes, and Ontology Root Information.
    > **Example:** `traits.xlsx` file in the sugar kelp example directory.
    
    > If there is an exisiting **Trait Dictionary** for the crop ontology,
    > the **Trait Workbook** can be created using the `create_tw.pl` script.
    
    > For more information on creating a **Trait Workbook** for a new crop
    > (when an existing **Trait Dictionary** does not exist), see the 
    > [Creating a New Ontology workflow](WORKFLOW_NEW.md)


2) Generate the **Trait Dictionary** and/or **standard-obo** files:
    
    `perl build_traits.pl -t traits.csv -o traits.obo -u DJW -i T3 -v traits.xlsx`

     > The `traits.csv` file can be used to update the Crop Ontology website

     > The `traits.obo` file will be used to create the obo file that is necessary to load the trait ontology into breedbase


3) Convert the **standard-obo** file to an **sgn-obo** file:
    
    `perl convert_obo.pl 
        --remove-synonyms
        -d wheat_trait 
        -o sgn.obo -v traits.obo`

    > The `sgn.obo` file can be used to load the traits into **breeDBase**


4) Load the traits into **breeDBase**

    4A) Load the ontology

        cd /home/production/cxgn/Chado/chado/bin
        perl ./gmod_load_cvterms.pl 
            -H localhost -D {db_name} -d Pg -r postgres -p "{postgress password}"
            -s CO_360 -n sugar_kelp_trait -uv /path/to/sgn.obo


    4B) Connect the ontology terms

        perl ./gmod_make_cvtermpath.pl 
            -H localhost -D {db_name} -d Pg -u postgres -p "{postgress password}" 
            -c sugar_kelp_trait -v


    4C) Tag the ontology (first time only)

        Update the  cvprop table to mark new cv as a 'trait_ontology'
            cv_id = cv.id of 'sugar_kelp_trait'
            type_id = cvterm.cvterm_id of 'trait_ontology'


    4D) Make sure sgn_local.conf variables are correctly set

        trait_ontology_db_name          CO_360
        trait_cv_name                   sugar_kelp_trait
        onto_root_namespaces            CO_360 (Sugar Kelp Traits), ...
        trait_variable_onto_namespace   CO_360 (Sugar Kelp Traits), ...
        
