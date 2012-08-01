package CDSink::CDObjects;
#model class, doesnt wory about user authorization, the controller, CDSink::Object handles that
use Data::Dumper;

sub new { bless {}, shift }

sub inverse_for_relationship($){
    my ($self, $relationship) = @_;
    return $self->{"CDconfig"}->{"entities"}->{ $relationship->{"type"} }->{"relationships"}->{$relationship->{"inverse_name"}};
}

sub primaryKeyForEntity($){
    my ($self, $entity) = @_;
    my $key = $self->{"CDconfig"}->{"entities"}->{$entity}->{"primary_key"};
    return $key;
}

sub object_exists($$){
    #return userid
    #0 means doesnt exist
    #-1 bad id
    my ($self, $entity, $object_id) = @_;
    return -1 unless $observation_id;
    my $id_field = $self->primaryKeyForEntity($entity);
    my $sth = $self->dbh->prepare("select $id_field from $entity where $id_field like ?");
    if($sth->exectute($object_id)){
        my ($id) = $sth->fetchrow_array;
        return 1 if $id;
    }
    return 0;
}

sub get_object($$$){
    #return a hashref
    my ($self, $entity, $object_id, $ignore_relationship) = @_;

    my $id_field = $self->primaryKeyForEntity($entity);

    #print "get_object of type $entity with $id_field=$object_id\n";
    my %entity_config = %{$self->{"CDconfig"}->{"entities"}->{$entity}};
    if(!%entity_config){
        $self->log->error("could not find config for entity $entity");
        return -1;
    }
    
    my %attributes = %{$entity_config{'attributes'}};
    
    my @input_fields = sort(keys %attributes);
    my @sql_fields;
    foreach my $field(@input_fields){
        push(@sql_fields, $entity_config{'attributes'}->{$field}->{"sql_field"});
    }
    
    if($entity_config{"parent_object"}){
        push(@sql_fields, "userid");
        push(@insert_values, $userid)
    }
    
    my $sql = "SELECT * FROM $entity WHERE $id_field=?";
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute($object_id);
    
    my %object = %{$sth->fetchrow_hashref};
        
    my %relationships = %{$entity_config{'relationships'}};
    foreach my $r_name(keys(%relationships)){
        my %r = %{$relationships{$r_name}};
        my $sql_field = $r{"sql_field"};

        if($ignore_relationship && $ignore_relationship eq $r_name){
            if($sql_field){
                delete $object{$sql_field};
            }
            next;
        }
        
        my %inverse = %{$self->inverse_for_relationship(\%r)};
        if(!%inverse){
            print "ERROR: could not find inverse for relationship $entity:$r_name\n";
        }
        
        if($r{"to_many"}){
            #fetch all ids where the inverse field points to this object
            #iterate through ids, call get_object on each one, excluding the inverse
            my $inverse_field = $inverse{"sql_field"};
            my $target_id_field = $self->primaryKeyForEntity($r{"type"});
            if($inverse_field){
                my $sql = "SELECT $target_id_field FROM " . $r{"type"} . " WHERE $inverse_field=?";
                # print "$sql\n";
                my $sth = $self->{dbh}->prepare($sql);
                $sth->execute($object_id);
                my @ids_to_fetch = @{$sth->fetchall_arrayref([0])};
                my @objects_for_relationship;
                foreach my $t(@ids_to_fetch){
                   push @objects_for_relationship, $self->get_object($r{"type"}, $t->[0], $inverse{"name"});
                }
                $object{$r_name} = \@objects_for_relationship;
            }
        }else{#to one
            if($object{$sql_field}){
                my $id = $object{$sql_field};
                delete $object{$sql_field};
                $object{$r_name} = $self->get_object( $r{"type"}, $id, $inverse{"name"} );
            }
        }
    }
    
    return \%object;
}

