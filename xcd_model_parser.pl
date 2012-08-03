#!/usr/bin/perl -w
use strict;
use warnings;
use XML::Simple;
use Data::Dumper;
use Scalar::Util 'reftype';
use JSON;
use Carp;
use DBI;

my %excluded_attributes;
my %excluded_relationships;
my %config;
my @methods;
my %relationships;

my %model;

my @reserved_words = qw(ACCESSIBLE ADD ALL ALTER ANALYZE AND AS ASC ASENSITIVE BEFORE BETWEEN BIGINT BINARY BLOB BOTH BY CALL CASCADE
CASE CHANGE CHAR CHARACTER CHECK COLLATE COLUMN CONDITION CONSTRAINT CONTINUE CONVERT CREATE CROSS CURRENT_DATE CURRENT_TIME
CURRENT_TIMESTAMP CURRENT_USER CURSOR DATABASE DATABASES DAY_HOUR DAY_MICROSECOND DAY_MINUTE DAY_SECOND DEC DECIMAL DECLARE
DEFAULT DELAYED DELETE DESC DESCRIBE DETERMINISTIC DISTINCT DISTINCTROW DIV DOUBLE DROP DUAL
EACH ELSE ELSEIF ENCLOSED ESCAPED EXISTS
EXIT EXPLAIN FALSE FETCH FLOAT FLOAT4 FLOAT8 FOR FORCE FOREIGN FROM FULLTEXT
GRANT GROUP HAVING HIGH_PRIORITY HOUR_MICROSECOND HOUR_MINUTE
HOUR_SECOND IF IGNORE IN INDEX INFILE INNER INOUT INSENSITIVE INSERT INT INT1
INT2 INT3 INT4 INT8 INTEGER INTERVAL INTO IS ITERATE JOIN KEY KEYS
KILL LEADING LEAVE LEFT LIKE LIMIT LINEAR LINES LOAD LOCALTIME LOCALTIMESTAMP LOCK
LONG LONGBLOB LONGTEXT LOOP LOW_PRIORITY MASTER_SSL_VERIFY_SERVER_CERT
MATCH MAXVALUE MEDIUMBLOB MEDIUMINT MEDIUMTEXT MIDDLEINT MINUTE_MICROSECOND MINUTE_SECOND MOD MODIFIES NATURAL NOT
NO_WRITE_TO_BINLOG NULL NUMERIC ON OPTIMIZE OPTION OPTIONALLY OR ORDER OUT OUTER OUTFILE
PRECISION PRIMARY PROCEDURE PURGE RANGE READ READS READ_WRITE REAL REFERENCES REGEXP RELEASE
RENAME REPEAT REPLACE REQUIRE RESIGNAL RESTRICT RETURN REVOKE RIGHT RLIKE SCHEMA SCHEMAS
SECOND_MICROSECOND SELECT SENSITIVE SEPARATOR SET SHOW SIGNAL SMALLINT SPATIAL
SPECIFIC SQL SQLEXCEPTION SQLSTATE SQLWARNING SQL_BIG_RESULT
SQL_CALC_FOUND_ROWS SQL_SMALL_RESULT SSL STARTING STRAIGHT_JOIN TABLE
TERMINATED THEN TINYBLOB TINYINT TINYTEXT TO TRAILING TRIGGER TRUE UNDO UNION UNIQUE
UNLOCK UNSIGNED UPDATE USAGE USE USING UTC_DATE UTC_TIME UTC_TIMESTAMP VALUES VARBINARY VARCHAR
VARCHARACTER VARYING WHEN WHERE WHILE WITH WRITE XOR YEAR_MONTH ZEROFILL);

sub proccess_relationship($$$){
    my %r = %{shift @_};
    my $source_entity = shift @_;
    my $name = shift @_;

    my $destination_entity = $r{'destinationEntity'};
    
    if(is_entity_excluded($destination_entity)){
        return;
    }
    
    if($excluded_relationships{$source_entity} && $excluded_attributes{$source_entity}->{$name}){
        return;
    }
    
    my $sql_attribute;
    my %relationship;
    $relationship{"name"} = $name;
    
    if(!$r{"toMany"} || $r{"toMany"} eq "NO"){
        $sql_attribute = $name . "_ID";
        $relationship{"to_many"} = 0;
        if(is_parent_object($source_entity)){
            push @methods, "get '/$source_entity/:" . $source_entity . "_id/$name'";
        }elsif(has_children($source_entity)){
            my $global_parent = $config{"parent_object"}->[0];
            push @methods, "get '/$global_parent/:" . $global_parent . "_id/$source_entity/:" . $source_entity . "_id/$name'";
        }
        $relationship{"sql_field"} = $sql_attribute;
    }else{
        $sql_attribute = $name . "_COUNT";
        $relationship{"to_many"} = 1;
        if(is_parent_object($source_entity)){
            push @methods, "get '/$source_entity/:" . $source_entity . "_id/$name'";
        }elsif(has_children($source_entity)){
            my $global_parent = $config{"parent_object"}->[0];
            push @methods, "get '/$global_parent/:" . $global_parent . "_id/$source_entity/:" . $source_entity . "_id/$name'";
        }
    }
    $relationship{"delete_rule"} = $r{"deletionRule"};
    $relationship{"type"} = $destination_entity;
    $relationship{"inverse_name"} = $r{"inverseName"};
    $model{$source_entity}->{"relationships"}->{$name} = \%relationship;
}

