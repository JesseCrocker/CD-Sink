CD-Sink
=======

Automatically generate REST services from core-data models for light-weight sync services.

this ALPHA software that is being actively developed.

It is not designed with an eye to speed, you might not want to use it for production, but it is great for rapid prototyping.

What it doesn't do yet:
Updating objects, this will come soon.

What it doesn't do:
Megring changes to objects.
Inserts and deletes can be synced, but not conflicting changes to existing objects can not be merged.
Many-to-Many relationships are not handled.
Circular relationships could cause an infinte loop: A->B->C->A


How to use:
Create a Core-Data model in your project.
Use RestKit(http://restkit.org/) to map your data model to json.  Map all of your attributes and relationships with there original names.
Configure CDSink by editing the config.json file to point to your data model, and to exclude any attributes or relationships that
you do not want to sync.
Proccess your data model: ./xcd_model_parser.pl config.json
This will generate a SQL schema, you will probably want to edit it, by default all core-data text fields are mapped as varchar(100).
Create your mysql database, create the tables in the generated sql schema, and the system_schema.sql files.
Start CDSink: ./script/cdsink daemon

Refer to Mojolicious documentation for information about deploying mojolicious.

perl modules needed:
DBI
DBD::mysql
Authen::Passphrase::BlowfishCrypt
XML::Simple
JSON
Mojolicious

routes for sync:
/deletes
/changes - inserts and updates
/log - changes and deletes
