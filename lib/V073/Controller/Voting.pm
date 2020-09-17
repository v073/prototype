package V073::Controller::Voting;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub create_voting_form ($self) {

    # Prepare types and options
    # Hide free types (basically default options only)
    my $types = $self->db('Type')->search({
        name => {-not_like => 'free_%'},
    }, {
        prefetch => 'options',
        order_by => 'options.id', # important for option stringification
    });

    # Option stringification
    my %string;
    for my $type ($types->all) {
        $string{$type->name} = join ' / ' => map $_->text => $type->options;
    }

    # Done
    $self->stash(
        types       => $types,
        type_string => \%string,
    );
}

sub _create_free_type_name ($len = 20) {
    my @chars = ('a'..'z', '0'..'9');
    return join '' => map $chars[rand @chars] => 1 .. $len;
}

sub create_voting ($self) {

    # Create a new type
    my $type_name = $self->param('type');
    my $type;
    if ($type_name eq 'free') {

        # Create the type
        $type_name = 'free_' . _create_free_type_name;
        $self->db('Type')->create({name => $type_name});
        $type = $self->db('Type')->find($type_name);

        # Create the initial option (abstention)
        my $abst = $self->config('voting')->{abstention};
        $type->create_related(options => {text => $abst});
    }

    # Or try to load the correct type
    else {
        $type = $self->db('Type')->find($type_name);
        return $self->reply->not_found unless defined $type;
    }

    # Create the voting
    my $voting = $self->db('Voting')->create({
        text    => $self->param('text'),
        type    => $type->name,
        token   => $self->token,
    });

    # Generate initial tokens
    my $count = $self->param('token_count');
    $count =~ s/^\s*(\S+)\s*$/$1/;
    return $self->render(text => 'Invalid token count', status => 403)
        if $count =~ /\D/ or $count < 0
        or $count > $self->config('voting')->{max_token_count};
    for my $i (1 .. $count) {
        my $token = $self->token; # Generate
        $voting->create_related(tokens => {name => $token});
    }

    # Save & redirect
    $self->session(voting => $voting->id);
    return $self->redirect_to('admin_token');
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

sub admin_token ($self) {
    # Template only
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

sub add_option ($self) {
    my $type = $self->stash('voting')->type;

    # Not possible with un-free types
    return $self->render(text => 'Type not free', status => 403)
        unless $type->name =~ /^free_/;

    # Prepare option text
    my $text = $self->param('option');
    return $self->render(text => 'No option given', status => 403)
        unless defined $text and $text =~ /\S/;
    $text =~ s/^\s*(.*?)\s*$/$1/;

    # Create the new option for the voting's type
    $type->create_related(options => {text => $text});

    # Done
    return $self->redirect_to('voting');
}

sub delete_option ($self) {
    my $voting = $self->stash('voting');

    # Too late?
    return $self->render(text => 'Voting started', status => 403)
        if $voting->started;

    # Delete
    my $oid = $self->param('option');
    my $del = $voting->type->delete_related(options => {id => $oid});
    return $self->reply->not_found unless $del;

    # Done
    return $self->redirect_to('voting');
}

sub manage_tokens ($self) {
    my $voting = $self->stash('voting');

    # Too late?
    return $self->render(text => 'Voting started', status => 403)
        if $voting->started;

    # Check token count
    my $count = $self->param('token_count');
    $count =~ s/^\s*(\S+)\s*$/$1/;
    return $self->render(text => 'Invalid token count', status => 403)
        if $count =~ /\D/ or $count < 1
        or $count > $self->config('voting')->{max_token_count};

    # What to do?
    my $current = $voting->tokens->count;
    my $diff    = $count - $current;

    # Generate and store new token
    if ($diff > 0) {
        $voting->create_related(tokens => {name => $self->token})
            for 1 .. $diff;
    }
    elsif ($count < $current) {
        my @tokens  = $voting->tokens;
        my $last_id = $tokens[$count-1]->id;
        $voting->tokens({id => {'>' => $last_id}})->delete;
    }

    # Done
    return $self->redirect_to('voting');
}

sub delete_token ($self) {
    my $voting = $self->stash('voting');

    # Too late?
    return $self->render(text => 'Voting started', status => 403)
        if $voting->started;

    # Delete
    my $token   = $self->param('token');
    my $deleted = $voting->delete_related(tokens => {name => $token});
    return $self->reply->not_found unless $deleted;

    # Done
    return $self->redirect_to('voting');
}

sub start ($self) {

    # Prepare
    my $voting          = $self->stash('voting');
    my $option_count    = $voting->type->options->count;
    my $token_count     = $voting->tokens->count;

    # Forbidden state to start the voting?
    return $self->render(text => 'Forbidden', status => 403)
        if $option_count <= 0 or $token_count <= 0;

    # OK, start
    $self->stash('voting')->update({started => 1});
    return $self->redirect_to('voting');
}

sub close ($self) {

    # Prepare
    my $voting      = $self->stash('voting');
    my $token_count = $voting->tokens->count;

    # Forbidden state to close the voting?
    return $self->render(text => 'Forbidden', status => 403)
        if not $voting->started;

    # OK, close
    $self->stash('voting')->update({closed => 1});
    return $self->redirect_to('voting');
}

1;
