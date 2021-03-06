#!/usr/bin/perl
sub napi; sub tegnapi; sub keres; sub mutat; sub statf; sub statm; sub statu;
# Header
print <<HEADER;
Content-type: text/html

<!DOCTYPE html>
<html><head>
<meta charset="utf-8" />
<title>subogero napi</title></head><body>
<a href="?napi">napi</a>
<a href="?tegnapi">tegnapi</a>
<a href="?keres">keres</a>
<a href="napi.rss"><img src="rss.gif"></a>
<hr><h3 align="center">subogero napi</h3><hr>
HEADER

# Find working directory (uhttpd runs this in docroot)
($PWD = $0) =~ s/^(.+)index\.pl$/$1/;
chdir $PWD;
push @INC, $PWD;
require Percent2Utf8 or die;

# Store direcory URL upon first use
$dir_url = 'http://' . $ENV{HTTP_HOST} . $ENV{REQUEST_URI};
$dir_url =~ s:/$::;
unless (-f "dir_url.txt") {
    open URL, ">dir_url.txt";
    print URL "$dir_url\n";
    close URL;
}

# Read and sanitize POSTed query from stdin
my $query = $ENV{QUERY_STRING};
@query = split /&/, Percent2Utf8::p2u($query);
if    ($query[0] =~ /keres/  ) { keres   @query }
elsif ($query[0] =~ /tegnapi/) { tegnapi @query }
elsif ($query[0] =~ /mutat/  ) { mutat   @query }
elsif ($query[0] =~ /stat/   ) { statm   @query }
else                           { napi           }

# Footer
if (open MOLINO, "../molino") {
    print while <MOLINO>;
    close MOLINO;
}
print <<FOOTER;
<small><hr> (c) CC - Mer&eacute;nyi D&aacute;niel
<br>Eredeti: h t t p : / / n a p i r a j z . h u ----
h t t p : / / i n d e x . h u / n a p i r a j z ----
h t t p : / / c o m e d y c e n t r a l . h u
<br>Ez az oldal azok számára készült, akiket a céges internet proxy megfosztott
a napi rajz nyújtotta inspirációtól.<hr>
<a href="http://github.com/subogero">github.com/subogero</a>
<a href="?stat">statisztika</a>
</small>
</body></html>
FOOTER

####### Show pics from last 31 days
sub napi {
    my $after = time / (24 * 60 * 60) - 31;
    open MINE, "mine.csv" or print "Could not find database.\n" and return;
    my @hits;
    while (<MINE>) {
        my ($name, $date, $src) = split /[,;\n]/;
        $date =~ s/_0/_/g; # strip leading zeroes from month and day
        my @time = split /_/, $date;
        my $time = ($time[0] - 1970) * 365.25
                 + ($time[1] -    1) *  30.44
                 + ($time[2] -    1);
        push @hits, { name => $name, src => $src } if $time > $after;
    }
    foreach (reverse @hits) {
        (my $basename = $_->{name}) =~ s/^(.+)\..+$/$1/;
        print "<a href=\"?mutat=$_->{name}\">$basename</a> $_->{src}<br>\n";
    }
}

####### Archives by month
sub tegnapi {
    (my $month = $_[0]) =~ s/tegnapi=?(.*)/$1/;
    my $last_month = '';
    my $result = '';
    open MINE, "mine.csv" or print "Could not find database.\n" and return;
    while (<MINE>) {
        if ($month) {
            if (/^((.+)\.jpe?g);$month.*;(.*)$/i) {
                $result = "<a href=\"?mutat=$1\">$2</a> $3<br>\n" . $result;
            }
        } else {
            /^.+;(\d{4}_\d{2}).+/;
            if ($1 ne $last_month) {
                $result = "<a href=\"?tegnapi=$1\">$1</a><br>\n" . $result;
                $last_month = $1;
            }
        }
    }
    close MINE;
    print $result;
}

