package CDSink::Objects;
use Mojo::Base 'Mojolicious::Controller';
#this is the controller
#it checks if a user is authorzied with CDUser->check_authorized($userid, $method, $entity, $object_id)
#then makes calls to the model CDSink::CDObjects

sub objects_list{
    my $self = shift;
    my $userid = $self->session('userid');
    my $entity = $self->param('entity');
    my $id_field = $self->app->object_manager->primaryKeyForEntity( $entity );
    my $sql = "SELECT $id_field FROM $entity WHERE userid=?";
    $self->app->log->debug("$sql");
    my $sth = $self->app->dbh->prepare($sql);
    $sth->execute($userid);
    my @results = @{$sth->fetchall_arrayref};
    my @out = map {${$_}[0] } @results;
    $self->render(json => \@out, status=>200);
}

sub post_object{
    my $self = shift;
    my $userid = $self->session('userid');
    my $entity = $self->param('entity');
    
    if(!$userid){
        $self->render(json=>{error => "Not logged in"}, status=>403);
    }
    
    if($self->users->check_authorized($userid, "POST", $entity, "")){
        $self->app->log->debug($self->req->body);
        my $object = Mojo::JSON->decode( $self->req->body);
        my $insert_id = $self->object_manager->post_object($entity, $object, $userid);
        if($insert_id > 0){
            my $id_field = $self->object_manager->primaryKeyForEntity($entity);
            $self->render(json=>{$entity => {$id_field => $insert_id}}, status=>201);
        }else{
            $self->render(json=>{error => "error inserting $entity"}, status=>500);
        }
    }else{
        $self->render(json=>{error => "Not authorized to POST $entity"}, status=>403);
    }
}

sub get_object{
    my $self = shift;
    my $userid = $self->session('userid');
    my $entity = $self->param('entity');
    my $object_id = $self->param('object_id');
    if(!$userid){
        $self->render(json=>{error => "Not logged in"}, status=>403);
    }
    
    if(!$object_id){
        $self->render(json=>{error => "No object specified"}, status=>400);
    }
    
    if($self->users->check_authorized($userid, "GET", $entity, $object_id)){
        my $object = $self->object_manager->get_object($entity, $object_id);
        $self->render(json=>$object, status=>200);
    }else{
        $self->render(json=>{error => "Not authorized to GET $entity/$object_id"}, status=>403);
    }

}

sub update_object{
    my $self = shift;
    my $userid = $self->session('userid');
    my $entity = $self->param('entity');
    my $object_id = $self->param('object_id');
    if(!$userid){
        $self->render(json=>{error => "Not logged in"}, status=>403);
    }
    
    if(!$object_id){
        $self->render(json=>{error => "No object specified"}, status=>400);
    }
    
    if(!$self->object_manager->object_exists($entity, $object_id)){
        $self->render(json=>{error => "Object does not exist"}, status=>400);
    }
    
    if($self->users->check_authorized($userid, "PUT", $entity, $object_id)){
        my $object = Mojo::JSON->decode( $self->req->body);
        $self->object_manager->update_object($entity, $object_id, $object, $userid);
        $self->render(json=>{message => "Object updated"}, status=>202);
    }else{
        $self->render(json=>{error => "Not authorized to PUT $entity/$object_id"}, status=>403);
    }
}

sub delete_object{
    my $self = shift;
    my $userid = $self->session('userid');
    my $entity = $self->param('entity');
    my $object_id = $self->param('object_id');
    if(!$userid){
        $self->render(json=>{error => "Not logged in"}, status=>403);
    }
    
    if(!$object_id){
        $self->render(json=>{error => "No object specified"}, status=>400);
    }
    
    if($self->users->check_authorized($userid, "DELETE", $entity, $object_id)){
        $self->app->log->debug("deleting object");
        if($self->object_manager->delete_object($entity, $object_id, $userid)){
            $self->render(json =>{}, status=>204);
        }else{#delete found, object not found
            $self->render(json=>{error => "Object not found"}, status=>404);
        }

    }else{
        $self->render(json=>{error => "Not authorized to DELETE $entity/$object_id"}, status=>403);
    }

}



1;
