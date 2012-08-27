package CDSink::CDUser;
use strict;
use warnings;
use Authen::Passphrase::BlowfishCrypt;

sub new { bless {}, shift }


sub check_login($$){
    #return userid if succsesful, 0, if password is incorrect, -1 if email addr is incorrect
    my ($self, $username, $password) = @_;
    my $sth = $self->{app}->dbh->prepare("select userid from users where username like ?");
    $sth->execute($username);
    my ($userid) = $sth->fetchrow_array;
    if(!$userid){
        return -1; #incorrect username
    }
    
    if($self->password_matches($userid, $password)){
        return $userid;
    }
    return 0;#incorrect password
}

sub hash_new_password($){
    my ($self, $password) = @_;
    
    my $ppr = Authen::Passphrase::BlowfishCrypt->new(cost => 8,
    salt_random => 1,
    passphrase => $password);
    
    return $ppr;
}

sub password_matches($){
    my ($self, $userid, $password) = @_;
    my $sth = $self->{app}->dbh->prepare("select password,salt from users where userid like ?");
    $sth->execute($userid);
    my ($hash, $salt) = $sth->fetchrow_array;

    my $ppr = Authen::Passphrase::BlowfishCrypt->new(
    cost => 8,
    salt_base64 => $salt,
    hash_base64 => $hash);
    
    if($ppr->match($password)){
        return 1;
    }
    return 0;
}

sub new_user($$){
    my ($self, $email, $password) = @_;
    my $sth = $self->{app}->dbh->prepare("select userid from users where username like ?");
    $sth->execute($email);
    my ($result) = $sth->fetchrow_array;
    if($result){
        return -1;
    }
    
    my $hashed_password = $self->hash_new_password($password);
        
    my $dbh = $self->{app}->dbh;
    $sth = $dbh->prepare("insert into users (username, password, salt) values(?, ?, ?)");
    if($sth->execute($email, $hashed_password->hash_base64, $hashed_password->salt_base64)){
        my $id = $dbh->{'mysql_insertid'};
        return $id;
    }
    return 0;
}

sub change_password($$){
    my ($self, $userid, $password) = @_;
    if(!$password){
        return;
    }
    my $hash = $self->hash_new_password($password);
    my $sth = $self->{app}->dbh->prepare("UPDATE users set password=?, salt=? where userid=?");
    $sth->execute($hash->hash_base64, $hash->salt_base64, $userid);
}

sub check_authorized($$$$){
    #is the user allowed to modify this observation/comment/whattever
    #return 1 if allowed, 0 if not allowed, -1 if object does not exist
    my ($self, $userid, $method, $entity_name, $object_id) = @_;
    my %entity = %{$self->{model}->{$entity_name}};
    my $id_field = $entity{"primary_key"};

    if($method eq "POST"){
        #all users alowed to post
        if($userid){
            return 1;
        }else{
            return 0;
        }
    }
    #not posting, get/modify existing object
    my $object_owner_id = $self->{app}->object_manager->object_exists($entity_name, $object_id);
    if($object_owner_id <= 0){
	#object does not exist
        return -1;
    }
    
    if($method eq "PUT" || $method eq "DELETE"){
        #object can only be updated or deleted by its owner
        if($userid == $object_owner_id){
            return 1;
        }
        return 0;
    }elsif($method eq "GET"){
        if ( grep { $_ eq $entity_name} @{ $self->{app}->config->{"public_entities"} }){
            return 1;
        }
        
        if($entity{"attributes"}->{"private"}){
            #does it have a private field
            my $sth = $self->{app}->dbh->prepare("select private from $entity_name where $id_field like ?");
            $sth->execute($object_id);
            my ($private) = $sth->fetchrow_array;
            if($private){
                return 0;
            }else{ #not private
                return 1;
            }
        }
        
        if($userid && $userid == $object_owner_id){
            return 1;
        }

        
        return 0;
    }else{
        $self->log->error("unknow method in check_authorized: $method");
    }
    return 0;
}


sub delete_user($){
    my ($self, $userid) = @_;
    my $dbh = $self->{app}->dbh;
    my $sth = $dbh->prepare("DELETE from messages where userid like ?");
    $sth->execute($userid);
    $sth = $dbh->prepare("DELETE from users where userid like ?");
    $sth->execute($userid);
}

sub login_info($){
    my ($self, $userid) = @_;
    my $sth = $self->{app}->dbh->prepare('select userid, username, push_messages from users where userid like ?');
    $sth->execute($userid);
    return $sth->fetchrow_hashref;
}

1;
