#!/usr/bin/perl

#
# Generate docs from ser/sip-router cfg group descriptions
# (run on files generated by gcc -fdump-translation-unit -c file.c,
#  try -h for help)
# E.g.: dump_cfg_defs.pl --file cfg_core.c  --defs="-DUSE_SCTP ..."
#

# Note: uses GCC::TranslationUnit (see cpan) with the following patch:
#@@ -251,6 +251,8 @@
# 	    $node->{vector}[$key] = $value;
# 	} elsif($key =~ /^op (\d+)$/) {
# 	    $node->{operand}[$1] = $value;
#+	} elsif ($key eq "val") {
#+		push @{$node->{$key}}, ($value) ;
# 	} else {
# 	    $node->{$key} = $value;
# 	}
#
#
# Assumptions:
#  - the first array of type cfg_def_t with an initializer is the array
#    with the config definitions (name, type, description a.s.o.). Only
#    one cfg_def array per file is supported.
#  - the first variable of type struct cfg_group_(.*) , with an initializer,
#    contains the default values. If no group name is specified on the
#    command line (--group) the group name is derived from the struct
#    name ($1). The default values are optional. Only one such variable is
#    supported per file.
#  - if the number of the default values is different from the number of
#    elements in the config defs array, the default values are discarded.
#
# Output notes:
#  - range is not printed if min==max==0.
#  - default values are not printed if missing


use strict;
use warnings;
use Getopt::Long;
use File::Temp qw(:mktemp);
use File::Basename;
use GCC::TranslationUnit;

# text printed if we discover that GCC::TranslationUnit is unpatched
my $patch_required="$0 requires a patched GCC:TranslationUnit, see the " .
				"comments at the beginning of the file or try --patch\n";
# gcc name
my $gcc="gcc";
# default defines
my $c_defs="DNAME='\"kamailio\"' -DVERSION='\"5.1.0-dev3\"' -DARCH='\"x86_64\"' -DOS='linux_' -DOS_QUOTED='\"linux\"' -DCOMPILER='\"gcc 4.9.2\"' -D__CPU_x86_64 -D__OS_linux -DSER_VER=5001000 -DCFG_DIR='\"/usr/local/etc/kamailio/\"' -DRUN_DIR='\"/run/kamailio/\"' -DPKG_MALLOC -DSHM_MEM -DSHM_MMAP -DDNS_IP_HACK -DUSE_MCAST -DUSE_TCP -DDISABLE_NAGLE -DHAVE_RESOLV_RES -DUSE_DNS_CACHE -DUSE_DNS_FAILOVER -DUSE_DST_BLOCKLIST -DUSE_NAPT -DMEM_JOIN_FREE -DF_MALLOC -DQ_MALLOC -DTLSF_MALLOC -DDBG_SR_MEMORY -DUSE_TLS -DTLS_HOOKS -DUSE_CORE_STATS -DSTATISTICS -DMALLOC_STATS -DWITH_AS_SUPPORT -DUSE_SCTP -DFAST_LOCK -DADAPTIVE_WAIT -DADAPTIVE_WAIT_LOOPS=1024 -DCC_GCC_LIKE_ASM -DHAVE_GETHOSTBYNAME2 -DHAVE_UNION_SEMUN -DHAVE_SCHED_YIELD -DHAVE_MSG_NOSIGNAL -DHAVE_MSGHDR_MSG_CONTROL -DHAVE_ALLOCA_H -DHAVE_TIMEGM -DHAVE_SCHED_SETSCHEDULER -DHAVE_IP_MREQN -DHAVE_EPOLL -DHAVE_SIGIO_RT -DSIGINFO64_WORKAROUND -DUSE_FUTEX -DHAVE_SELECT";

# file with gcc syntax tree
my $file; #"tcp_options.c.001t.tu" ;
my $tmp_file;
my $src_fname;

# type to look for
my $var_type="cfg_def_t";

