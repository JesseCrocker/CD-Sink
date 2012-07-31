use Mojo::Base -strict;

use Test::More tests => 19;
use Test::Mojo;

my $t = Test::Mojo->new('CDSink');

$t->ua->max_redirects(1);

$t->app->log->level('debug');

$t->post_form_ok('/user' => {email => 'jesse@foo.bar', password => 'password'})
    ->status_is(201) ->json_has('/userid');

$t->get_ok('/logout')
    ->status_is(200);

$t->post_form_ok('/login' => {email => 'jesse@foo.bar', password => 'wrong'})
    ->status_is(401);

$t->post_form_ok('/login' => {email => 'wrong', password => 'password'})
    ->status_is(401);

$t->post_form_ok('/login' => {email => 'jesse@foo.bar', password => 'password'})
    ->status_is(202) ->json_has('/userid');
    
$t->get_ok('/user')
    ->status_is(200) ->json_has('/userid') ->json_has('/email') ->json_hasnt('/password');

#$t->get_ok('/messages')
#    ->status_is(200) ->json_has('/0/message/');

$t->delete_ok('/user')
    ->status_is(200);
    
done_testing();