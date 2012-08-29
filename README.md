CD-Sink
=======

Automatically generate REST services from core-data models for light-weight sync services.

This is ALPHA software that is being actively developed.

It is not designed with an eye to speed, you might not want to use it for production, but it is great for rapid prototyping.

### Why use CD-Sink instead of iCloud core-data?
If you have to ask that, then there is a good chance you will be just fine using iCloud.
But if you need to do any of the following then CD-Sink might be a good choice:

* Sync with non-apple devices.
* Sync with a non-appstore mac app.
* Generate notifications based on synced data.
* Access data through a web interface.
* Share data between users.
* Store more data than is reasonable with iCloud.
* Enable the same data to be used by multiple apple ids.


## What it doesn't do yet:
* Proper handling of too many relations. Every object that points to a too many creates its own copy of that object

## What it doesn't do:
* Megring changes to objects.
* Inserts and deletes can be synced, but not conflicting changes to existing objects can not be merged.
* Many-to-Many relationships are not handled.
* Circular relationships could cause an infinte loop: A->B->C->A


## How to use:
Create a Core-Data model in your project.

Use RestKit(http://restkit.org/) to map your data model to json.  Map all of your attributes and relationships with there original names.

Configure CDSink by editing the config.json file to point to your data model, and to exclude any attributes or relationships that
you do not want to sync.

If you need sql tables in addition to your model, put them in sql/application.sql

Proccess your data model: ./xcd_model_parser.pl config.json

This will generate a SQL schema, you will probably want to edit it, by default all core-data text fields are mapped as varchar(100).

It will also connect to your SQL server and create tables.

Check out the routes that have been created: ./script/cdsink routes

Start CDSink: /script/cdsink daemon

Refer to Mojolicious documentation for information about deploying mojolicious.

## Perl modules needed:
* Mojolicious
* Mojolicious::Plugin::Database
* DBI
* DBD::mysql
* Authen::Passphrase::BlowfishCrypt
* XML::Simple
* JSON
* Data::UUID
* Net::APNS::Persistent

## routes for sync:
* /deletes
* /changes - inserts and updates
* /log - changes and deletes

## Customizing for your application:
sql/application.sql for custom tables

Custom templates: Entity.format

Two class of custom modules can be loaded, controllers and helpers.