sub is_reserved_word($){
    my $name = uc(shift @_);
    if ( grep { $_ eq $name} @reserved_words ){
        return 1;
    }else{
        return 0;
    }
}

sub is_parent_object($){
    my $name = shift @_;
    if(!$config{"parent_object"}){
        return 0;
    }
    if ( grep { $_ eq $name} @{$config{"parent_object"}} ){
        return 1;
    }else{
        return 0;
    }
}

sub has_children($){
    my $name = shift @_;
    if(!$config{"parent_object"}){
        return 0;
    }
    if ( grep { $_ eq $name} @{$config{"has_children"}} ){
        return 1;
    }else{
        return 0;
    }
}

sub is_entity_excluded($){
    my $name = shift @_;
    if(!$config{"exclude_entities"}){
        return 0;
    }
    if ( grep { $_ eq $name} @{$config{"exclude_entities"}} ){
        return 1;
    }else{
        return 0;
    }
}

sub is_attribute_excluded($$){
    my ($entity, $attribute) = @_;
    if(!$config{"excluded_attributes"}){
        return 0;
    }
    my $excluded_attributes = $config{"excluded_attributes"}->{$entity};
    if(!$excluded_attributes){
        return 0;
    }
    
    if ( grep { $_ eq $attribute} @{$excluded_attributes} ){
        return 1;
    }else{
        return 0;
    }
}

sub read_config($){
    my $filepath = shift @_;
    if(!$filepath){
        $filepath = "config.json";
    }
        
    my $json;
    {
        local $/=undef;
        open FILE, $filepath or die "Couldn't open file: $!";
        $json = <FILE>;
        close FILE;
    }
    %config = %{decode_json $json};
    #print Dumper(%config);
    %excluded_attributes = %{$config{"excluded_attributes"}};
}

sub parse_model{
    my $xml = new XML::Simple;
    my $data = $xml->XMLin($config{"data_model"});
    
    #print Dumper($data);
    my %entities = %{$data->{'entity'}};
    
    foreach my $entityName(keys(%entities)){
        if(is_entity_excluded($entityName)){
            next;
        }
        my %destination_entity;
        if(is_parent_object($entityName)){
            push @methods, "get '/$entityName'";
            push @methods, "post '/$entityName'";
            push @methods, "get '/$entityName/:$entityName" . "_id'";
            push @methods, "put '/$entityName/:$entityName" . "_id'";
            push @methods, "delete '/$entityName/:$entityName" . "_id'";
            $destination_entity{"parent_object"} = 1;
        }else{
            $destination_entity{"parent_object"} = 0;
        }
        
        my %source_entity = %{$entities{$entityName}};
        my %source_attributes = %{$source_entity{'attribute'}};
        foreach my $attributeName(keys(%source_attributes)){
            if(is_attribute_excluded($entityName, $attributeName)){
                next;
            }
            my %this_source_attribute = %{$source_attributes{$attributeName}};
            my $type = $this_source_attribute{'attributeType'};
            if($type eq 'String'){
                $type = "varchar(100)";
            }elsif($type eq 'Integer 16'){
                $type = "SMALLINT";
            }elsif($type eq 'Integer 32'){
                $type = "INT";
            }elsif($type eq 'Integer 64'){
                $type = "BIGINT";
            }elsif($type eq "Decimal"){
                $type = "DECIMAL(1,1)";
            }elsif($type eq "Double"){
                $type = "DOUBLE";
            }elsif($type eq "Float"){
                $type = "FLOAT";
            }elsif($type eq "Boolean"){
                $type = "BOOL";
            }elsif($type eq "Date"){
                $type = "DATETIME";
            }elsif($type eq "Binary"){
                $type = "BLOB";
            }elsif($type eq "Transformable"){
                $type = "BLOB";
            }else{
                print "ERROR: unknown type $type";
            }
            
            my %destination_attribute;
            
            $destination_attribute{"type"} = $type;
            if($this_source_attribute{'optional'} && $this_source_attribute{'optional'} ne "YES"){
                $destination_attribute{"optional"} = 0;
            }else{
                $destination_attribute{"optional"} = 1;
            }
            my $sql_name;
            if(is_reserved_word($attributeName)){
                $destination_attribute{"original_name"} = $attributeName;
                $sql_name =  $attributeName . "_field";
            }else{
                $sql_name = $attributeName;
            }
            $destination_attribute{"sql_field"} = $sql_name;
            $destination_entity{"attributes"}{$attributeName} = \%destination_attribute;
        }
        
        $model{$entityName} = \%destination_entity;
        
        if($source_entity{'relationship'}){
            my %relationships = %{$source_entity{'relationship'}};
            foreach my $relationship_name (sort(keys(%relationships))){
                if(!ref($relationships{$relationship_name})){
                    proccess_relationship(\%relationships, $entityName, $relationships{"name"});
                    last;
                }else{
                    proccess_relationship($relationships{$relationship_name}, $entityName, $relationship_name);
                }
            }
        }
    }
}

