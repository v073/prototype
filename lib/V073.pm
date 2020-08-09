package V073;
use Mojo::Base 'Mojolicious', -signatures;

use DBI;
use V073::DB;

sub startup ($self) {
    $self->plugin('NotYAMLConfig'); # Load from v073.yml
    $self->_prepare_db;
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
    $self->helper(db => sub { state $db = V073::DB->connect($dsn) });
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
