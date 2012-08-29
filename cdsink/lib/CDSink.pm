package CDSink;
use Mojo::Base 'Mojolicious';
use DBI;
use JSON;
use CDSink::CDUser;
use CDSink::CDMessages;
use CDSink::CDObjects;
use CDSink::CDNotification;
use Data::Dumper;
use Mojo::Loader;
use Mojolicious::Plugin::Database;

# This method will run once at server start
sub startup {
    my $self = shift;
    
    $self->load_config;
    $self->secret($self->config->{"secret"});
    
#    $self->helper(dbh => sub { return $self->database_connection });
    $self->setup_database_connection;

    my $users = CDSink::CDUser->new;
    $users->{model} = $self->model;
    $users->{app} = $self->app;
    $self->helper(users => sub { return $users });

    my $messages = CDSink::CDMessages->new;
    $messages->{app} = $self->app;
    $self->helper(messages => sub { return $messages });

    my $object_manager = CDSink::CDObjects->new;
    $object_manager->{app} = $self->app;
    $object_manager->{model} = $self->model;
    $self->helper(object_manager => sub { return $object_manager });

    $self->start_apns;

    $self->setup_basic_routes;
    $self->setup_user_routes;
    $self->setup_object_routes;
    $self->setup_sync_routes;
    $self->setup_image_routes;
    $self->load_app_helpers;
    $self->load_app_controllers;

}

sub load_config{
    my $self = shift;
    my $filepath = "../config.json";
    
    my $config = $self->plugin('JSONConfig' => {file => $filepath});
    
    my $modelFile = "../model.json";
    my $json;
    {
        local $/=undef;
        open FILE, $modelFile or die "Couldn't open file $modelFile: $!";
        $json = <FILE>;
        close FILE;
    }
    my $model = decode_json $json;
    $self->helper(model => sub { return $model });
}

sub setup_database_connection{
    my $self = shift;
    my $db = $self->config->{"database"}->{"database"};
    my $dbserver = $self->config->{"database"}->{"server"};
    my $dbuser = $self->config->{"database"}->{"user"};
    my $dbpassword = $self->config->{"database"}->{"password"};

    $self->log->debug("Setting up database connection: $dbuser@" . "$dbserver:$db with password $dbpassword");

    $self->plugin('database', { 
            dsn      => "DBI:mysql:$db:$dbserver",
            username => $dbuser,
            password => $dbpassword,
            options  => {timezone => "UTC"},
            helper   => 'dbh',
		  });
}

sub database_connection{
#not used currently, using database plugin instead
    my $self = shift;
    my $db = $self->config->{"database"}->{"database"};
    my $dbserver = $self->config->{"database"}->{"server"};
    my $dbuser = $self->config->{"database"}->{"user"};
    my $dbpassword = $self->config->{"database"}->{"password"};
    
    $self->log->debug("Connect to database: $dbuser@" . "$dbserver:$db with password $dbpassword");
    my $dbh = DBI->connect("DBI:mysql:$db:$dbserver", $dbuser, $dbpassword);
    if(!$dbh){
        $self->log->error("Failed to connect to database");
        exit;
    }
    #$dbh->{TraceLevel} = "2|SQL";
    return $dbh;
}

sub load_app_helpers{
    my $self = shift;
    
    $self->log->debug("Loading app helpers from class " . $self->config->{helpers});
    
    my $loader = Mojo::Loader->new;
    for my $class (@{$loader->search($self->config->{helpers})}) {
        $self->log->debug("loading class $class");
        
        my $exception = $loader->load($class);
        if($exception){
            $self->log->error($exception);
        }
        
        my $h = $class->new;
        $h->setup($self->app);
    }
}

sub load_app_controllers{
    my $self = shift;
    
    $self->log->debug("Loading app controllers from class " . $self->config->{controllers});
    
    my $loader = Mojo::Loader->new;
    for my $class (@{$loader->search($self->config->{controllers})}) {
        $self->log->debug("loading class $class");

        my $exception = $loader->load($class);
        if($exception){
            $self->log->error($exception);
        }
        
        $self->app->routes->add_child($_) for @{$class->new->routes->children};
        
        # Make DATA sections accessible
        push @{$self->app->static->classes},   $class;
        push @{$self->app->renderer->classes}, $class;
    }
}

sub start_apns{
    my $self = shift;
    my $apns = CDSink::CDNotification->new($self->app);
    $self->helper(apns => sub { return $apns });
}

#setup routes
sub setup_basic_routes{
    my $self = shift;
    my $r = $self->routes;
    $r->get("/" =>sub{
        my $self = shift;
        $self->render(json => {message => "CD Sink version 1.0"}, status=>200);
    });

    $r->get("/pushtest" => sub{
	my $self = shift;
	$self->apns->send_alert_to_user(1, "message");
	$self->render(json => {message => "sending push notification"}, status=>200);
	    });
}

sub setup_object_routes{
    my $self = shift;
    
    $self->log->debug("setup_object_routes");
    my $r = $self->routes;
    my %entities = %{$self->model};
    
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
    $r->get('/user')->to(controller => "Login", action=>"get_login_info");
    $r->post('/user')->to(controller => "Login", action=>"new_user");
    $r->put('/user')->to(controller => "Login", action=>"update_user");
    $r->any('/login')->to(controller => "Login", action=>"login");
    $r->any('/logout')->to(controller => "Login", action=>"logout");
    $r->delete('/user')->to(controller => "Login", action=>"delete_user");

    $r->post('/user/push')->to(controller => "Push", action=>"set_device_token");
}

sub setup_sync_routes{
    my $self = shift;
    my $r = $self->routes;
    $r->get("/inserts")->to(controller=>"Sync", action=>"deletes_for_user");
    $r->get("/changes")->to(controller=>"Sync", action=>"changes_for_user");
    $r->get("/deletes")->to(controller=>"Sync", action=>"deletes_for_user");
    $r->get("/log")->to(controller=>"Sync", action=>"log_for_user");
}

sub setup_image_routes{
    my $self = shift;
    my $r = $self->routes;
    $r->post("/imageUpload")->to(controller=>"Images", action=>"image_upload");
    $r->get("/images/:image")->to(controller=>"Images", action=>"get_image");
}

1;
