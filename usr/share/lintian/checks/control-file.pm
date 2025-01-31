# control-file -- lintian check script -*- perl -*-
#
# Copyright (C) 2004 Marc Brockschmidt
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, you can find it on the World Wide
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::control_file;
use strict;
use warnings;
use autodie;

use List::MoreUtils qw(any);
use List::Util qw(first);

use Lintian::Data ();
use Lintian::Relation ();
use Lintian::Tags qw(tag);
use Lintian::Util qw(file_is_encoded_in_non_utf8 read_dpkg_control
  rstrip strip);

# The list of libc packages, used for checking for a hard-coded dependency
# rather than using ${shlibs:Depends}.
my @LIBCS = qw(libc6 libc6.1 libc0.1 libc0.3);
my $LIBCS = Lintian::Relation->new(join(' | ', @LIBCS));
my $src_fields = Lintian::Data->new('common/source-fields');

sub run {
    my ($pkg, undef, $info) = @_;
    my $dcontrol = $info->debfiles('control');

    if (-l $dcontrol) {
        tag 'debian-control-file-is-a-symlink';
    }

    # check that control is UTF-8 encoded
    my $line = file_is_encoded_in_non_utf8($dcontrol);
    if ($line) {
        tag 'debian-control-file-uses-obsolete-national-encoding',
          "at line $line";
    }

    # Nag about dh_make Vcs comment only once
    my $seen_vcs_comment = 0;
    open(my $fd, '<', $dcontrol);
    while (<$fd>) {
        s/\s*\n$//;

        if (
            m{\A \# \s* Vcs-(?:Git|Browser): \s*
                  (?:git|http)://git\.debian\.org/
                  (?:\?p=)?collab-maint/<pkg>\.git}osmx
          ) {
            # Emit it only once per package
            tag 'control-file-contains-dh_make-vcs-comment'
              unless $seen_vcs_comment++;
            next;
        }

        next if /^\#/;

        # line with field:
        if (/^(\S+):/) {
            my $field = lc($1);
            if ($field =~ /^xs-vcs-/) {
                my $base = $field;
                $base =~ s/^xs-//;
                tag 'xs-vcs-header-in-debian-control', $field
                  if $src_fields->known($base);
            }
            if ($field eq 'xc-package-type') {
                tag 'xc-package-type-in-debian-control', "line $.";
            }
            unless (/^\S+: \S/ || /^\S+:$/) {
                tag 'debian-control-has-unusual-field-spacing', "line $.";
            }
            # something like "Maintainer: Maintainer: bad field"
            if (/^\Q$field\E: \s* \Q$field\E \s* :/xsmi) {
                tag 'debian-control-repeats-field-name-in-value', "line $.";
            }
        }
    }
    close($fd);

    eval {
        # check we can parse it, but ignore the result - we will fetch
        # the fields we need from $info.
        read_dpkg_control($dcontrol);
    };
    if ($@) {
        chomp $@;
        $@ =~ s/^internal error: //;
        $@ =~ s/^syntax error in //;
        tag 'syntax-error-in-control-file', "debian/control: $@";
        return;
    }

    my @package_names = $info->binaries;

    foreach my $bin (@package_names) {
        my $bfields = $info->binary_field($bin);
        tag 'build-info-in-binary-control-file-section', "Package $bin"
          if (first { $bfields->{"build-$_"} }
            qw(depends depends-indep conflicts conflicts-indep));
        foreach my $field (keys %$bfields) {
            tag 'binary-control-field-duplicates-source',
              "field \"$field\" in package $bin"
              if ( $info->source_field($field)
                && $bfields->{$field} eq $info->source_field($field));
        }
    }

    # Check that fields which should be comma-separated or
    # pipe-separated have separators.  Places where this tends to
    # cause problems are with wrapped lines such as:
    #
    #     Depends: foo, bar
    #      baz
    #
    # or with substvars.  If two substvars aren't separated by a
    # comma, but at least one of them expands to an empty string,
    # there will be a lurking bug.  The result will be syntactically
    # correct, but as soon as both expand into something non-empty,
    # there will be a syntax error.
    #
    # The architecture list can contain things that look like packages
    # separated by spaces, so we have to remove any architecture
    # restrictions first.  This unfortunately distorts our report a
    # little, but hopefully not too much.
    #
    # Also check for < and > relations.  dpkg-gencontrol warns about
    # them and then transforms them in the output to <= and >=, but
    # it's easy to miss the error message.  Similarly, check for
    # duplicates, which dpkg-source eliminates.

    for my $field (
        qw(build-depends build-depends-indep
        build-conflicts build-conflicts-indep)
      ) {
        my $raw = $info->source_field($field);
        my $rel;
        next unless $raw;
        $rel = Lintian::Relation->new($raw);
        check_relation('source', $field, $raw, $rel);
    }

    for my $bin (@package_names) {
        for my $field (
            qw(pre-depends depends recommends suggests breaks
            conflicts provides replaces enhances)
          ) {
            my $raw = $info->binary_field($bin, $field);
            my $rel;
            next unless $raw;
            $rel = $info->binary_relation($bin, $field);
            check_relation($bin, $field, $raw, $rel);
        }
    }

    # Make sure that a stronger dependency field doesn't imply any of
    # the elements of a weaker dependency field.  dpkg-gencontrol will
    # fix this up for us, but we want to check the source package
    # since dpkg-gencontrol may silently "fix" something that's a more
    # subtle bug.
    #
    # Also check if a package declares a simple dependency on itself,
    # since similarly dpkg-gencontrol will clean this up for us but it
    # may be a sign of another problem, and check that the package
    # doesn't hard-code a dependency on libc.  We have to do the
    # latter check here rather than in checks/fields to distinguish
    # from dependencies created by ${shlibs:Depends}.
    my @dep_fields = qw(pre-depends depends recommends suggests);
    foreach my $bin (@package_names) {
        for my $strong (0 .. $#dep_fields) {
            next unless $info->binary_field($bin, $dep_fields[$strong]);
            my $relation = $info->binary_relation($bin, $dep_fields[$strong]);
            tag 'package-depends-on-itself', $bin, $dep_fields[$strong]
              if $relation->implies($bin);
            tag 'package-depends-on-hardcoded-libc', $bin, $dep_fields[$strong]
              if $relation->implies($LIBCS)
              and $pkg !~ /^e?glibc$/;
            for my $weak (($strong + 1) .. $#dep_fields) {
                next unless $info->binary_field($bin, $dep_fields[$weak]);
                for my $dependency (split /\s*,\s*/,
                    $info->binary_field($bin, $dep_fields[$weak])) {
                    next unless $dependency;
                    tag 'stronger-dependency-implies-weaker', $bin,
                      "$dep_fields[$strong] -> $dep_fields[$weak]", $dependency
                      if $relation->implies($dependency);
                }
            }
        }
    }

    # Check that every package is in the same archive area, except
    # that sources in main can deliver both main and contrib packages.
    # The source package may or may not have a section specified; if
    # it doesn't, derive the expected archive area from the first
    # binary package by leaving $area undefined until parsing the
    # first binary section.  Missing sections will be caught by other
    # checks.
    #
    # Check any package that looks like a library -dev package for a
    # dependency on a shared library package built from the same
    # source.  If found, such a dependency should have a tight version
    # dependency on that package.
    #
    # Also accumulate short and long descriptions for each package so
    # that we can check for duplication, but skip udeb packages.
    # Ideally, we should check the udeb package descriptions
    # separately for duplication, but udeb packages should be able to
    # duplicate the descriptions of non-udeb packages and the package
    # description for udebs is much less important or significant to
    # the user.
    my $area = $info->source_field('section');
    if (defined $area) {
        if ($area =~ m%^([^/]+)/%) {
            $area = $1;
        } else {
            $area = 'main';
        }
    } else {
        tag 'no-section-field-for-source';
    }
    my @descriptions;
    foreach my $bin (@package_names) {

        # Accumulate the description.
        my $desc = $info->binary_field($bin, 'description');
        my $bin_area;
        if ($desc and $info->binary_package_type($bin) ne 'udeb') {
            push @descriptions, [$bin, split("\n", $desc, 2)];
        }

        # If this looks like a -dev package, check its dependencies.
        if ($bin =~ /-dev$/ and $info->binary_field($bin,'depends')) {
            check_dev_depends($info, $bin,$info->binary_field($bin, 'depends'),
                @package_names);
        }

        # Check mismatches in archive area.
        $bin_area = $info->binary_field($bin, 'section');
        next unless $area && $bin_area;

        if ($bin_area =~ m%^([^/]+)/%) {
            $bin_area = $1;
        } else {
            $bin_area = 'main';
        }
        next
          if $area eq $bin_area
          or ($area eq 'main' and $bin_area eq 'contrib');

        tag 'section-area-mismatch', 'Package', $bin;
    }

    # Check for duplicate descriptions.
    my (%seen_short, %seen_long);
    for my $i (0 .. $#descriptions) {
        my (@short, @long);
        for my $j (($i + 1) .. $#descriptions) {
            if ($descriptions[$i][1] eq $descriptions[$j][1]) {
                my $package = $descriptions[$j][0];
                push(@short, $package) unless $seen_short{$package};
            }
            next unless ($descriptions[$i][2] and $descriptions[$j][2]);
            if ($descriptions[$i][2] eq $descriptions[$j][2]) {
                my $package = $descriptions[$j][0];
                push(@long, $package) unless $seen_long{$package};
            }
        }
        if (@short) {
            tag 'duplicate-short-description', $descriptions[$i][0], @short;
            for (@short) { $seen_short{$_} = 1 }
        }
        if (@long) {
            tag 'duplicate-long-description', $descriptions[$i][0], @long;
            for (@long) { $seen_long{$_} = 1 }
        }
    }

    # check the Build-Profiles field
    # this has to checked here because the Build-Profiles field does not appear
    # in DEBIAN/control and even if it should in the future, some binary
    # packages might never be built in the first place because of build
    # profiles

    # check which profile names are supposedly supported according to the build
    # dependencies
    my %used_profiles;
    for my $field (
        qw(build-depends build-depends-indep build-conflicts build-conflicts-indep)
      ) {
        if (my $value = $info->source_field($field)) {
            # If the field does not contain "profile." then skip this
            # part.  They rarely do, so this is just a little
            # "common-case" optimisation.
            next if index($value, 'profile.') < 0;
            for my $dep (split /\s*,\s*/, $value) {
                for my $alt (split /\s*\|\s*/, $dep) {
                    while ($alt =~ /<([^>]+)>/g) {
                        for my $restr (split /\s+/, $1) {
                            if ($restr =~ m/^!?profile\.(.*)/) {
                                $used_profiles{$1} = 0;
                            }
                        }
                    }
                }
            }
        }
    }

    # find those packages that do not get built because of a certain build
    # profile
    for my $bin (@package_names) {
        my $raw = $info->binary_field($bin, 'build-profiles');
        next unless $raw;
        for my $prof (split /\s+/, $raw) {
            if ($prof =~ s/^!//) {
                $used_profiles{$prof} = 1;
            }
        }
    }

    # find out if the developer forgot to mark binary packages as not being
    # built
    while (my ($k, $v) = each(%used_profiles)) {
        tag 'stageX-profile-used-but-no-binary-package-dropped'
          if (($k eq 'stage1' || $k eq 'stage2') && $v == 0);
    }

    # find binary packages that Pre-Depend on multiarch-support without going
    # via ${misc:Pre-Depends}
    if ($info->source_field('build-depends')) {
        if ($info->source_field('build-depends') =~ /debhelper/) {
            for my $bin (@package_names) {
                my $raw = $info->binary_field($bin, 'pre-depends');
                next unless $raw;
                if($raw =~ /multiarch-support/) {
                    tag 'pre-depends-directly-on-multiarch-support',$bin;
                }
            }
        }
    }

    return;
}

