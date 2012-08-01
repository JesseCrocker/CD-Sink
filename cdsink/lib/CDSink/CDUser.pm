package CDSink::CDUser;
use strict;
use warnings;
use Authen::Passphrase::BlowfishCrypt;

sub new { bless {}, shift }


sub check_login($$){
    #return userid if succsesful, 0, if password is incorrect, -1 if email addr is incorrect
    my ($self, $username, $password) = @_;
    my $sth = $self->{dbh}->prepare("select userid from users where email like ?");
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
    my $sth = $self->{dbh}->prepare("select password,salt from users where userid like ?");
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
    my $sth = $self->{dbh}->prepare("select userid from users where email like ?");
    $sth->execute($email);
    my ($result) = $sth->fetchrow_array;
    if($result){
        return -1;
    }
    
    my $hashed_password = $self->hash_new_password($password);
        
    $sth = $self->{dbh}->prepare("insert into users (email, password, salt) values(?, ?, ?)");
    if($sth->execute($email, $hashed_password->hash_base64, $hashed_password->salt_base64)){
        my $id = $self->{dbh}->{'mysql_insertid'};
        #$self->user_message($id, "Welcome To Avalanche Lab.");
        return $id;
    }
    return 0;
}

sub update_user{
    
}

sub check_authorized($$$$){
    #is the user allowed to modify this observation/comment/whattever
    #return 1 if allowed, 0 if not allowed, -1 if object does not exist
    my ($self, $userid, $method, $entity_name, $object_id) = @_;
    my %entity = %{$self->{"CDconfig"}->{"entities"}->{$entity_name}};
    my $id_field = $entity{"primary_key"};
    
    if($method eq "POST"){
        if($userid){
            return 1;
        }else{
            return 0;
        }
    }elsif($method eq "PUT" || $method eq "DELETE"){
        #object can only be updated or deleted by its owner
        my $sth = $self->{dbh}->prepare("select userid from $entity_name where $id_field like ?");
        $sth->execute($object_id);
        my ($object_userid) = $sth->fetchrow_array;
        if($object_userid && $userid == $object_userid){
            return 1;
        }
        return 0;
    }elsif($method eq "GET"){
        if($entity{"attributes"}->{"private"}){
            #does it have a private field
            my $sth = $self->{dbh}->prepare("select private,userid from $entity_name where $id_field like ?");
            $sth->execute($object_id);
            my ($private, $object_userid) = $sth->fetchrow_array;
            if($private){
                if($userid == $object_userid){
                    return 1;
                }
                return 0;
            }
            #not private
            return 1;            
        }else{
            #if no private field, then assume private
            my $sth = $self->{dbh}->prepare("select userid from $entity_name where $id_field like ?");
            $sth->execute($object_id);
            my ($object_userid) = $sth->fetchrow_array;
            if($userid == $object_userid){
                return 1;
            }
            return 0;
        }
    }else{
        $self->log->error("unknow method in check_authorized: $method");
    }
    return 0;
}


sub delete_user($){
    my ($self, $userid) = @_;
    my $sth = $self->{dbh}->prepare("DELETE from messages where userid like ?");
    $sth->execute($userid);
    $sth = $self->{dbh}->prepare("DELETE from users where userid like ?");
    $sth->execute($userid);
}

sub user_info($$){
    my ($self, $userid, $me) = @_;
    my $sth;
    if($me){
        $sth = $self->{dbh}->prepare('select userid, email, display_name, image_url, orginization, profile, push_messages, rating from users where userid like ?');
    }else{
        $sth = $self->{dbh}->prepare("select userid, email, display_name, image_url, orginization, profile, rating from users where userid like ?");
    }
    $sth->execute($userid);
    return $sth->fetchrow_hashref;
}


1;