sub post_object($$){
    #should return id for new object, or -1 if insert failed
    my ($self, $entity, $data, $userid) = @_;
    my %object = %{$data};
    #    print "post_object of type $entity\n";
    my %entity_config = %{$self->{"CDconfig"}->{"entities"}->{$entity}};
    if(!%entity_config){
        $self->log->error("could not find config for entity $entity");
        return -1;
    }
    
    my %attributes = %{$entity_config{'attributes'}};

    my @input_fields = sort(keys %attributes);
    my @sql_fields;
    foreach my $field(@input_fields){
        push(@sql_fields, $entity_config{'attributes'}->{$field}->{"sql_field"});
    }

    my @insert_values = @object{@input_fields};
    
    if($entity_config{"parent_object"}){
        push(@sql_fields, "userid");
        push(@insert_values, $userid)
    }
    
    my $field_placeholders = join ", ", map {'?'} @sql_fields;

    my $sth = $self->{dbh}->prepare("insert into $entity(" . join(",", @sql_fields) . ") values($field_placeholders)");
    $sth->execute(@insert_values);
    my $insert_id = $self->{dbh}->{'mysql_insertid'};
    if(!$insert_id){
        return -1;
    }
    
    my @relationship_fields;
    my @relationship_ids;
    
    my %relationships = %{$entity_config{'relationships'}};
    foreach my $r_name(keys(%relationships)){
        my %r = %{$relationships{$r_name}};
        my %inverse = %{$self->inverse_for_relationship(\%r)};
        if(!%inverse){
            print "ERROR: could not find inverse for relationship $entity:$r_name\n";
        }
        if($r{"sql_field"} && $object{$r{"sql_field"}}){
            #a target id for this relationship is already set, so all we need to do to proccess it is insert it
            push @relationship_fields, $r{"sql_field"};
            push @relationship_ids, $object{$r{"sql_field"}};
        }
        
        if($r{"to_many"}){
            # print "proccessing to-many relationship: $r_name\n";
            if($object{$r_name}){
                my @all_o = @{$object{$r_name}};
                foreach my $o (@all_o){
                    if($inverse{"sql_field"}){
                        $o->{$inverse{"sql_field"}} = $insert_id;
                    }
                    $self->post_object($r{'type'}, $o, $userid);
                }
            }
        }else{
            #print "proccessing singular relationship: $r_name\n";
            if($object{$r_name}){
                my $o = $object{$r_name};
                if($inverse{"sql_field"}){
                    $o->{$inverse{"sql_field"}} = $insert_id;
                }
                my $r_insert_id = $self->post_object($r{'type'}, $o, $userid);
                if($r_insert_id){
                    push @relationship_fields, $r{"sql_field"};
                    push @relationship_ids, $r_insert_id;
                }
            }
        }
    }
    
    if(@relationship_fields){
        my $field_placeholders = join ", ", map {"$_=?"} @relationship_fields;
        my $sql = "update $entity SET $field_placeholders where " . $self->primaryKeyForEntity($entity) . "=$insert_id";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute(@relationship_ids);
    }
    
    $self->update_modification_table($entity, $insert_id, $userid);
    
    return $insert_id;
}



sub update_object($$){
    my ($self, $entity, $object_id) = @_;

}

