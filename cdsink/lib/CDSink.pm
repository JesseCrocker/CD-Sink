package CDSink;
use Mojo::Base 'Mojolicious';
use DBI;
use JSON;
use CDSink::CDUser;
use CDSink::CDMessages;
use CDSink::CDObjects;
use Data::Dumper;

# This method will run once at server start
sub startup {
    my $self = shift;
    
    my $config = $self->load_config;
    $self->helper(CDconfig => sub { return $config });
    #$self->log->debug("config: " . Dumper($config));
    $self->secret($config->{"secret"});
    
    my $dbh = $self->setup_database;
    $self->helper(dbh => sub { return $dbh });
    
    my $users = CDSink::CDUser->new;
    $users->{dbh} = $dbh;
    $users->{"CDconfig"} = $config;
    $self->helper(users => sub { return $users });

    my $messages = CDSink::CDMessages->new;
    $messages->{dbh} = $dbh;
    $self->helper(messages => sub { return $messages });

    my $object_manager = CDSink::CDObjects->new;
    $object_manager->{"CDconfig"} = $config;
    $object_manager->{"dbh"} = $dbh;
    $self->helper(object_manager => sub { return $object_manager });

    $self->setup_basic_routes;
    $self->setup_user_routes;
    $self->setup_object_routes;
    $self->setup_message_routes;
    $self->setup_rating_routes;
    $self->setup_sync_routes;
}

sub load_config{
    my $self = shift;
    my $filepath = "../model.json";
    if(!$filepath){
        croak("No config file");
    }
    
    my $json;
    {
        local $/=undef;
        open FILE, $filepath or die "Couldn't open file $filepath: $!";
        $json = <FILE>;
        close FILE;
    }
    return decode_json $json;
}

sub setup_database{
    my $self = shift;
    my $db = $self->CDconfig->{"database"}->{"database"};
    my $dbserver = $self->CDconfig->{"database"}->{"server"};
    my $dbuser = $self->CDconfig->{"database"}->{"user"};
    my $dbpassword = $self->CDconfig->{"database"}->{"password"};
    
    $self->log->debug("Connect to database: $dbuser@" . "$dbserver:$db with password $dbpassword");
    my $dbh = DBI->connect("DBI:mysql:$db:$dbserver", $dbuser, $dbpassword);
    if(!$dbh){
        $self->log->error("Failed to connect to database");
        exit;
    }
    return $dbh;
}

#setup routes
sub setup_basic_routes{
    my $self = shift;
    my $r = $self->routes;
    $r->get("/" =>sub{
        my $self = shift;
        $self->render(json => {message => "CD Sink version 1.0"}, status=>200);
    });
}

sub setup_object_routes{
    my $self = shift;
    
    $self->log->debug("setup_object_routes");
    my $r = $self->routes;
    my %entities = %{$self->CDconfig->{entities}};
    
    foreach my $entity_name(keys(%entities)){
        my %entity = %{$entities{$entity_name}};
        if($entity{"parent_object"}){
            $self->log->debug("Setting up parent object routes for entity $entity_name");
            $r->get("/$entity_name")->to(controller =>'Objects', action=>'objects_list', entity=>$entity_name);
            $r->post("/$entity_name")->to(controller =>'Objects', action=>'post_object', entity=>$entity_name);
            $r->get("/$entity_name/:object_id")->to(controller =>'Objects', action=>'get_object', entity=>$entity_name);
            $r->put("/$entity_name/:object_id")->to(controller =>'Objects', action=>'update_object', entity=>$entity_name);
            $r->delete("/$entity_name/:object_id")->to(controller =>'Objects', action=>'delete_object', entity=>$entity_name);
            
        }else{
            $self->log->debug("Setting up non-parent routes for entity $entity_name");
        }
    }
    #print Dumper($r);
}

sub setup_user_routes{
    my $self = shift;
    my $r = $self->routes;
    $r->get('/user')->to(controller => "Login", action=>"get_current_user_info");
    $r->get('/user/:userid')->to(controller => "Login", action=>"get_user_info");
    $r->post('/user')->to(controller => "Login", action=>"new_user");
    $r->put('/user')->to(controller => "Login", action=>"new_user");
    $r->any('/login')->to(controller => "Login", action=>"login");
    $r->any('/logout')->to(controller => "Login", action=>"logout");
    $r->delete('/user')->to(controller => "Login", action=>"delete_user");
}

sub setup_sync_routes{
    my $self = shift;
    my $r = $self->routes;
    $r->get("/deletes")->to(controller=>"Sync", action=>"deletes_for_user");
    $r->get("/log")->to(controller=>"Sync", action=>"log_for_user");
    $r->get("/changes")->to(controller=>"Sync", action=>"changes_for_user");
}

sub setup_message_routes{
    
}

sub setup_rating_routes{
    
}

1;
