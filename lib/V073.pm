package V073;
use Mojo::Base 'Mojolicious', -signatures;

use DBI;
use V073::DB;

sub startup ($self) {
    $self->plugin('NotYAMLConfig'); # Load from v073.yml
    $self->_prepare_db;
    $self->_add_default_options;
    $self->_token_helper;
    $self->_other_helpers;
    $self->_set_routes;
}

sub _prepare_db ($self) {

    # Determine DB file names
    my $db_file     = $self->home->rel_file(
        $self->config('db')->{file});
    my $schema_file = $self->home->rel_file(
        $self->config('db')->{schema_file});
    my $dsn         = "dbi:SQLite:dbname=$db_file";

    # Load schema into sqlite db, if neccessary
    unless (-e $db_file) {
        my $dbh = DBI->connect($dsn, '', '', {sqlite_unicode => 1});
        $dbh->do($_) for split /;/ => $schema_file->slurp;
    }

    # Add schema as web app helper
    $self->helper(db => sub ($app, $rs) {
        state $db = V073::DB->connect($dsn, '', '', {sqlite_unicode => 1});
        return defined($rs) ? $db->resultset($rs) : $db;
    });
}

sub _add_default_options ($self) {

    # Load default options from config
    my $default_options = $self->config('voting')->{default_options};

    # Add to database
    while (my ($type_name, $option_names) = each %$default_options) {
        next if $self->db('Type')->count({name => $type_name});
        my $type = $self->db('Type')->create({name => $type_name});
        $type->create_related(options => {text => $_}) for @$option_names;
    }
}

sub __generate_token ($len) {
    my @chars = ('A'..'Z', '0'..'9');
    return join '' => map $chars[rand @chars] => 1 .. $len;
}

sub _token_helper ($self) {
    $self->helper(token => sub ($self) {
        my $token   = __generate_token($self->config('token_length'));
        my $voting  = $self->db('Voting')->count({token => $token});
        my $vote    = $self->db('Token')->count({name => $token});
        $token      = $self->token if $voting or $vote;
        return $token;
    });
}

sub _other_helpers ($self) {

    # Render percent from [0,1]
    $self->helper(percent => sub {sprintf '%.2f %%' => $_[1] * 100});
    # TODO localization?
}

sub _set_routes ($self) {
    my $r = $self->routes;

    # Home: insert token
    $r->get('/')->to('home#token_form')->name('home');
    $r->post('/')->to('home#token_dispatch')->name('token_dispatch');

    # Or: create voting
    $r->get('/create_voting')->to('voting#create_voting_form')->name('create');
    $r->post('/create_voting')->to('voting#create_voting')->name('create');

    # Inspect / modify voting
    my $ra = $r->under('/voting')->to('voting#restricted');
    $ra->get('/admin_token')->to('#admin_token')->name('admin_token');
    $ra->get('/')->to('#view')->name('voting');
    $ra->post('/tokens')->to('#manage_tokens')->name('manage_tokens');
    $ra->post('/tokens/delete')->to('#delete_token')->name('delete_token');
    $ra->post('/start')->to('#start')->name('start_voting');
    $ra->post('/close')->to('#close')->name('close_voting');

    # Cast a vote
    my $rv = $r->under('/vote')->to('vote#restricted');
    $rv->get('/')->to('#vote')->name('vote');
    $rv->post('/')->to('#cast')->name('cast_vote');
}

1;
