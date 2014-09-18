# Movable Type (r) (C) 2001-2014 Six Apart, Ltd. All Rights Reserved.
# This code cannot be redistributed without permission from www.sixapart.com.
# For more information, consult your Movable Type license.
#
# $Id$

package MT::DataAPI::Resource::Category::v2;

use strict;
use warnings;

use MT::CMS::Category;
use MT::Util;

sub updatable_fields {
    [   qw(
            parent
            allowTrackbacks
            pingUrls
            )
    ];
}

sub fields {
    [   {   name             => 'updatable',
            type             => 'MT::DataAPI::Resource::DataType::Boolean',
            bulk_from_object => sub {
                my ( $objs, $hashes ) = @_;
                my $app  = MT->instance;
                my $user = $app->user;

                if ( $user->is_superuser ) {
                    $_->{updatable} = 1 for @$hashes;
                    return;
                }

                my %blog_perms;
                for ( my $i = 0; $i < scalar @$objs; $i++ ) {
                    my $obj = $objs->[$i];

                    next if $obj->class ne 'category';

                    my $cat_blog_id = $obj->blog_id;
                    if ( !exists $blog_perms{$cat_blog_id} ) {
                        $blog_perms{$cat_blog_id}
                            = $user->permissions($cat_blog_id)
                            ->can_do('save_category');
                    }

                    if ( $blog_perms{$cat_blog_id} ) {
                        $hashes->[$i]{updatable} = 1;
                    }
                }
            },
        },
        {   name                => 'allowTrackbacks',
            alias               => 'allow_pings',
            from_object_default => 0,
            type                => 'MT::DataAPI::Resource::DataType::Boolean',
        },
        {   name        => 'pingUrls',
            alias       => 'ping_urls',
            from_object => sub {
                my $obj      = shift;
                my $app      = MT->instance;
                my $callback = undef;

                if ( !MT::CMS::Category::can_view( $callback, $app, $obj ) ) {
                    return;
                }

                return $obj->ping_url_list;
            },
            to_object => sub {
                my $hash = shift;

                my $ping_urls = $hash->{pingUrls};
                if ( ref($ping_urls) ne 'ARRAY' ) {
                    $ping_urls = [$ping_urls];
                }

                return join( "\n", @$ping_urls );
            },
        },
        {   name        => 'archiveLink',
            from_object => sub {
                my ($obj) = @_;

                my $blog = MT->model('blog')->load( $obj->blog_id );
                if ( !$blog ) {
                    return;
                }

                my $url = $blog->archive_url;
                $url .= '/' unless $url =~ m/\/$/;
                $url .= MT::Util::archive_file_for( undef, $blog, 'Category',
                    $obj );

                return $url;
            },
        },
    ];
}

1;

__END__

=head1 NAME

MT::DataAPI::Resource::Category::v2 - Movable Type class for resources definitions of the MT::Category.

=head1 AUTHOR & COPYRIGHT

Please see the I<MT> manpage for author, copyright, and license information.

=cut
