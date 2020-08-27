package V073::Controller::Vote;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub restricted ($self) {

    # Nothing found in session data
    my $token_name = $self->session('token');
    $self->reply->not_found and return unless defined $token_name;

    # Try to load
    my $token = $self->db('Token')->search({'me.name' => $token_name},
        {prefetch => {voting => {type => 'options'}}})->first;
    $self->reply->not_found and return unless defined $token;

    # Store
    $self->stash(
        token   => $token,
        voting  => $token->voting,
        options => scalar($token->voting->type->options),
    );
}

sub view ($self) {
    # Template only
}

sub cast ($self) {

    # Token already used for voting?
    return $self->render(text => 'Already voted', status => 403)
        if $self->stash('token')->voted;

    # Check the option voted for
    my $option_id   = $self->param('option');
    my $option      = $self->stash('options')->find($option_id);
    return $self->render(text => 'Forbidden', status => 403) unless $option;

    # Store the vote
    my $voting_id   = $self->stash('voting')->id;
    my $vote        = $option->create_related(votes => {voting => $voting_id});

    # Disable the token
    $self->stash('token')->update({voted => 1});

    # Got to voting view
    return $self->redirect_to('view_vote');
}

1;
