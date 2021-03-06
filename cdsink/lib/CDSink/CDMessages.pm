package CDSink::CDMessages;

sub new { bless {}, shift }

sub mark_message_as_read{
    my ($self, $message_id) = @_;
    my $sth = $self->{app}->dbh->prepare("update messages set message_read=1 where message_id like ?");
    $sth->execute($message_id);
}

sub send_user_message($$){
    my ($self, $userid, $message) = @_;
    my $dbh = $self->{app}->dbh;
    my $sth = $dbh->prepare("insert into messages(userid, message, date) values(?, ?, now())");
    if($sth->execute($userid, $message)){
        my $id = $dbh->{'mysql_insertid'};
        return $id;
    }
    return 0;
}

1;
