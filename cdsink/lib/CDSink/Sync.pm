package CDSink::Sync;
use Mojo::Base 'Mojolicious::Controller';


sub deletes_for_user{
    my $self = shift;
    return $self->render(json => {error => "Not Logged In"}, status=>401) unless $self->session('userid');
    
    my $userid = $self->session('userid');
    my $date = $self->param("date");
    my $deletes = $self->object_manager->deletes_for_user($userid, $date);
    
    $self->render(json => $deletes, status=>200);
}

sub changes_for_user{
    my $self = shift;
    return $self->render(json => {error => "Not Logged In"}, status=>401) unless $self->session('userid');
    
    my $userid = $self->session('userid');
    my $date = $self->param("date");
    my $changes = $self->object_manager->changes_for_user($userid, $date);
    $self->render(json => $changes, status=>200);
}

sub log_for_user{
    my $self = shift;
    return $self->render(json => {error => "Not Logged In"}, status=>401) unless $self->session('userid');
    
    my $userid = $self->session('userid');    
    my $date = $self->param("date");
    
    my $deletes = $self->object_manager->deletes_for_user($userid, $date);
    my $changes = $self->object_manager->changes_for_user($userid, $date);
    
    $self->render(json => {deletes => $deletes, changes => $changes }, status=>200);
}

1;