my $tu;
my $node;
my $i;
my @cfg_defs; # filled with config var definition (cfg_def_t)
my @cfg_default; # filled with config var defaults
my ($cfg_grp_name, $def_cfg_name, $cfg_var_name);

my ($opt_help, $opt_txt, $opt_is_tu, $dbg, $opt_grp_name, $opt_patch);
my ($opt_force_grp_name, $opt_docbook);

# default output formats
my $output_format_header="HEADER";
my $output_format_footer="FOOTER";
my $output_format_varline="VARLINE2";


sub show_patch
{
my $patch='
--- GCC/TranslationUnit.pm.orig	2009-10-16 17:57:51.275963053 +0200
+++ GCC/TranslationUnit.pm	2009-10-16 20:17:28.128455959 +0200
@@ -251,6 +251,8 @@
 	    $node->{vector}[$key] = $value;
 	} elsif($key =~ /^op (\d+)$/) {
 	    $node->{operand}[$1] = $value;
+	} elsif ($key eq "val") {
+		push @{$node->{$key}}, ($value) ;
 	} else {
 	    $node->{$key} = $value;
 	}
';

print $patch;
}


sub help
{
	#print "Usage: $0 --file fname [--src src_fname] [--txt|-t] [--help|-h]\n";
	$~ = "USAGE";
	write;

format USAGE =
Usage @*  -f filename | --file filename  [options...]
      $0
Options:
         -f        filename    - use filename for input (see also -T/--tu).
         --file    filename    - same as -f.
         -h | -? | --help      - this help message.
         -D | --dbg | --debug  - enable debugging messages.
         -d | --defs           - defines to be passed on gcc's command line
                                 (e.g. --defs="-DUSE_SCTP -DUSE_TCP").
         -g | --grp  name
         --group     name      - config group name used if one cannot be
                                 autodetected (e.g. no default value
                                 initializer present in the file).
         -G | --force-grp name
         --force-group    name - force using a config group name, even if one
                                 is autodetected (see also -g).
         --gcc     gcc_name    - run gcc_name instead of gcc.
         -t | --txt            - text mode output.
         --docbook | --xml     - docbook output (xml).
         -T | --tu             - the input file is in raw gcc translation
                                 unit format (as produced by
                                   gcc -fdump-translation-unit -c ). If not
                                 present it's assumed that the file contains
                                 C code.
         -s | --src | --source - name of the source file, needed only if
                                 the input file is in "raw" translation
                                 unit format (--tu) and useful to restrict
                                 and speed-up the search.
         --patch               - show patches needed for the
                                 GCC::TranslationUnit package.
.

}



