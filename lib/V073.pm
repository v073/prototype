package V073;
use Mojo::Base 'Mojolicious', -signatures;

use DBI;
use V073::DB;

sub startup ($self) {
    $self->plugin('NotYAMLConfig'); # Load from v073.yml
    $self->_prepare_db;
    $self->_add_default_options;
    $self->_token_helper;
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
        my $dbh = DBI->connect($dsn, '', '');
        $dbh->do($_) for split /;/ => $schema_file->slurp;
    }

    # Add schema as web app helper
    $self->helper(db => sub ($app, $rs) {
        state $db = V073::DB->connect($dsn);
        return defined($rs) ? $db->resultset($rs) : $db;
    });
}

sub _add_default_options ($self) {

    # Load default options from config
    my $default_options = $self->config('voting')->{default_options};

    # Add to database
    while (my ($type_name, $option_names) = each %$default_options) {
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
        my $vote    = $self->db('Token')->count({token => $token});
        $token      = $self->token if $voting or $vote;
        return $token;
    });
}

sub _set_routes ($self) {
    my $r = $self->routes;

    # Home: insert token
    $r->get('/')->to('home#token_form')->name('home');

    # Or: create voting
    $r->get('/create_voting')->to('voting#create_voting_form');
    $r->post('/create_voting')->to('voting#create_voting')->name('create');

    # Inspect / modify voting
    my $ra = $r->under('/voting')->to('voting#restricted');
    $ra->get('/')->to('#view');
}

1;
