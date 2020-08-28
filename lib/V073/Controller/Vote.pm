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

sub vote ($self) {

    # Prepare
    my $token   = $self->stash('token');
    my $voting  = $self->stash('voting');

    # Dispatch template
    return $self->render(template => 'vote/too_early')
        if not $voting->started;
    return $self->render(template => 'vote/cast_form')
        if $voting->started and not $voting->closed and not $token->voted;
    return $self->render(template => 'vote/wait')
        if not $voting->closed;
    # else: show the results

    # We have results! Count them!
    my $vote_total  = $voting->votes->count;
    my $token_total = $voting->tokens->count;
    my %count; $count{$_->get_column('option')}++ for $voting->votes;
    # $_->option->id whould lead to a new request

    # Done
    return $self->render(
        vote_count  => \%count,
        vote_total  => $vote_total,
        token_total => $token_total,
        template    => 'vote/results',
    );
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

    # Done
    return $self->render(template => 'vote/thanks');
}

1;