# Check the dependencies of a -dev package.  Any dependency on one of the
# packages in @packages that looks like the underlying library needs to
# have a version restriction that's at least as strict as the same upstream
# version.
sub check_dev_depends {
    my ($info, $package, $depends, @packages) = @_;
    strip($depends);
    for my $target (@packages) {
        next
          unless ($target =~ /^lib[\w.+-]+\d/
            and $target !~ /-(?:dev|docs?|common)$/);
        my @depends = grep { /(?:^|[\s|])\Q$target\E(?:[\s|\(]|\z)/ }
          split(/\s*,\s*/, $depends);

        # If there are any alternatives here, something special is
        # going on.  Assume that the maintainer knows what they're
        # doing.  Otherwise, separate out just the versions.
        next if any { /\|/ } @depends;
        my @versions = sort map {
            if (/^[\w.+-]+(?:\s*\(([^\)]+)\))/) {
                $1;
            } else {
                '';
            }
        } @depends;

        # If there's only one mention of this package, the dependency
        # should be tight.  Otherwise, there should be both >>/>= and
        # <</<= dependencies that mention the source, binary, or
        # upstream version.  If there are more than three mentions of
        # the package, again something is weird going on, so we assume
        # they know what they're doing.
        if (@depends == 1) {
            unless ($versions[0]
                =~ /^\s*=\s*\$\{(?:binary:Version|Source-Version)\}/) {
                # Allow "pkg (= ${source:Version})" if (but only if)
                # the target is an arch:all package.  This happens
                # with a lot of mono-packages.
                #
                # Note, we do not check if the -dev package is
                # arch:all as well.  The version-substvars check
                # handles that for us.
                next
                  if $info->binary_field($target, 'architecture', '') eq 'all'
                  && $versions[0] =~ /^\s*=\s*\$\{source:Version\}/;
                tag 'weak-library-dev-dependency', "$package on $depends[0]";
            }
        } elsif (@depends == 2) {
            unless (
                $versions[0] =~ m/^\s*<[=<]\s* \$\{
                        (?: (?:binary|source):(?:Upstream-)?Version
                            |Source-Version)\}/xsm
                && $versions[1] =~ m/^\s*>[=>]\s* \$\{
                        (?: (?:binary|source):(?:Upstream-)?Version
                        |Source-Version)\}/xsm
              ) {
                tag 'weak-library-dev-dependency',
                  "$package on $depends[0], $depends[1]";
            }
        }
    }
    return;
}

