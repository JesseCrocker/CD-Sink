package CDSink::Login;
use Mojo::Base 'Mojolicious::Controller';

sub login {
    my $self = shift;
    my $email = $self->param('email') || '';
    my $password = $self->param('password') || '';
    my $userid = $self->users->check_login($email, $password);
    if($userid > 0){
        $self->session(expires => time + (60 * 60 * 24));
        $self->session(userid => $userid);
        $self->render(json =>{userid => $userid}, status=>202);
    }elsif($userid == 0){#login failed
        $self->render(json=>{error => "Invalid Password"}, status=>401);
    }else{
        $self->render(json=>{error => "Email Address not found"}, status=>401);
    }
}

sub logout {
    my $self = shift;
    return $self->render(json=>{error => "Not Logged In"}, status=>400) unless $self->session('userid');
    $self->session(expires => 1);
    $self->render(json => {message => "Logout Successful"}, status=>200);
    
}

sub new_user {
    my $self = shift;
    return $self->render(json=>{error => "Already Logged In"}, status=>400) if $self->session('userid');

    my $email = $self->param('email') || '';
    my $password = $self->param('password') || '';
    if(!$email){
        $self->render(json=>{error => "Invalid Email Address"}, status=>400);
    }elsif(!$password){
        $self->render(json=>{error => "Invalid Password"}, status=>400);
    }else{
        my $userid = $ self->users->new_user($email, $password);
        if($userid == -1){
            $self->render(json => {error => "Email address is already registered"}, status=>403);
        }elsif($userid == 0){
            $self->render(json => {error => "Error creating account"}, status=>400);
        }else{
            $self->session(expires => time + (60 * 60 * 24));
            $self->session(userid => $userid);
            $self->render(json => {userid => $userid}, status=>201);
        }
    }
}

sub delete_user {
    my $self = shift;
    return $self->render(json => {error => "Not Logged In"}, status=>401) unless $self->session('userid');
    my $userid = $self->session('userid');
    $self->users->delete_user($userid);
    
    $self->render(json=>{message=>"User deleted"}, status=>200);
}

sub get_login_info {
    my $self = shift;
    return $self->render(json => {error => "Not Logged In"}, status=>401) unless $self->session('userid');
    
    my $userid = $self->session('userid');
    my $userinfo = $self->users->login_info($userid);
    $self->render(json => $userinfo, status=>200);
}

sub update_user{
    my $self = shift;
    return $self->render(json => {error => "Not Logged In"}, status=>401) unless $self->session('userid');
    
    my $userid = $self->session('userid');
    my $password = $self->param('password');
    my $push = $self->param('push');
    if($password){
        $self->users->change_password($userid, $password);
        $self->render(json=>{message=>"password changed"}, status=>200);
    }
    $self->render(json=>{message=>"nothing changed"}, status=>200);
}

1;