####### Try to find pattern among jpg filenames in dir, print links to them
sub keres {
    print <<FORM;
<form method="GET" action="?keres">
Forrás:
<select name="keres">
<option value="">mind</option>
<option value="napi">napi</option>
<option value="komedia">komédia</option>
<option value="aindex">aindex</option>
<option value="nincs">ismeretlen</option>
</select>
<input type="text" name="rajz"/>
Keresés rajz nevére. <small>Tipp: üres minta!</small>
</form>
FORM
    (my $src = $_[0]) =~ s/keres=(.*)/$1/;
    $src =~ s/^$/.*/;
    $src =~ s/^nincs$//;
    (my $rajz = $_[1]) =~ s/rajz=(.*)/$1/;
    open MINE, "mine.csv" or print "Could not find database.\n" and return;
    while (<MINE>) {
        if (/^((.*$rajz.*)\.jpe?g);.+;($src)$/i) {
            print "<a href=\"?mutat=$1\">$2</a> $3<br>\n"
        }
    }
    close MINE;
}

####### Show a picture and update usage statistics
sub mutat {
    $_[0] =~ /mutat=(.+)/;
    print "<img src=\"$1\"><br>\n";
    print "<a href=\"$1\">$1</a><br>\n";
    statf;
}

# Usage stats
sub statf {
    `date -Idate` =~ /^(.+)-(.+)-.+$/;
    my ($year, $month) = ($1, $2);
    $month =~ s/^0//;
    $month--;
    if ($month <= 0) {
        $year--;
        $month = 12;
    }
    $month =~ s/^(\d)$/0$1/;
    my $last_month = $year . "_" . $month;
    my $last_statm;
    if (open STATM, "statm.txt") {
        ($last_statm = $_) =~ s/^(.+) .+/$1/ while (<STATM>);
        close STATM;
    }
    my $hits = <STAT> if open STAT, "stat.txt";
    $hits++;
    if ($last_month > $last_statm) {
        print STAT 0 if open STAT, ">stat.txt";
        print STATM "$last_month $hits\n" if open STATM, ">>statm.txt";
    } else {
        print STAT $hits if open STAT, ">stat.txt";
    }
    statu;
}

####### Show usage statistics
sub statm {
    open STATM, "stat.txt";
    $statm{ehavi} = <STATM>;
    $max = $statm{ehavi  };
    open STATM, "statm.txt";
    while (<STATM>) {
        /^(.+) (.+)\n$/;
        $statm{$1} = $2;
        $max = $2 if ($max < $2);
    }
    close STATM;
    $h = keys(%statm) * 10;
    $factor = $max > 1000 ? 1000 / $max : 1;
    $max = $max * $factor + 70;
    print "<canvas id=\"vaszon\" width=\"$max\" height=\"$h\">";
    foreach (reverse sort keys %statm) {
        print "$_ $statm{$_}<br>";
    }
    print <<CANVAS1;
</canvas>
<script type="text/javascript">
var c=document.getElementById("vaszon");
var ctx=c.getContext("2d");
ctx.font="8px monospace";
CANVAS1
    $i = 0;
    foreach (reverse sort keys %statm) {
        print <<LINE;
ctx.textAlign='start'; ctx.fillText("$_"        ,  0, $i*10+7);
ctx.textAlign='right'; ctx.fillText("$statm{$_}", 60, $i*10+7);
ctx.fillRect(70, $i*10, $statm{$_} * $factor, 8);
LINE
        $i++;
    }
    print <<CANVAS2;
</script>
CANVAS2
}

# Update user statistics
sub statu {
    my $remote_host = $ENV{REMOTE_HOST} || $ENV{REMOTE_ADDR};
    return unless $remote_host;
    my $remote_host_found = 0;
    open STATU_NEW, ">statu.csv~" or return;
    open STATU, "statu.csv";
    while (<STATU>) {
        if (/^$remote_host;(\d+)/) {
            $remote_host_found = 1;
            my $num = $1 + 1;
            print STATU_NEW "$remote_host;$num\n";
        } else {
            print STATU_NEW;
        }
    }
    print STATU_NEW "$remote_host;1\n" unless $remote_host_found;
    close STATU;
    close STATU_NEW;
    rename "statu.csv~", "statu.csv";
}