# escape a string for xml use
# params: string to be escaped
# return: escaped string
sub xml_escape{
	my $s=shift;
	my %escapes = (
		'"' => '&quot;',
		"'" => '&apos;',
		'&' => '&amp;',
		'<' => '&lt;',
		'>' => '&gt;'
	);

	$s=~s/(["'&<>])/$escapes{$1}/g;
	return $s;
}



# escape a string according with the output requirements
# params: string to be escaped
# return: escaped string
sub output_esc{
	return xml_escape(shift) if defined $opt_docbook;
	return shift;
}



# eliminate casts and expressions.
# (always go on the first operand)
# params: node (GCC::Node)
# result: if node is an expression it will walk on operand(0) until first non
# expression element is found
sub expr_op0{
	my $n=shift;

	while(($n->isa('GCC::Node::Expression') || $n->isa('GCC::Node::Unary')) &&
			defined $n->operand(0)) {
		$n=$n->operand(0);
	}
	return $n;
}



# read command line args
if ($#ARGV < 0 || ! GetOptions(	'help|h|?' => \$opt_help,
								'file|f=s' => \$file,
								'txt|t' => \$opt_txt,
								'docbook|xml' => \$opt_docbook,
								'tu|T' => \$opt_is_tu,
								'source|src|s=s' => \$src_fname,
								'defs|d=s'=>\$c_defs,
								'group|grp|g=s'=>\$opt_grp_name,
								'force-group|force-grp|G=s' =>
													\$opt_force_grp_name,
								'dbg|debug|D'=>\$dbg,
								'gcc=s' => \$gcc,
								'patch' => \$opt_patch) ||
		defined $opt_help) {
	do { show_patch(); exit 0; } if (defined $opt_patch);
	select(STDERR) if ! defined $opt_help;
	help();
	exit((defined $opt_help)?0:1);
}

do { show_patch(); exit 0; } if (defined $opt_patch);
do { select(STDERR); help(); exit 1 } if (!defined $file);

if (defined $opt_txt){
	$output_format_header="HEADER";
	$output_format_footer="FOOTER";
	$output_format_varline="VARLINE2";
}elsif (defined $opt_docbook){
	$output_format_header="DOCBOOK_HEADER";
	$output_format_footer="DOCBOOK_FOOTER";
	$output_format_varline="DOCBOOK_VARLINE";
}

if (! defined $opt_is_tu){
	# file is not a gcc translation-unit dump
	# => we have to create one
	$src_fname=basename($file);
	$tmp_file = "/tmp/" . mktemp ("dump_translation_unit_XXXXXX");
	# Note: gcc < 4.5 will produce the translation unit dump in a file in
	# the current directory. gcc 4.5 will write it in the same directory as
	# the output file.
	system("$gcc -fdump-translation-unit $c_defs -c $file -o $tmp_file") == 0
		or die "$gcc -fdump-translation-unit $c_defs -c $file -o $tmp_file" .
			"  failed to generate a translation unit dump from $file";
	if (system("if [ -f \"$src_fname\".001t.tu ]; then \
					mv \"$src_fname\".001t.tu  $tmp_file; \
				else mv /tmp/\"$src_fname\".001t.tu  $tmp_file; fi ") != 0) {
		unlink($tmp_file, "$tmp_file.o");
		die "could not find the gcc translation unit dump file" .
				" ($src_fname.001t.tu) neither in the current directory" .
				" or /tmp";
	};
	$tu=GCC::TranslationUnit::Parser->parsefile($tmp_file);
	print(STDERR "src name $src_fname\n") if $dbg;
	unlink($tmp_file, "$tmp_file.o");
}else{
	$tu=GCC::TranslationUnit::Parser->parsefile($file);
}

print(STDERR "Parsing file $file...\n") if $dbg;
#
# function_decl: name, type, srcp (source), chan?, body?, link (e.g. extern)
# parm_decl: name, type, scpe, srcp, chan, argt, size, algn, used
# field_decl: name, type, scpe (scope), srcp, size, algn, bpos (bit pos?)
#
# array_type: size, algn, elts (elements?), domn ?
#
#
# name as string $node->name->identifier
#
# E.g.: static cfg_def_t tcp_cfg_def[]= {...}
#                        ^^^^^^^^^^^
#
# @7695 var_decl:  name: @7705   type: @7706    srcp: tcp_options.c:51
#                  chan: @7707    init: @7708    size: @7709
#                  algn: 256      used: 1
#
# @7705 (var name)  	identifier_node strg: tcp_cfg_def lngt 11
# @7706 (var type)  	array_type: size:@7709 algn: 32 elts: @2265 domn: @7718
# @7707 (? next ?  )	function_decl: ....
# @7708 (initializer)	constructor: lngt: 25
#                                    idx : @20      val : @7723    [...]
# @7709             	interget_cst: type: @11 low: 5600
#
# @2265 (array type)	record_type: name: @2256    unql: @2255    size: @2002
#                                    algn: 32       tag : struct   flds: @2263
# @2256 (type)      	type_decl: name: @2264    type: @2265    srcp: cfg.h:73
#                                  chan: @2266
# @2264 (name)     		identifier_node:  strg: cfg_def_t

print(STDERR "Searching...\n") if $dbg;
$i=0;
# iterate on the entire nodes array (returned by gcc), but skipping node 0
SEARCH: for $node (@{$tu}[1..$#{$tu}]) {
	$i++;
	while($node) {
		if (
			@cfg_defs == 0 &&  # parse it only once
			$node->isa('GCC::Node::var_decl') &&
			$node->type->isa('GCC::Node::array_type')  &&
			(! defined $src_fname || $src_fname eq "" ||
				$node->source=~"$src_fname")
			){
			# found a var decl. that it's an array
			# check if it's a valid array type
			next if (!(	$node->type->can('elements') &&
						defined $node->type->elements &&
						$node->type->elements->can('name') &&
						defined $node->type->elements->name &&
						$node->type->elements->name->can('name') &&
						defined $node->type->elements->name->name)
					);
			my $type_name= $node->type->elements->name->name->identifier;
			if ($type_name eq $var_type) {
				#printf "tree[$i]: found var %s %s (%s)\n",
				#		$type_name,
				#		$node->name->identifier,v
				#		$node->source;
				#print ("keys:", join " ", keys %$node, "\n");
				#print ("keys init:", join " ", keys %{$node->initial}, "\n");
				if ($node->can('initial') && defined $node->initial) {
					my %c1=%{$node->initial};
					$cfg_var_name=$node->name->identifier;
					if (defined $c1{val}){
						my $c1_el;
						die $patch_required if (ref($c1{val}) ne "ARRAY");
						# iterate on array elem., level 1( top {} )
						# each element is a constructor
						for $c1_el (@{$c1{val}}) {
							# finally we are a the lower {} initializer
							my %c2=%{$c1_el};
							my @el=@{$c2{val}};
							my ($name_n, $type_n, $min_n, $max_n, $fixup_n,
									$pcbk_n, $desc_n)=@el;
							my ($name, $type, $min, $max, $desc);
							if ($name_n->isa('GCC::Node::integer_cst')){
								printf(" ERROR: integer non-0 name (%d)\n",
										$name_n->low) if ($name_n->low!=0);
								if (@cfg_default > 0){
									last SEARCH; # exit
								}else{
									next; # have to look for defaults too
								}
							}
							$name=expr_op0($name_n)->string;
							$type=$type_n->low;
							$min=$min_n->low;
							$max=$max_n->low;
							$desc=expr_op0($desc_n)->string;
							push @cfg_defs, [$name, $type, $min, $max, $desc];
						}
					}
				}
			}
		}elsif (@cfg_default == 0 && # parse it only once
				$node->isa('GCC::Node::var_decl') &&
				$node->type->isa('GCC::Node::record_type') &&
				(! defined $src_fname || $src_fname eq "" ||
					$node->source=~"$src_fname") &&
				defined $node->type->name->can('identifier') &&
				$node->type->name->identifier=~"cfg_group_([a-z0-9_]+)" &&
				$node->can('initial') && defined $node->initial) {
				my %c1=%{$node->initial};
				if (defined $c1{val}){
					my $c1_el;
					$cfg_grp_name=$1;
					$def_cfg_name=$node->name->identifier;
					print(STDERR "found default cfg: $def_cfg_name,",
								"grp $cfg_grp_name\n") if $dbg;
					die $patch_required if (ref($c1{val}) ne "ARRAY");
					# iterate on array elem.,( top {} )
					# each element is an integer, expr (string pointer) or
					# constructor (str)
					for $c1_el (@{$c1{val}}) {
						if ($c1_el->isa('GCC::Node::integer_cst')){
							push @cfg_default, $c1_el->low;
						}elsif ($c1_el->isa('GCC::Node::constructor')){
							push @cfg_default, "<unknown:str>";
						}else{
							push @cfg_default, expr_op0($c1_el)->string;
						}
					}
					last SEARCH if @cfg_defs > 0; # exit
				}
		}
	} continue {
		if ($node->can('chain')){
			$node = $node->chain;
		}else{
			last;
		}
	}
}

print(STDERR "Done.\n") if $dbg;

my ($name, $flags, $min, $max, $desc);
my ($type, $extra_txt, $default);

if (@cfg_defs > 0){
	my $l;
	my $no=@cfg_default;
	$i=0;
	if ($no > 0 && @cfg_defs != $no) {
		print(STDERR "WARNING: different array lengths ($def_cfg_name($no) &&",
				" $cfg_var_name($(scalar @cfg_defs)))\n");
		$no=0;
	}
	# dump the configuration in txt mode
	if (defined $opt_force_grp_name) {
		$cfg_grp_name=output_esc($opt_force_grp_name);
	}elsif (!defined $cfg_grp_name && defined $opt_grp_name) {
		$cfg_grp_name=output_esc($opt_grp_name);
	}
	$~ = $output_format_header; write;
	$~ = $output_format_varline ;
	for $l (@cfg_defs){
		($name, $flags, $min, $max, $desc)=@{$l};
		$type="";
		$extra_txt="";
		$default= ($no>0) ? output_esc($cfg_default[$i]) : "";

		$i++;
		if ($min==0 && $max==0) {
			$min=""; $max="";
		}
		if ($flags & 8) {
			$type="integer";
		}elsif ($flags & 16) {
			$type="string";
		}elsif ($flags & 32) {
			$type="string"; # str
		}else{
			my $t = $flags & 7;
			$t == 1 && do { $type="integer"; };
			$t == 2 && do { $type="string"; };
			$t == 3 && do { $type="string"; }; # str
			$t == 4 && do { $type=""; }; # pointer
		}

		$extra_txt.="Read-only." if ($flags & 128 );
		$extra_txt=output_esc($extra_txt);
		$desc=output_esc($desc . ".");
		$name=output_esc($name);
		# generate txt description
		write;
	}
	$~ = $output_format_footer; write;
}else{
	die "no configuration variables found in $file\n";
}


sub valid_grp_name
{
	my $name=shift;
	return defined $name && $name ne "";
}


format HEADER =
Configuration Variables@*
(valid_grp_name $cfg_grp_name) ? " for " . $cfg_grp_name : ""
=======================@*
"=" x length((valid_grp_name $cfg_grp_name)?" for " . $cfg_grp_name : "")

@||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
"[ this file is autogenerated, do not edit ]"


.

format FOOTER =
.

format VARLINE =
@>. @<<<<<<<<<<<<<<<<<<< - ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$i, $name,                 $desc
~~                         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                           $desc
~                          Default: @*.
                           $default
~                          Range: @* - @*.
                                  $min, $max
~                          Type: @*. ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                 $type, $extra_txt
~~                         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                           $extra_txt

.

format VARLINE2 =
@>. @*
$i, (valid_grp_name $cfg_grp_name)?$cfg_grp_name . "." . $name : $name
~~      ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        $desc
~       Default: @*.
                 $default
~       Range: @* - @*.
               $min, $max
~       Type: @*. ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
              $type, $extra_txt
~~      ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        $extra_txt

.

format DOCBOOK_HEADER =
<?xml version="1.0" encoding="UTF-8"?>
<!-- this file is autogenerated, do not edit! -->
<!DOCTYPE section PUBLIC "-//OASIS//DTD DocBook XML V4.2//EN"
	"http://www.oasis-open.org/docbook/xml/4.2/docbookx.dtd">
<chapter id="config_vars@*">
(valid_grp_name $cfg_grp_name) ? "." . $cfg_grp_name : ""
	<title> Configuration Variables@*</title>
(valid_grp_name $cfg_grp_name) ? " for " . $cfg_grp_name : ""


.

format DOCBOOK_FOOTER =
</chapter>
.

format DOCBOOK_VARLINE =
<section id="@*">
    (valid_grp_name $cfg_grp_name)?$cfg_grp_name . "." . $name : $name
    <title>@*</title>
    (valid_grp_name $cfg_grp_name)?$cfg_grp_name . "." . $name : $name
    <para>
~~      ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        $desc
    </para>
~   <para>Default value: @*.</para>
        $default
~   <para>Range: @* - @*.</para>
            $min, $max
~   <para>Type: @*.</para>
            $type
    <para>
~~      ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        $extra_txt
    </para>
</section>

.
