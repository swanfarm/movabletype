package EntryTemplate::EntryTemplate;

use strict;
use warnings;

use MT;
use MT::Object;
use MT::Util qw( trim encode_html );
use base qw( MT::Object );

use EntryTemplate;

__PACKAGE__->install_properties(
    {   column_defs => {
            id      => 'integer not null auto_increment',
            blog_id => 'integer not null',
            label   => {
                type => 'string',
                size => 255,
            },
            text        => { type => 'text', },
            description => {
                type => 'string',
                size => 255,
            },
        },
        indexes => {
            blog_id     => 1,
            label       => 1,
            created_on  => 1,
            modified_on => 1,
            blog_c_by   => { columns => [ 'blog_id', 'created_by' ], },
        },

        child_of => 'MT::Blog',
        audit    => 1,

        datasource  => 'entry_template',
        primary_key => 'id',
    }
);

sub class_type {
    'entry_template';
}

sub class_label {
    translate('EntryTemplate');
}

sub class_label_plural {
    translate('EntryTemplates');
}

sub list_props {
    return {
        label => {
            label      => 'Name',
            base       => '__virtual.label',
            display    => 'force',
            order      => 200,
            sub_fields => [
                {   class   => 'description',
                    label   => 'Description',
                    display => 'optional',
                },
            ],
            bulk_html => sub {
                my $prop     = shift;
                my ($objs)   = @_;
                my %blog_ids = map { $_->blog_id => 1 } @$objs;
                my @blogs    = MT->model('blog')->load(
                    { id => [ keys %blog_ids ], },
                    {   fetchonly => {
                            id        => 1,
                            name      => 1,
                            parent_id => 1,
                        }
                    }
                );
                my $user = MT->instance->user;
                my %perms = map { $_->id => $user->permissions($_) } @blogs;
                my @out = ();

                require EntryTemplate::App;

                for my $obj (@$objs) {
                    my $label       = encode_html($obj->label);
                    my $description = $obj->description;
                    if ($description) {
                        my $len = 40;
                        if ( length $description > $len ) {
                            $description = substr( $description, 0, $len );
                            $description .= '...';
                        }

                        $description = '<p class="description">'
                            . encode_html($description) . '</p>';
                    }
                    if (EntryTemplate::App::can_edit_entry_template($perms{$obj->blog_id}, $obj, $user)) {
                        my $edit_url = MT->app->uri(
                            mode => 'view',
                            args => {
                                _type   => 'entry_template',
                                id      => $obj->id,
                                blog_id => $obj->blog_id,
                            }
                        );
                        push @out, qq{
                            <a href="$edit_url">$label</a>
                            $description
                        };
                    }
                    else {
                        push @out, qq{
                            $label
                            $description
                        };
                    }
                }

                return @out;
            },
        },
        author_name => {
            base    => '__virtual.author_name',
            order   => 300,
            display => 'default',
        },
        blog_name => {
            base  => '__virtual.blog_name',
            order => 400,
            display => 'default',
            site_name => 0,
            view  => ['system'],
            bulk_html => sub {
                my $prop     = shift;
                my ($objs)   = @_;
                my %blog_ids = map { $_->blog_id => 1 } @$objs;
                my @blogs    = MT->model('blog')->load(
                    { id => [ keys %blog_ids ], },
                    {   fetchonly => {
                            id        => 1,
                            name      => 1,
                            parent_id => 1,
                        }
                    }
                );
                my %blog_map = map { $_->id        => $_ } @blogs;
                my %site_ids = map { $_->parent_id => 1 }
                    grep {
                    $_->parent_id
                        && !$blog_map{ $_->parent_id }
                    } @blogs;
                my @sites
                    = MT->model('website')
                    ->load( { id => [ keys %site_ids ], },
                    { fetchonly => { id => 1, name => 1, }, } )
                    if keys %site_ids;
                my %urls = map {
                    $_->id => MT->app->uri(
                        mode => 'list',
                        args => {
                            _type   => 'entry_template',
                            blog_id => $_->id,
                        }
                    );
                } @blogs;
                my %blog_site_map
                    = map { $_->id => $_ } ( @blogs, @sites );
                my @out;

                for my $obj (@$objs) {
                    if ( !$obj->blog_id ) {
                        push @out, MT->translate('(system)');
                        next;
                    }
                    my $blog = $blog_site_map{ $obj->blog_id };
                    unless ($blog) {
                        push @out,
                            MT->translate('*Website/Blog deleted*');
                        next;
                    }

                    my $name = undef;
                    if ((   my $site
                            = $blog_site_map{ $blog->parent_id }
                        )
                        && $prop->site_name
                        )
                    {
                        $name = join( '/', $site->name, $blog->name );
                    }
                    else {
                        $name = $blog->name;
                    }

                    push @out,
                          '<a href="'
                        . $urls{ $blog->id } . '">'
                        . encode_html($name) . ' (' . $blog->id . ')</a>';
                }

                return @out;
            },
        },
        created_on => {
            base    => '__virtual.created_on',
            display => 'default',
            order   => 500,
        },
        modified_on => {
            base  => '__virtual.modified_on',
            order => 600,
        },
    };
}

sub save_filter {
    my ( $cb, $app ) = @_;

    my %values = ();
    $values{$_} = $app->param($_) for ( 'id', @{ required_fields() } );
    if ( my $user = $app->user ) {
        $values{created_by} = $user->id;
    }
    validate( $cb, \%values );
}

sub validate {
    my ( $cb, $values ) = @_;

    foreach my $f ( @{ required_fields() } ) {
        if ( !trim( $values->{$f} ) ) {
            return $cb->error( translate( ucfirst($f) . ' is required.' ) );
        }
    }

    return 1;
}

sub required_fields {
    [qw(label)];
}

1;