sub generate_sql{
    my $outfile = "sql/model.sql";
    if(!$outfile){
        croak "Couldn't find sql_schema_file in config";
    }
    open schemaSQL, ">$outfile";
    foreach my $entity_name(sort(keys(%model))){
        my %entity = %{$model{$entity_name}};
        my %attributes = %{$entity{"attributes"}};
        my @attribute_keys = sort(keys(%attributes));
        
        my $id_field = $config{"primary_keys"}->{$entity_name};
        if(!$id_field){
            $id_field = $entity_name . "_id";
        }
        $model{$entity_name}->{"primary_key"} = $id_field;
        
        print schemaSQL "DROP TABLE $entity_name;\n";
        print schemaSQL "CREATE TABLE $entity_name (\n";
        print schemaSQL "\t$id_field INT AUTO_INCREMENT PRIMARY KEY,\n";
        
        if(is_parent_object($entity_name)){
            print schemaSQL "\tuserid INT,\n";
        }

        
        my @relationship_keys;
        my %relationships;
        if($entity{"relationships"}){
            %relationships = %{$entity{"relationships"}};
            foreach my $r(sort(keys(%relationships))){
                if($relationships{$r}->{"sql_field"}){
                    push @relationship_keys, $r;
                }
            }
        }
        
        for(my $i = 0; $i <= $#attribute_keys; $i++){
            my $attribute_name = $attribute_keys[$i];
            if($attribute_name eq $id_field){
                next;
            }
        
            my %attribute = %{$attributes{$attribute_name}};
            my $sql_line = "\t" . $attribute{"sql_field"} . " " . $attribute{"type"};
            if(!$attribute{"optional"}){
                $sql_line .= "NOT NULL";
            }
                
            if($i < $#attribute_keys || @relationship_keys){
                $sql_line .= ",";
            }
            $sql_line .= "\n";
            print schemaSQL $sql_line;
        }
        
        if($entity{"relationships"}){
            while(my $relationship_name = shift @relationship_keys){
                my %relationship = %{$relationships{$relationship_name}};
                if(! $relationship{"sql_field"}){
                    next;
                }
                
                my $sql_line = "\t" . $relationship{"sql_field"} . " INT";
                
                if($#relationship_keys >= 0){
                    $sql_line .= ",";
                }
                $sql_line .= "\n";
                print schemaSQL $sql_line;
            }
        }
        
        print schemaSQL ");\n\n";
    }
    close schemaSQL;
}

sub print_methods{
    print "Methods:\n";
    foreach my $method(sort(@methods)){
        print "$method => sub {\n
};\n";
    }
}

sub generate_json_model{
    my $outfile = $config{"json_model_file"};
    if(!$outfile){
        croak "Couldn't find json_model_file in config";
    }
    open JSON_OUT, ">$outfile" || croak "$!";
    my $model_json = JSON->new->pretty->encode({"entities" => \%model, database => $config{"database"},
        secret => $config{"secret"} });
    print JSON_OUT $model_json;
    close JSON_OUT;    
}

sub generate_tables{
    my $db = $config{"database"}->{"database"};
    my $dbserver = $config{"database"}->{"server"};
    my $dbuser = $config{"database"}->{"user"};
    my $dbpassword = $config{"database"}->{"password"};
    
    my $dbh = DBI->connect("DBI:mysql:$db:$dbserver", $dbuser, $dbpassword);
    if(!$dbh){
        croak("Failed to connect to database\nNot creating tables\n");
    }
    my @files = qw(system.sql model.sql application.sql);
    foreach my $file(@files){
        my $sql;
        {
            local $/=undef;
            open FILE, "sql/$file" or die "Couldn't open file sql/$file: $!";
            $sql = <FILE>;
            close FILE;
        }
        print $sql;
        my @tables = split(/\;/, $sql);
        foreach my $table(@tables){
            if($table =~ /^\s*drop/ || $table =~ /^\s*DROP/){
                eval { $dbh->do($table) };
            }elsif($table =~ /\w+/){
                $dbh->do($table) || croak "Could not Create Table: $DBI::errstr";
            }
        }
    }
}

read_config(shift @ARGV);
parse_model();
generate_sql();
#print_methods();
generate_json_model();
generate_tables();