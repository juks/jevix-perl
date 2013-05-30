package Jevix::Makeup;

# ==========================================
#
#  Jevix Version 0.9.7 (windows-1251)
#
#  Developed by Igor Askarov
# 
#  Please send all suggestions to
#  Igor Askarov <juks@juks.ru>
#  http://www.jevix.ru/
#
#  Release date: 20/12/2008
#
# === Methods list==========================
#
#  new							the constructor
#  procces						entry sub
#  setConf						setting up the configuration
#  preset						presets selector
#  makeup						makeup the text
#  quotes						quotes processor
#  cuttags						tags processor
#  tagEnd						looking fo tag end
#  plantTags						sub to bring the tags back
#  vanish						sub to remove all the stuff and bring the text to plain mode
#  parseTagsAllowString					parse the tagsAllow string to hash
#  parseTagsDenyString					parse the tagsDeny string to hash
#  getConf						return configuration hash
#
# ==========================================

use strict;
use warnings;

my $markLength = 8;
my $strip;
my $result;
my $tags;
my @tagsOpen;
my $conf;

my @singleTags = qw/link input spacer img br hr/;
my @breakingTags = qw/p td div hr/;
my @spaceTags = qw/br/;
my @tagsToEat = qw/script style pre code/;

# ==The constructor
sub new {
	my Jevix::Makeup $class = shift;
	
	return $class;
}

# ==Here we've got the input
sub process($$$) {
	my($class, $text, $userConf) = @_;
		
	# If there is a configuration given we set it here
	$class->setConf($userConf) if($userConf);
	
	$strip = "";
	$tags = [];
	@tagsOpen = ();
	
	$result = {};
	$result->{error} = 0;
	$result->{errorLog} = [];

	if($conf->{vanish}) {
		$class->cuttags($text, {tagsDenyAll=>1}, $result);
		$class->vanish(\$strip);
		$result->{text} = $strip;
	} else {
		if(!$conf->{isHTML}) { $strip = $$text; } else { $class->cuttags($text, $conf, $result); }
		if($conf->{quotes}) { $class->quotes($conf); }
		$class->makeup($conf);

		$result->{text} = "";
		if($conf->{isHTML}) { $class->plantTags($result); } else { $result->{text} = $strip; }
	}

	return $result;
}

# ==Setting the configuration
sub setConf($$) {
	my($class, $userConf) = @_;

	$conf = $userConf ? $userConf : {presetBasic=>1};
	$class->preset();
}

# ==Choosing default setup when necessary
sub preset($$) {
	my ($class) = @_;

	if(!$conf || $conf->{presetBasic}) {
		$conf->{isHTML} = 1 if(!defined($conf->{isHTML}));								# HTML mode
		$conf->{lineBreaks} = 1 if(!defined($conf->{lineBreaks}));						# Linebreaks to <br/>
		$conf->{paragraphs} = 0 if(!defined($conf->{paragraphs}));						# Paragraphs
		$conf->{dashes} = 1 if(!defined($conf->{dashes}));								# Replace hyphens with dashes when necessary
		$conf->{dots} = 1 if(!defined($conf->{dots}));										# Replace 3 dots with a symbol
		$conf->{edgeSpaces} = 1 if(!defined($conf->{edgeSpaces}));						# Wipe edge space characters
		$conf->{multiSpaces} = 1 if(!defined($conf->{multiSpaces}));						# Wipe multispaces
		$conf->{redundantSpaces} = 1 if(!defined($conf->{redundantSpaces}));				# Wipe redundant spaces
		$conf->{compositeWordsLength} = 10 if(!defined($conf->{compositeWordsLength}));		# The maximim length of composite word to be put inside <nobr>
		$conf->{tagLf} = 1 if(!defined($conf->{tagLf}));								# Wipe crs and lfs after droppped tag
		$conf->{nbsp} = 1 if(!defined($conf->{nbsp}));										# Insert non-breaking spaces
		$conf->{quotes} = 1 if(!defined($conf->{quotes}));								# Makeup quotes
		$conf->{qaType} = 0 if(!defined($conf->{qaType}));								# Main quotes type
		$conf->{qbType} = 2 if(!defined($conf->{qbType}));								# Nested quotes type
		$conf->{misc} = 1 if(!defined($conf->{misc}));										# Misc substitutions
		$conf->{codeMode} = 2 if(!defined($conf->{codeMode}));								# The way jevix should represent html special characters
	}

	# If tagsAllow came as a string
	if(defined($conf->{tagsAllow}) && !ref($conf->{tagsAllow})) {
		my $tmp = $class->parseTagsAllowString($conf->{tagsAllow});
		$conf->{tagsAllow} = $tmp->{tagsAllow};
		$conf->{tagsDenyAllAttributes} = $tmp->{tagsDenyAllAttributes};
	}

	# If tagsDeny came as a string
	if(defined($conf->{tagsDeny}) && !ref($conf->{tagsDeny})) {
		$conf->{tagsDeny} = $class->parseTagsDenyString($conf->{tagsDeny});
	}
}

