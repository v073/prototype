package V073;
use Mojo::Base 'Mojolicious', -signatures;

sub startup ($self) {
    $self->plugin('NotYAMLConfig'); # Load from v073.yml
    $self->_set_routes;
}

sub _set_routes ($self) {
    my $r = $self->routes;
    $r->get('/')->to('example#welcome');
}

1;
