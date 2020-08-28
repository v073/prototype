package V073::Controller::Voting;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub create_voting_form ($self) {
    # Template only
}

sub create_voting ($self) {

    # Use default options
    my $type = $self->db('Type')->first;

    # Create
    my $voting = $self->db('Voting')->create({
        text    => $self->param('text'),
        type    => $type->name,
        token   => $self->token,
    });

    # Save & redirect
    $self->session(voting => $voting->id);
    return $self->redirect_to('voting');
}

sub restricted ($self) {

    # Nothing found in session data
    my $voting_id = $self->session('voting');
    $self->reply->not_found and return unless defined $voting_id;

    # Try to load
    my $voting = $self->db('Voting')->search({'me.id' => $voting_id},
        {prefetch => {type => 'options'}})->first;
    $self->reply->not_found and return unless defined $voting;

    # Store
    $self->stash(
        voting  => $voting,
        options => scalar($voting->type->options),
    );
}

sub view ($self) {

    # Closed: show the results
    my $voting = $self->stash('voting');
    if ($voting->closed) {

        # Count
        my $vote_total  = $voting->votes->count;
        my $token_total = $voting->tokens->count;
        my %count; $count{$_->get_column('option')}++ for $voting->votes;
        # $_->option->id would lead to a new request

        # Done
        return $self->render(
            vote_count  => \%count,
            vote_total  => $vote_total,
            token_total => $token_total,
            template    => 'vote/results',
        );
    }

    return $self->render(template => 'voting/view');
}

sub generate_tokens ($self) {

    # Check token count
    my $count = $self->param('token_count');
    $count =~ s/^\s*(\S+)\s*$/$1/;
    return $self->render(text => 'Invalid token count', status => 403)
        if $count =~ /\D/ or $count < 1 or $count > 1_000;

    # Generate and store tokens
    for my $i (1 .. $count) {
        my $token = $self->token; # Generate
        $self->stash('voting')->create_related(tokens => {name => $token});
    }

    # Done
    return $self->redirect_to('voting');
}

sub start ($self) {
    $self->stash('voting')->update({started => 1});
    return $self->redirect_to('voting');
}

sub close ($self) {
    $self->stash('voting')->update({closed => 1});
    return $self->redirect_to('voting');
}

1;
