package V073::Controller::Home;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub token_form ($self) {
    # Template only
}

sub token_dispatch ($self) {
    my $token = $self->param('token');

    # Is it a voting ("admin") token?
    if (my $voting = $self->db('Voting')->search({token => $token})->first) {
        $self->session(voting => $voting->id);
        return $self->redirect_to('voting');
    }

    # Is it a vote token?
    if (my $token = $self->db('Token')->search({name => $token})->first) {
        $self->session(token => $token->name);
        return $self->redirect_to('vote');
    }

    # It's nothing!
    return $self->reply->not_found;
}

1;
