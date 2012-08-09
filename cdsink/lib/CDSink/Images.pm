package CDSink::Images;
use Mojo::Base 'Mojolicious::Controller';
use Data::UUID;

sub image_upload{
    my $self = shift;
    return $self->render(json => {error => "Not Logged In"}, status=>401) unless $self->session('userid');

    my $image = $self->param('image');
    my $entity = $self->param('entity');
    my $field = $self->param('field');
    my $object_id = $self->param("id");
    my $type = $self->param("type");
    my $userid = $self->session('userid');
    $self->app->log->debug("image upload: entity:$entity field:$field objectID:$object_id userid:$userid type:$type");
    
    if(!$image){
        $self->render(json=>{error => "could not find image"}, status=>400);
    }
    elsif(!$type){
        $self->render(json=>{error => "could not find image type"}, status=>400);
    }
    elsif(!$entity || !$field || !$object_id){
        $self->render(json=>{error => "invalid target object"}, status=>400);
    }
    elsif(!$self->object_manager->object_exists($entity, $object_id)){
        $self->render(json=>{error => "target object does not exist"}, status=>400);
    }
    elsif(!$self->object_manager->is_entity_valid($entity)){
        $self->render(json=>{error => "entity is not valid"}, status=>400);
    }
    elsif(!$self->object_manager->is_attribute_valid($entity, $field)){
        $self->render(json=>{error => "attribute is not valid"}, status=>400);
    }
    
    elsif($self->users->check_authorized($userid, "PUT", $entity, $object_id)){
        my $filename = $self->generate_filename;
        $filename =~ s/[^\w]/a/g;
        if($type eq "image/png"){
            $filename .= ".png";
        }elsif($type eq "image/jpeg"){
            $filename .= ".jpg";
        }
        my $imagedir = $self->config->{"images"}->{"local_path"};
        $image->move_to($imagedir . "/" . $filename);
        my $url =  $self->config->{"images"}->{"url_prefix"};
        if($url !~ /\/$/){
            $url .= "/";
        }
        $url .= "$filename";
        $self->set_url($url, $entity, $object_id, $field);
        $self->render(json=>{url => $url}, status=>201);
    }else{
        $self->render(json=>{error => "Not authorized to GET $entity/$object_id"}, status=>403);
    }
}

sub generate_filename{
    my $ug = new Data::UUID;
    return $ug->create_b64();
}

sub set_url($$$){
    my ($self, $url, $entity, $object_id, $field) = @_;
    my $id_field = $self->object_manager->primaryKeyForEntity( $entity );

    my $sth = $self->dbh->prepare("UPDATE $entity SET $field=? where $id_field=?");
    $sth->execute($url, $object_id);
    $self->object_manager->update_modification_table($entity, $object_id, $self->session("userid"));
}

1;