# Checks for duplicates in a relation, for missing separators and
# obsolete relation forms.
sub check_relation {
    my ($pkg, $field, $rawvalue, $relation) = @_;
    for my $dup ($relation->duplicates) {
        tag 'duplicate-in-relation-field', 'in', $pkg,
          "$field:", join(', ', @$dup);
    }

    $rawvalue =~ s/\n(\s)/$1/g;
    $rawvalue =~ s/\[[^\]]*\]//g;
    if (
        $rawvalue =~ /(?:^|\s)
                   (
                (?:\w[^\s,|\$\(]+|\$\{\S+:Depends\})\s*
                (?:\([^\)]*\)\s*)?
                   )
                   \s+
                   (
                (?:\w[^\s,|\$\(]+|\$\{\S+:Depends\})\s*
                (?:\([^\)]*\)\s*)?
                   )/x
      ) {
        my ($prev, $next) = ($1, $2);
        for ($prev, $next) {
            rstrip;
        }
        tag 'missing-separator-between-items', 'in', $pkg,
          "$field field between '$prev' and '$next'";
    }
    while ($rawvalue =~ /([^\s\(]+\s*\([<>]\s*[^<>=]+\))/g) {
        tag 'obsolete-relation-form-in-source', 'in', $pkg,"$field: $1";
    }
    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