# ==Imposing clear text
sub makeup($$) {
	my ($class, $conf) = @_;
	
	# ==Misc
	# Prepositions
	my $prp_rus = "а|без|безо|в|вне|во|да|дл€|до|за|и|из|изо|или|к|как|на|над|надо|не|ни|но|о|об|обо|около|от|ото|по|под|подо|при|про|с|сквозь|со|у|через";
	my $prp_eng = "aboard|about|above|absent|across|after|against|along|alongside|amid|amidst|among|amongst|around|as|astride|at|atop|before|behind|below|beneath|beside|besides|between|beyond|but|by|despite|down|during|except|following|for|from|in|inside|into|like|mid|minus|near|nearest|notwithstanding|of|off|on|onto|opposite|out|outside|over|past|re|round|save|since|than|through|throughout|till|to|toward|towards|under|underneath|unlike|until|up|upon|via|with|within|without";
	my $prp = "$prp_rus|$prp_eng";

	my $letters = "A-Za-zј-яа-€®Є…й";				 # Characters
	my $cap_letters = "A-Zј-я®Є";								 # Capital characters

	my $sp = " \xA0\t";														   # space class
	my $rt = "\r?\n";																 # cr class

	my $br = "\x00\x0F..[\x01\x03].\x0F\x00";				 # br tag
	my $pt = "\x00\x0F..[\x02].\x0F\x00";						 # Paragraph tag
	my $ps = "\x00\x0F..[\x02][\x01\x03]\x0F\x00";		# Paragraph start
	my $pe = "\x00\x0F..[\x02][\x02\x00]\x0F\x00";		# Paragraph end
	my $to = "\x00\x0F...[\x03\x01]\x0F\x00";				 # Opening tag
	my $tc = "\x00\x0F...[\x02\x00]\x0F\x00";				 # Closing tag
	my $bb = "\x00\x0F...[\x02\x03]\x0F\x00";				 # Tag where <nobr> is open
	my $nb = "\x00\x0F...[\x01\x00]\x0F\x00";				 # Tag where no <nobr> is open
	my $ao = "\x00\x0F[\x01]...\x0F\x00";						# Tag where <a> is open
	my $ac = "\x00\x0F[\x00]...\x0F\x00";						# Tag where no <a> is open				
	my $ts = "\x00\x0F";														  # Tag start
	my $te = "\x0F\x00";														  # Tag end

	my $brt = "<br *\/?>";														# br tag in text mode
	my $pst = "<p>";
	my $pet = "</p>";

	# Codes, metasymbols or what ever?
	my ($cdash, $cnbsp, $cdots, $cfracs, $ccopy, $creg);

	if(!$conf->{codeMode}) {
		($cdash, $cnbsp, $cdots, $ccopy, $creg) = ("Ч", "†", "Е", "©", "Ѓ");
		$cfracs = {'1/4'=>"?", '1/2'=>"?", '3/4'=>"?"};
	} elsif($conf->{codeMode} == 1) {
		($cdash, $cnbsp, $cdots, $ccopy, $creg) = ("&#151;", "&#160;", "&#133;", "&#169;", "&#174;");
		$cfracs = {'1/4'=>"&#188;", '1/2'=>"&#189;", '3/4'=>"&#190;"};
	} else {
		($cdash, $cnbsp, $cdots, $ccopy, $creg) = ("&mdash;", "&nbsp;", "&hellip;", "&copy;", "&reg;");
		$cfracs = {'1/4'=>"&frac14;", '1/2'=>"&frac12;", '3/4'=>"&frac34;"};
	}

	# Wiping edge spaces
	if($conf->{edgeSpaces}) { $strip =~ s/^[$sp\r\n]*(.+?)[$sp\r\n]*$/$1/isg; }

	# Wiping spaces between tags (</td> </tr>)
	if($conf->{tagSpaces}) { $strip =~ s/($tc)[$sp]($tc)/$1$2/isg; }

	# Wiping multispaces
	if($conf->{multiSpaces}) { $strip =~ s/([$sp]){2,}/$1/ig; }

	# Wiping redundant spaces
	if($conf->{redundantSpaces}) { $strip =~ s{([$sp]+(?![:;]-[)(])([;:,.)?!]))|(\()(?<![:%;]-\()[$sp]+}{$1 ? $2 : $3}eig; } 

	if($conf->{nbsp}) {
		# Prepositions with &nbsp;
		$strip =~ s/(^|\x00|[$sp])($prp)[$sp]([0-9$letters])/$1$2$cnbsp$3/gm;

		# &nbsp; with digits
		$strip =~ s{($nb|^)(.*?)($bb|$)}{ my ($a, $b, $c) = ($1, $2, $3); $b =~ s/([0-9]+)([$sp]+|&nbsp;|&#160;)(?:(?=[0-9]{2,})|(?=%))/$1$cnbsp/ig; "$a$b$c"; }eisg;
	}		
	
	# Put composite words inside <nobr>
	if($conf->{compositeWords}) { $strip =~ s{($nb|^)(.*?)($bb|$)}{ my ($a, $b, $c) = ($1, $2, $3);
											$b =~ s{(^|[$sp\x00]|&nbsp;)([$letters]+(?:-[$letters]+)+)(?=$|[$sp\x00])}{
															my $d = !defined($1) ? "" : $1; my $e = !defined($2) ? "" : $2; my $f = !defined($3) ? "" : $3;
															if(length($e) <= $conf->{compositeWordsLength}) { "$d<nobr>$e<\/nobr>" } else {"$d$e$f"}
													}eig; "$a$b$c";
											}eisg; }
											
	# Links
	if($conf->{links}) {
		my $lAttributes = '';

		# Building <a> attributes string
		if($conf->{linksAttributes}) {
			my $q = !$conf->{tagUnQuoteValues} ? '"' : '';

			while (my ($attr, $value) = each(%{$conf->{linksAttributes}})) {
				$lAttributes .= ' ' if($lAttributes);
				$lAttributes .= "$attr=$q$value$q";
			}

			$lAttributes = ' ' . $lAttributes if($lAttributes);
		}

		$strip =~ s{(^|$ac|(?<=</a>))([^\x00]*?)(http://[^ \x00]+)(?<![,.!?])}{$1$2<a href="$3"$lAttributes>$3</a>}ig;
	}

	# Dots
	if($conf->{dots}) { $strip =~ s/\.{3}|Е|&hellip;/$cdots/ig; }

	# Dashes
	if($conf->{dashes}) {
		# Hyphen
		$strip =~ s/([^$sp])([$sp]|&#160;|&nbsp;)(-{1,2}|Ч|&mdash;|&#151;)/$1$cnbsp$cdash/ig;
		# "Speech" hyphen
		$strip =~ s/((?:^|$ps|$br|$brt(?:$rt)*|[$rt]))[$sp]*(?:&nbsp;)*(-{1,2}|Ч|&mdash;|&#151;)[$sp]*(?:&nbsp;)*(.)/$1$cdash$cnbsp$3/ig;
	}

	# Misc stuff
	if($conf->{misc}) {
		# Fracs
		$strip =~ s{(?:(?<=[$sp\x00])|(?<=^))([13])/([24])(?:(?=[$sp\x00])|(?=$))}{if(defined($cfracs->{"$1/$2"})) { $cfracs->{"$1/$2"} } else { "$1/$2" } }esg;
		# Copyright & registered
		$strip =~ s{(?:(?<=[$sp\x00])|(?<=^))(\([cr]\)|&copy;|©)(?:(?=[$sp\x00?!;.,])|(?=$))}{ if((lc($1) eq "(c)") || (lc($1) eq "&copy;") || ($1 eq "©")) {$ccopy} elsif((lc($1) eq "(r)") || (lc($1) eq "&reg;") || ($1 eq "Ѓ")) {$creg} else { $2 } }eig;
	}
	
	# Paragraphs
	if($conf->{paragraphs}) { $strip =~ s{(^|$pe(?:$rt$rt)?|$rt$rt)(?!$ps)(.+?)($br)?($brt)?(?<!$pe)(?:(?=$)|(?=$rt$rt)|(?=$ps))}{ my ($a, $b, $c) = ($1,$2,$3||""); (($b =~ /^[ \r\n]+$/) || ($b =~ /^(<br *\/?>|$br)+$/)) ? "$a$b$c" : "$a<p>$b</p>";}eisg; }

	# Line break
	if($conf->{lineBreaks}) { $strip =~ s/(?<!$pt)(?<!$br)(?<!$br\r)(?<!$pe\r\n\r\n)(?<!$pe\n\n)(?<!$pe\r\n)(?<!$pe\n)(?<!$pe\r)(?<!$pe)(?<!$pet\r\n\r\n)(?<!$pet\r\n\r)(?<!$pet\n\n)(?<!$pet\r\n)(?<!$pet\n)(?<!$pet\r)(?<!$pet)(?<!$pst)($rt)(?!$brt)(?!$ts)/<br \/>$1/isg; }
}

# ==impose quotes
sub quotes($$) {
	my ($class, $conf) = @_;

	my $i;
	my ($a_open, $b_open) = (0,0);
	my ($cp, $c, $cn, $cn_is_sp, $cp_is_sp) = ('', '', '', 0, 0);
	my ($qaStart, $qaEnd, $qbStart, $qbEnd);
	my (@qs, @qe, @qs_ansi, @qe_ansi, @qs_html, @qe_html, @qs_ent, @qe_ent,);

	# space class
	my $sp =" \t\xA0";

	# characters
	my $letters = "A-Za-zј-яа-€®Є…й";

	@qs_ansi = ("Ђ", "У", "Д", "С", "В", '"');		
	@qe_ansi = ("ї", "Ф", "У", "Т", "С", '"');
	@qs_html = ("&#171;", "&#147;", "&#132;", "&#145;", "&#130;", "&#34;");
	@qe_html = ("&#187;", "&#148;", "&#147;", "&#146;", "&#145;", "&#34;");
	#				<<				``				..				`				.				"
	@qs_ent = ("&laquo;",		"&ldquo;",		"&bdquo;",		"&lsquo;",		"&sbquo;",		"&quot;");		
	#				>>				''				''				'				`				"
	@qe_ent = ("&raquo;", 		"&rdquo;", 		"&ldquo;", 		"&rsquo;", 		"&lsquo;", 		"&quot;");

	# Quotes collection
	if(!$conf->{codeMode}) {
		@qs = @qs_ansi; @qe = @qe_ansi;
	} elsif ($conf->{codeMode} == 1) {
		@qs = @qs_html; @qe = @qe_html;
	} else {
			@qs = @qs_ent; @qe = @qe_ent;
	}
	
	# Getting configuration setting
	$conf->{qaType} ||= 0;
	$conf->{qbType} ||= 1;
	$conf->{qaType} = ($conf->{qaType} >= 0 && $conf->{qaType} <= 5) ? $conf->{qaType} : 0;
	$conf->{qbType} = ($conf->{qbType} >= 0 && $conf->{qbType} <= 5) ? $conf->{qbType} : 1;

	# Selecting quotes as requested by user
	($qaStart, $qaEnd) = ($qs[$conf->{qaType}], $qe[$conf->{qaType}]);
	($qbStart, $qbEnd) = ($qs[$conf->{qbType}], $qe[$conf->{qbType}]);
	
	# Resetting all the quotes inside text to <">
	my $qa = join('|', @qs_ansi) . '|' . join('|', @qe_ansi) . '|' . join('|', @qs_html) . '|' . join('|', @qe_html) . '|' . join('|', @qs_ent) . '|' . join('|', @qe_ent);
	$strip =~ s/(?:(?:(?<=[^$letters])|(?<=^))($qa))|(?:($qa)(?:(?=[^$letters])|(?=$)))/\"/ig;
	
	my $spread = 1;
	my $mv = 0;
	my $mvn = 0;
	my @st;
	$i = 0;
	my $skip = 0;
	my @space;				  # Space tags flag
	my @break;				  # Text break flags
	
	$st[$_] = '' foreach(0..$spread + 1);
	$space[$_] = 0 foreach(0 + 1..$spread + 1);
	$break[$_] = 0 foreach(0 + 1..$spread + 1);
	$space[0] = 1;
	$break[0] = 1;

	while(1) {
		# Skipping tags
		foreach(0..$spread) {
			do {
				$skip = 0;
				if($i + $_ + $mv <= length($strip)) {
					if($i + $_ + $mv + 1 < length($strip)) {
						if((substr($strip, $i + $_ + $mv, 1) eq "\x00") && (substr($strip, $i + $_ + $mv + 1, 1) eq "\x0F")) {
							$space[$_ + 1] |= (ord(substr($strip, $i + $_ + $mv + 3, 1)) & 2) >> 1;
							$break[$_ + 1] |= ord(substr($strip, $i + $_ + $mv + 3, 1)) & 1;
							$mv += $markLength;
							if(!$_) { $mvn = $mv; }
							$st[$_ + 1] = "";
							$skip = 1;
						}
					}
					if(!$skip) { $st[$_ + 1] = substr($strip, $i + $_ + $mv, 1); }
				} 
			} while($skip);
		}
		
		$i += $mvn;
		$mv = 0;
		$mvn = 0;

		($cp, $c, $cn) = ($st[0], $st[1], $st[2]);
		$cp_is_sp = (($cp =~ /[^0-9$letters]/) || $space[0] || $space[1] || $break[0] || !$i) ? 1 : 0;
		$cn_is_sp = (($cn =~ /[^0-9$letters]/) || $space[2] || $break[2] || $cn eq '') ? 1 : 0;

		# Reset state if breaking tag appears
		if($break[1] || $i == length($strip)) {
			if($a_open || $b_open) {
				# Log quote error if appears
				if($conf->{logErrors}) {
					my $quoteErrSampleLength = 100;
					my $z = $i - 1;
					my $y;
					while(1) {
						if(substr($strip, $z, 1) eq " " || substr($strip, $z, 1) eq "\xA0" || !$z) { if($i-$z <= $quoteErrSampleLength) {$y = $z}}
						last if(!$z);
						$z--;
					}
					my $sample = substr($strip, $y, ($i - $y));
					$sample =~ s/\x00\x0F[^\x0F]+\x0F\x00//g;
					$sample =~ s/<\/?[a-z]+.*?>//g;
					push(@{$result->{errorLog}}, {type=>"Quote_error", message=>"Quote mismatch near [$sample]<--"});
					$result->{error} = 1;
				}
			}
	
			$a_open = 0;
			$b_open = 0;
		}

	if($c eq '"') {
		if(!$a_open) {
			$a_open = 1;
			substr($strip, $i, 1) = $qaStart;
			$i += length($qaStart) - 1;
		} elsif ($a_open && (($i == length($strip) - 1) || (!$b_open && $cn_is_sp))) {
			$a_open = 0;
			substr($strip, $i, 1) = $qaEnd;
			$i += length($qaEnd) - 1;
		} elsif ($a_open && !$b_open) {
			$b_open = 1;
			substr($strip, $i, 1) = $qbStart;
			$i += length($qbStart) - 1;
		} elsif ($a_open && $b_open) {
			$b_open = 0;
			substr($strip, $i, 1) = $qbEnd;
			$i += length($qbEnd) - 1;
		}
	}
	
		last if($i == length($strip));
		
		$st[0] = $st[1];
		$space[0] = $space[1];
		$break[0] = $break[1];
		$space[$_] = 0 foreach(0 + 1..$spread + 1);
		$break[$_] = 0 foreach(0 + 1..$spread + 1);
		$i++;
	}
}

# ==Cutting the tags away
sub cuttags($$$$) {
		my($class, $text, $conf, $result) = @_;
		
		# loop counter
		my $i = 0;
		# Jump length
		my $hop;
		# current & next character
		my ($c, $cn);
		# tag length, tag dimensions, tag name, tag body text, single tag flag, content inside the tag
		my ($tl, $ts, $te, $cl, $tagName, $tagBody, $tagContent);
		# some useful flags
		my ($isTag, $isTagStart, $isSingle, $isSingleClosed, $isSpace, $isBreaking, $nobrIsOpen, $aIsOpen, $flagSet3, $flagSet2, $flagSet1, $flagSet0);
		
		# space class
		my $sp =" \t\xA0";

		while(1) {
			$hop = index($$text, "<", $i);

			if($hop < 0) {
				$strip .= substr($$text, $i, length($$text) - $i);
				last;
			} elsif($hop > 0) {
				$strip .= substr($$text, $i, $hop - $i);
				$i = $hop;
			}

			($c, $cn) = unpack("aa", substr($$text, $i, 2));
		
			$isTag = 0;

			# =If tag opens
			$isTagStart = ($cn =~ /!|[a-z]/i) ? 1 : 0;
			if($isTagStart || ($cn eq "/")) { $isTag = 1; }

			if($isTag) {
				$ts = $i;																		# Tag start position 
				$te = $isTagStart ? tagEnd($text, $ts) : index($$text, ">", $ts);				# Tag end position

				if($te) {
					$tagBody = substr($$text, $ts, $te - $ts + 1);
					$tagName = $isTagStart ? ($tagBody =~ m/^<([a-z0-9]+)/i)[0] : ($tagBody =~ m/^<\/\s*([a-z]+)/i)[0];
					$tagName =~ tr/A-Z/a-z/;
				}

				if($te && $tagName) {
					# =Flags
					# Detecting whether the tag is single (self-closing) or double
					$isSingleClosed = 0;
					$isSingle = 0;
	
					if($isTagStart) {
						if(grep{$tagName eq $_} @singleTags) {
							$isSingle = 1;
						} elsif (substr($tagBody, length($tagBody) - 2, 1) eq "/") {
							$isSingle = 1;
							$isSingleClosed = 1;
						}
					}
	
					# Detecting wether this is space tag or not
					$isSpace = (grep{$tagName eq $_} @spaceTags) ? 1 : 0;
					
					# Detecting wether this is breaking tag or not
					$isBreaking = (grep{$tagName eq $_} @breakingTags) ? 1 : 0;
					
					# Tag Length
					$tl = $te - $ts + 1;
	
					# Updating the status for tags open
					if(($conf->{checkHTML} || $conf->{tagCloseOpen}) && !$isSingle) {
						if($isTagStart) {
							push(@tagsOpen, $tagName);
						} else {
							if($tagsOpen[$#tagsOpen] ne $tagName) {
								# HTML error
								$result->{error} = 1;
								if($conf->{logErrors}) { push(@{$result->{errorLog}}, {type=>"HTML_Parse", position=>$i, message=>"Found closing tag <$tagName> while waiting tag <" . $tagsOpen[$#tagsOpen] . "> to close!"}); }
							} else {
								pop(@tagsOpen);
							}
						}
					}
	
					# Eating tag content for some tags like <script>
					$tagContent = "";
					$cl = 0;
					if((grep{$tagName eq $_} @tagsToEat) && $isTagStart) {
						$cl = index($$text, "</$tagName>", $ts + $tl) - $ts - $tl;
						if($cl > 0) {
							$tagContent = substr($$text, $ts + $tl, $cl);
						} else {
							$cl = 0;
							$result->{error} = 1;
							
							if($conf->{logErrors}) { push(@{$result->{errorLog}}, {type=>"HTML_Parse", position=>$i, message=>"Can't find <$tagName> end!"}); }
						}
					}
	
					# Should I drop all the tags by default?
					my $dropTag = 0;
					if($conf->{tagsDenyAll} || $conf->{simpleXSS} && $tagName eq 'script') { $dropTag = 1; }
					
					# Checking deny list
					if(!$dropTag && defined($conf->{tagsDeny})) {
						if($conf->{tagsDeny}->{$tagName}) { $dropTag = 1; }
					}
	
					# Checking allow list
					if(defined($conf->{tagsAllow}) && $dropTag) {
						if($conf->{tagsAllow}->{$tagName}) { $dropTag = 0; }
					}
	
					# Nobr tag status
					if($tagName eq "nobr" && $isTagStart) {
						$nobrIsOpen = 1;
					} elsif(($tagName eq "nobr" && !$isTagStart) || (grep{$tagName eq $_} @breakingTags)) {
						$nobrIsOpen = 0;
					}
	
					# A tag status
					if($tagName eq "a" && $isTagStart) {
						$aIsOpen = 1;
					} elsif(($tagName eq "a" && !$isTagStart) || (grep{$tagName eq $_} @breakingTags)) {
						$aIsOpen = 0;
					}
	
					# =Final part
					if(!$dropTag) {
						# =Processing tags
						# Tag name to lower case
						if($conf->{tagNamesToLower}) {
							if($isTagStart) { $tagBody = "<" . $tagName . substr($tagBody, length($tagName) + 1, length($tagBody) - length($tagName) - 1); }
							else { $tagBody =~ tr/A-Z/a-z/; }
						}
		
						# Tag name to upper case
						if($conf->{tagNamesToUpper}) {
							if($isTagStart) { $tagBody = "<" . uc($tagName) . substr($tagBody, length($tagName) + 1, length($tagBody) - length($tagName) - 1); }
							else { $tagBody =~ tr/a-z/A-Z/; }
						}
		
						# =Tag parameters to lower or upper case
						if($isTagStart && ($conf->{tagAttributesToLower} || $conf->{tagAttributesToUpper})) {
							# Regular parameters
							my $tmp = "";
							
							while ($tagBody =~ m/([^\s]*\s*)(?:([a-z\r]+)(\s*)(?==)(=\s*))?/ig ) {
								$tmp .= $1 if ($1); if($conf->{tagAttributesToLower}) { if($2) { $tmp .= lc($2); } } else { if($2) { $tmp .= uc($2); } } $tmp .= $3 if ($3); $tmp .= $4 if ($4); $tmp .= $5 if ($5);
							}
	
							# Single parameters (like <checked>)
							if($conf->{tagAttributesToLower}) { $tagBody =~ s{(?<!=)( +([a-z]+))}{lc($1)}eig; }
							elsif($conf->{tagAttributesToUpper}) { $tagBody =~ s{(?<!=)( +([a-z]+))}{uc($1)}eig; }
						}
		
						# Simple XSS & tag attributes protection
						if($isTagStart && ($conf->{simpleXSS} || $conf->{tagsAllow}->{$tagName}->{validAttributes} || $conf->{tagsAllow}->{$tagName}->{invalidAttributes} || $conf->{tagsAllow}->{$tagName}->{denyAllAttributes} || $conf->{tagsDenyAllAttributes})) {
							$tagBody =~ s{(?<!<)(\s*)([a-z]+)([$sp]*=[$sp]*)("[^"]+"|[^$sp/>]+)} {
								my ($a, $b, $c, $d) = ($1||'', lc($2), $3, $4);
								if($conf->{simpleXSS} && ($b =~ /^on/ig || $d =~ /javascript|expression/ig)) {
								'';
								} elsif(($conf->{tagsDenyAllAttributes} || $conf->{tagsAllow}->{$tagName}->{denyAllAttributes} || ($conf->{tagsAllow}->{$tagName}->{invalidAttributes} && $conf->{tagsAllow}->{$tagName}->{invalidAttributes}->{$b}))
																		&& !(($conf->{tagsAllow}->{$tagName}->{validAttributes} && $conf->{tagsAllow}->{$tagName}->{validAttributes}->{$b})
																		|| $conf->{tagsAllow}->{$tagName}->{allowAllAttributes})
										) {
								'';
														} elsif($conf->{tagsAllow}->{$tagName}->{validAttributes} && !$conf->{tagsAllow}->{$tagName}->{validAttributes}->{$b}) {
								'';
								} else {
								$a . $b . $c . $d;
								}
							}eig;						
					}
	
					# Close single tag
					if($conf->{tagCloseSingle} && $isSingle && !$isSingleClosed) {
						if(substr($tagBody, length($tagBody) - 2, 1) ne "/") {
							if(substr($tagBody, length($tagBody) - 2, 1) ne " ") { substr($tagBody, length($tagBody) - 2, 1) .= " /"; } else { substr($tagBody, length($tagBody) - 2, 1) .= "/"; }
						}
					}
	
					# Quote attribute values
					if($conf->{tagQuoteValues} && $isTagStart) {
						my $tmp = "";
						#						1			   23  4		5		6
						while($tagBody =~ m/([<a-z0-9 >]+)?((=)(\s*)([^ >]+)([ >]+))?/ig) {
							$tmp .= $1 if($1);
							if($2) {
								$tmp .= $3 if($3);
								$tmp .= $4 if($4);
								if($5 && substr($5, 0, 1) ne '"' && substr($5, length($5) - 1, 1) ne '"') { $tmp .= "\"$5\""; } else { $tmp .= $5; }
								$tmp .= $6 if($6);
							}
						}
						
						$tagBody = $tmp;
					}
	
					# Unquote attribute values
					if($conf->{tagUnQuoteValues}) {
						$tagBody =~ s/([a-z]+)(\s*)(=)(\s*)"([^\=\s">]+)"/$1$2$3$4$5/ig;   #"
					}
   
					# Saving the tag
					push(@$tags, {name=>$tagName, body=>$tagBody, content=>$tagContent});
			
					# Forming flagSet
					#
					# byte3: _ _ _ _ _ _ _ isHref | byte2: _ _ _ _ _ _ isSpace isBreaking| byte1: _ _ _ _ _ p br| byte0: _ _ _ _ nobr isTagStart
					$flagSet3 = 0;
					if($aIsOpen) { $flagSet3 |= 1; }
					$flagSet2 = 0;
					if($isSpace) { $flagSet2 |= 2; }
					if($isBreaking) { $flagSet2 |= 1; }
					$flagSet1 = 0;
					if($tagName eq "br") { $flagSet1 |= 1; }
					if($tagName eq "p") { $flagSet1 |= 2; }
					$flagSet0 = 0;
					if($isTagStart) { $flagSet0 |= 1; }
					if($nobrIsOpen) { $flagSet0 |= 2; }
					
					# Planting the marker
					$strip .= "\x00\x0F" . chr($flagSet3) . chr($flagSet2) . chr($flagSet1) . chr($flagSet0) . "\x0F\x00";
				}
				
				# Moving the pointer (tag end position + content length)
				$i = $te + $cl;

				# Eating crs & lfs after dropped tag
				if($conf->{tagLf} && $dropTag) {
					while(1) {
						if(substr($$text, $i + 1, 1) eq "\r") { $i++; } elsif(substr($$text, $i + 1, 1) eq "\n") { $i++; last; } else { last }
					}
				}
			}
		} else {
			# This is not a tag, just add the "<" to result
			$strip .= $c;
		}
		
		last if($i == length($$text));
		$i++;
	}
	
	# Need to close all the open tags in the order of appearance
	if($conf->{'closeOpenTags'} && scalar @tagsOpen) {
		while(my $tag = pop @tagsOpen) {
			
		}
	}
}

# ==Find where tag ends
sub tagEnd($$$) {
		my ($text, $i) = @_;
		
		my $gotcha = 0;
		my $quote = 0;
		
		$i |= 0;
		
		while (1) {
			if (substr($$text, $i, 1) eq '"') { $quote ^= 1; }
			if (!$quote && substr($$text, $i, 1) eq '>') { $gotcha = $i; }
			last if ($i == length($$text) || $gotcha);

			$i++;
		}
		
	return $gotcha;
}

# ==Bring everything back to HTML
sub plantTags($$) {
	my ($class, $result) = @_;
	my $i = 0;
	my $max = length($strip);
	my $ctag = 0;
	my $step;

	while (1) {
		if($i < $max - 2 && substr($strip, $i, 2) eq "\x00\x0F") {
			$result->{text} .= $$tags[$ctag]->{body};
			if($$tags[$ctag]->{content}) { $result->{text} .= $$tags[$ctag]->{content}; }
			$i += $markLength;
			$ctag++;
		} else {
			if($i < $max - 2) { $step = index($strip, "\x00\x0F", $i) - $i; } else { $step = $max - $i; }
			if($step < 0) { $step = $max - $i; }
			
			if($step >= 0) {
				$result->{text} .= substr($strip, $i, $step);
				$i += $step;
			}
		}
	
		last if($i == $max);
	}

	# Should we close open tags?
	if($conf->{tagCloseOpen} && scalar @tagsOpen) {
		my $closeString;

		while(my $tag = pop @tagsOpen) {
			if($conf->{tagNamesToUpper}) { $tag = uc($tag); }
			$closeString .= '</' . $tag .'>';
		}
		
		if($closeString) { $result->{text} .= $closeString; }
	}
}

# ==Bring the text to plain mode==
sub vanish($$) {
	my($class, $text) = @_;

	$$text =~ s/&laquo;|&ldquo;|&bdquo;|&lsquo;|&sbquo;|&quot;|&raquo;|&rdquo;|&ldquo;|&rsquo;|&#171;|&#147;|&#132;|&#145;|&#130;|&#34;|&#187;|&#148;|&#146;|Ђ|У|Д|С|В|"|ї|Ф|Т/"/ig;
	$$text =~ s/&nbsp;|&#160;|†/ /ig;
	$$text =~ s/&mdash;|&ndash;|&#151;|&#150;|Ч|Ц/-/ig;
	$$text =~ s/&hellip;|&#133;|Е/.../ig;
	$$text =~ s/&copy;|&#169;|©/(c)/ig;
	$$text =~ s/&reg;|&#174;|Ѓ/(r)/ig;
	$$text =~ s/&frac14;|&#188;/1\/4/ig;
	$$text =~ s/&frac12;|&#189;/1\/2/ig;
	$$text =~ s/&frac34;|&#190;/3\/4/ig;
}

# ==Parse the tagsAllow string advanced format==
sub parseTagsAllowString($$) {
	my($class, $string) = @_;

	return {tagsAllow=>{}, tagsDenyAllAttributes=>0} if(!$string);

	my $tagsAllow = {};
	my $tagsDenyAllAttributes = 0;

	# Should I deny all tag attributes by default?
	if(substr($string,0,1) eq '|') {
		$tagsDenyAllAttributes = 1;
		substr($string,0,1) = '';
	};
	
	# Parsing the Configuration String
	while($string =~ /([a-z:|]+)/ig) {
		my $tBody = $1;
		my ($tagName) = lc(($tBody =~ /^([a-z]+)/i)[0]);
		
		last if(!$tagName);
		
		my $attrList = ();
		$tagsAllow->{$tagName}->{val}=1;
		
		if($tBody =~ /^$tagName\|$/i) {
			$tagsAllow->{$tagName}->{denyAllAttributes}=1;
		} elsif($tBody =~ /^$tagName\:$/i) {
			$tagsAllow->{$tagName}->{allowAllAttributes}=1;
		} else {
			while($tBody =~ /:([a-z]+)/ig) {
				$tagsAllow->{$tagName}->{validAttributes}->{lc($1)}=1;
			}
		
			while($tBody =~ /\|([a-z]+)/ig) {
				if(!$tagsAllow->{$tagName}->{validAttributes}->{lc($1)}) {
					$tagsAllow->{$tagName}->{invalidAttributes}->{lc($1)}=1;
				}
			}
		}
	}

	return {tagsAllow=>$tagsAllow, tagsDenyAllAttributes=>$tagsDenyAllAttributes};
}

# ==Parse the tagsAllow string advanced format==
sub parseTagsDenyString($$) {
	my($class, $string) = @_;

	return {} if(!$string);

	my $tagsDeny = {};
	while($string =~ /([a-z]+)/ig) {
			$tagsDeny->{$1}->{val}=1;
	}

	return $tagsDeny;
}

# ==Return the configuration hash==
sub getConf($) {
	return $conf;
}
 
return 1;