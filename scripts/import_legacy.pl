#!/usr/bin/env perl
use strict;
use warnings;

my @posts = (
  'blog/2019/08/11/5-types-of-nonsense-data-science/index.html',
  'blog/2020/08/04/hello-world-in-pytorch-biggraph/index.html',
  'blog/2020/09/07/embedding-sets-of-vectors-with-emde/index.html',
);

for my $path (@posts) {
  open my $git, '-|', 'git', 'show', "master:$path" or die "git show: $!";
  local $/;
  my $html = <$git>;
  close $git or die "Could not read $path\n";

  my ($title) = $html =~ m{<h1 class="entry-title">(.*?)</h1>}s;
  my ($date) = $html =~ m{<time class='entry-date' datetime='([^']+)'};
  my ($body) = $html =~ m{<div class="entry-content">(.*?)</div>\s*(?:<head>|<footer>)}s;
  die "Could not parse $path\n" unless $title && $date && $body;
  $title =~ s/^\s+|\s+$//g;
  $title =~ s/&quot;/"/g;
  $title =~ s/&#39;/'/g;
  $title =~ s/&amp;/&/g;
  $title =~ s/"/\\"/g;

  my (undef, $year, $month, $day, $slug) = split '/', $path;
  my $output = "content/posts/$year-$month-$day-$slug.html";
  open my $out, '>', $output or die "$output: $!";
  print {$out} qq{---\ntitle: "$title"\ndate: "$date"\nslug: "$slug"\n---\n$body\n};
  close $out;
  print "Recovered $output\n";
}
