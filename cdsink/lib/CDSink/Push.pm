package CDSink::Push;
use Mojo::Base 'Mojolicious::Controller';

sub set_device_token{
    my $self = shift;
    return $self->render(json => {error => "Not Logged In"}, status=>401) unless $self->session('userid');

    my $udid = $self->param("udid");
    my $token = $self->param("deviceToken");
    my $userid = $self->session("userid");

    my $dbh = $self->app->dbh;
    my $sth = $dbh->prepare("DELETE FROM pushDevice WHERE userid=? AND udid=?");
    $sth->execute($userid, $udid);

    $sth = $dbh->prepare("INSERT INTO pushDevice (userid, udid, deviceToken) values(?, ?, ?)");
    if($sth->execute($userid, $udid, $token)){
	$self->render(json => {}, status=>202); 
    }else{
	$self->render(json => {error => "Error setting token"}, status=>401);
    }
}

1;
