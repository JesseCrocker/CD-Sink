package CDSink::CDNotification;
use Net::APNS::Persistent;
use Data::Dumper;

sub new{
    my $class = shift;
    my $app = shift;

    my $cert = $app->config->{"apns"}->{"certificate"};
    my $key = $app->config->{"apns"}->{"privatekey"};
    my $sandbox = $app->config->{"apns"}->{"sandbox"};
    unless(-e $cert){
	$app->log->error("could not find cert $cert");
	return;
    }
    unless(-e $key){
	$app->log->error("could not find key file $key");
	return;
    }
    $app->log->debug("connecting to apns with Net::APNS::Persistent");
    if($sandbox){
	$app->log->debug("connecting to sandbox server");
    }
    $app->log->debug("cert file:$cert");
    $app->log->debug("key file:$key");
    my $apns = Net::APNS::Persistent->new({
    sandbox => $sandbox,
    cert    => $cert,
    key     => $key,
					  });
    my $self = {
	app => $app,
	apns => $apns
    };
    bless $self, $class;

    $self->send_alert_to_user(1, "working?");
    return $self;
}

sub send_alert_to_user{
    my ($self, $userid, $alert) = @_;
    $self->send_notification_to_user($userid, {aps => {alert => $alert, sound => 'default'}});
}

sub send_notification_to_user{
    my ($self, $userid, $payload) = @_;
    my $dbh = $self->{app}->dbh;
    my $sth = $dbh->prepare("SELECT deviceToken FROM pushDevice WHERE userid=?");
    $sth->execute($userid);
    my @tokens = @{$sth->fetchall_arrayref([0])};
    foreach my $t(@tokens){
	my $toke = $t->[0];
	$self->{app}->log->debug("sending push to $toke");
	$self->{app}->log->debug(Dumper($payload));
	$self->{apns}->queue_notification($toke, $payload);
    }
    $self->{apns}->send_queue;
}

1;