sub delete_object($$$){
    #return 1 if success, 0 if object not found

    my ($self, $entity, $object_id, $userid) = @_;
        
    my $id_field = $self->primaryKeyForEntity($entity);
    
    #print "delete_object of type $entity with $id_field=$object_id\n";
    my %entity_config = %{$self->{"CDconfig"}->{"entities"}->{$entity}};
    if(!%entity_config){
        $self->log->error("could not find config for entity $entity");
        return -1;
    }
    
    my %attributes = %{$entity_config{'attributes'}};

    #fetch a copy of object to use for relationship proccessing
    my $sql = "SELECT * FROM $entity WHERE $id_field=?";
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute($object_id);
    my %object = %{$sth->fetchrow_hashref};
    if(!%object){
        return 0;
    }
    
    #delete from db
    $sql = "DELETE FROM $entity WHERE $id_field=?";
    $sth = $self->{dbh}->prepare($sql);
    $sth->execute($object_id);
    
    #make entry in deletions table
    $self->add_to_deletion_table($entity, $object_id, $userid);
    
    #go through relationships
    #if there is a cascade, nullify the inverse before cascading
    #if there is a nullify, the nullify it
    my %relationships = %{$entity_config{'relationships'}};
    foreach my $r_name(keys(%relationships)){
        my %r = %{$relationships{$r_name}};
        my %inverse = %{$self->inverse_for_relationship(\%r)};
        if($r{"to_many"}){
            my $inverse_field = $inverse{"sql_field"};
            my $target_id_field = $self->primaryKeyForEntity( $r{"type"} );
            if($inverse_field){
                my $sql = "SELECT $target_id_field FROM $r{'type'} WHERE $inverse_field=?";
                my $sth = $self->{dbh}->prepare($sql);
                $sth->execute($object_id);
                my @ids_to_delete = @{$sth->fetchall_arrayref([0])};
                foreach my $t(@ids_to_delete){
                    my $id = $t->[0];
                    if(!$id){
                        next;
                    }
                    if($r{'delete_rule'} eq "Cascade"){
                        $self->nullify_relationship_target(\%r, $id);
                        $self->delete_object($r{"type"}, $id, $userid);
                    }elsif($r{'delete_rule'} eq "Nullify"){
                        $self->nullify_relationship_target(\%r, $id);
                    }elsif($r{'delete_rule'} eq "Deny"){
                        #not going to deal with this
                    }
                }
            }
        }else{
            if(!$object{$r{"sql_field"}}){
                next;
            }
            
            if($r{'delete_rule'} eq "Cascade"){
                $self->nullify_relationship_target(\%r, $object{$r{"sql_field"}});
                $self->delete_object($r{"type"}, $object{$r{"sql_field"}}, $userid);
            }elsif($r{'delete_rule'} eq "Nullify"){
                $self->nullify_relationship_target(\%r, $object{$r{"sql_field"}});
            }elsif($r{'delete_rule'} eq "Deny"){
                #not going to deal with this
            }
        }
    }
    
    return 1;
}

sub nullify_relationship_target($$){
    my ($self, $relationship, $target_id) = @_;
    my %inverse = %{$self->inverse_for_relationship($relationship)};
    my $id_field = $self->primaryKeyForEntity( $inverse{"type"} );

    if($inverse{'sql_field'}){
        my $sql = "UPDATE $relationship->{'type'} SET $inverse{'sql_field'}=0 where $id_field=?";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute($target_id);
    }
}

sub add_to_deletion_table($$$){
    my ($self, $entity, $object_id, $userid) = @_;
    my $sth = $self->{dbh}->prepare("INSERT INTO deletions (entity, object_id, userid) values(?, ?, ?)");
    $sth->execute($entity, $object_id, $userid);

    #clear out all modification logs on deleted objects
    $sth = $self->{dbh}->prepare("DELETE FROM modifications WHERE entity=? AND object_id=?");
    $sth->execute($entity, $object_id);
}

sub update_modification_table($$$){
    my ($self, $entity, $object_id, $userid) = @_;
    
    #clear out previous logs for this object
    $sth = $self->{dbh}->prepare("DELETE FROM modifications WHERE entity=? AND object_id=?");
    $sth->execute($entity, $object_id);
    
    $sth = $self->{dbh}->prepare("INSERT INTO modifications (entity, object_id, userid) values(?, ?, ?)");
    $sth->execute($entity, $object_id, $userid);
}

sub changes_for_user($$){
    my ($self, $userid, $date) = @_;
    
    my $sql = "SELECT entity, object_id, date FROM modifications WHERE userid=?";
    my $sth;
    if($date){
        $sql .= " and date > ?";
        $sth = $self->{dbh}->prepare($sql);
        $sth->execute($userid, $date);
    }else{
        $sth = $self->{dbh}->prepare($sql);
        $sth->execute($userid);
    }
    
    my @changes;
    while(my $row = $sth->fetchrow_hashref){
        push @changes, $row;
    }
    
    return \@changes;
}

sub deletes_for_user($$){
    my ($self, $userid, $date) = @_;
    
    my $sql = "SELECT entity, object_id, date FROM deletions WHERE userid=?";
    my $sth;
    if($date){
        $sql .= " and date > ?";
        $sth = $self->{dbh}->prepare($sql);
        $sth->execute($userid, $date);
    }else{
        $sth = $self->{dbh}->prepare($sql);
        $sth->execute($userid);
    }
    
    my @deletes;
    while(my $row = $sth->fetchrow_hashref){
        push @deletes, $row;
    }

    return \@deletes;
}

1;


