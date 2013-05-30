#!/usr/bin/perl -w

# Simple tests for Jevix::MakeupUtf

use strict;
use warnings;
use Jevix::MakeupUtf;
use Data::Dumper;

# Russian locale=================================================
use POSIX;
POSIX::setlocale (&POSIX::LC_CTYPE, "ru");
use locale;
# ===============================================================

# Список тестов вопрос-ответ
my @tests = (
		{ 
			q=>'Проверям тире, лишние пробелы, многоточие ... Слово   - дело',
			a=>'Проверям тире, лишние пробелы, многоточие&hellip; Слово&nbsp;&mdash; дело'
		},

		{
			q=>'Проверяем "кавычки внешние". После этого он сказал: "Не моё это "дело""',
			a=>'Проверяем &laquo;кавычки внешние&raquo;. После этого он сказал: &laquo;Не моё это &ldquo;дело&rdquo;&raquo;'
		},

		{
			q=>'"кавычки с <b>"тегами"</b>"',
			a=>'&laquo;кавычки с <b>&ldquo;тегами&rdquo;</b>&raquo;'
		},

		{
			q=>'Составное слово как-то так',
			a=>'Составное слово <nobr>как-то</nobr> так'
		},

		{
			addConf=>{'paragraphs'=>1},
			q=>"параграф1\n\nпараграф2\nновая строка",
			a=>"<p>параграф1</p>\n\n<p>параграф2<br />\nновая строка</p>"
		},

		{
			addConf=>{'paragraphs'=>0},
			q=>"-- До свиданья, внучек, до свиданья! – закивала бабка, – Вежливый какой, сейчас таких нет. Вот, например, Петрович – помню, помню, молодой был, галантный, воспитанный…\n-- До свиданья, внучек, до свиданья! – закивала бабка, – Вежливый какой, сейчас таких нет. Вот, например, Петрович – помню, помню, молодой был, галантный, воспитанный…\n-- До свиданья, внучек, до свиданья! – закивала бабка, – Вежливый какой, сейчас таких нет. Вот, например, Петрович – помню, помню, молодой был, галантный, воспитанный…",
			a=>"&mdash;&nbsp;До свиданья, внучек, до&nbsp;свиданья! – закивала бабка, – Вежливый какой, сейчас таких нет. Вот, например, Петрович – помню, помню, молодой был, галантный, воспитанный&hellip;<br />\n&mdash;&nbsp;До свиданья, внучек, до&nbsp;свиданья! – закивала бабка, – Вежливый какой, сейчас таких нет. Вот, например, Петрович – помню, помню, молодой был, галантный, воспитанный&hellip;<br />\n&mdash;&nbsp;До свиданья, внучек, до&nbsp;свиданья! – закивала бабка, – Вежливый какой, сейчас таких нет. Вот, например, Петрович – помню, помню, молодой был, галантный, воспитанный&hellip;"
		},

		{
			q=>'Тест <a href="http://jevix.ru" title=hello onload="alert(1)">допустимых</a> тегов и <b     cLaSs= my style="wow">аттрибутов</b>',
			a=>'Тест <a href="http://jevix.ru" title=hello>допустимых</a> тегов и <b style="wow">аттрибутов</b>'
		},

		{
			q=>'Здесь должна быть ссылка: http://jevix.ru, <a href="http://jevix.ru">а здесь - нет http://jevix.ru</a>',
			a=>'Здесь должна быть ссылка: <a href="http://jevix.ru" target="_blank">http://jevix.ru</a>, <a href="http://jevix.ru">а&nbsp;здесь&nbsp;&mdash; нет http://jevix.ru</a>'
		},

		{
			addConf=>{'tagNamesToLower'=>1},
			q=>'Приводим всё к <B>нижнему</b> <a HREF="http://jevix.ru">регистру</a>',
			a=>'Приводим всё к <b>нижнему</b> <a href="http://jevix.ru">регистру</a>'
		},

		{
			addConf=>{'tagsAllow'=>'a,br,b'},
			q=>'XSS test <script>alert(1)</script>. <a href="http://jevix.ru" onmouseOVER="alert(1)">hey!</a>',
			a=>'XSS test. <a href="http://jevix.ru">hey!</a>'
		},

		{
			addConf=>{'tagQuoteValues'=>1},
			q=>'<h1>this is test</h1><a href=jevix.ru title = link class="my" style="width: 100px; height: 200px;" id=elem700 >try jevix</a>',
			a=>'<h1>this is test</h1><a href="jevix.ru" title = "link" class="my" style="width: 100px; height: 200px;" id="elem700" >try jevix</a>'
		},
		
		{
			addConf=>{'tagCloseOpen'=>1},
			q=>'<p><h1>this is test',
			a=>'<p><h1>this is test</h1></p>'
		},

	      );

# Options values
my $conf = {
               isHTML=>1,							# Hypertext mode (plain text mode is faster)
               vanish=>0,							# Convert source into plain text (ignores all other options)               
               lineBreaks=>1,							# Add linebreaks <br />
               paragraphs=>0,							# Add paragraphs <p>
               dashes=>1,							# Long dashes
               dots=>1,								# Convert three dots into ellipsis
               edgeSpaces=>1,							# Clear white spaces around string
               tagSpaces=>1,							# Clear white spaces between tags (</td>  <td>)
               multiSpaces=>1,							# Convert multiple white spaces into single
               redundantSpaces=>1,						# Clear white spaces where they should not be
               compositeWords=>1,						# Put composite words inside <nobr> tag
               compositeWordsLength=>10,					# The maximum length of composite word to put inside <nobr>
               nbsp=>1,								# Convert spaceses into non breakable spaces where necessary
               quotes=>1,							# Quotes makeup
               qaType=>0,							# Outer quotes type (http://jevix.ru/)
               qbType=>1,							# Inner quotes type
               misc=>1,								# Little things (&copy, fractions and other)
               codeMode=>2,							# Special chars representation (0: ANSI <...>, 1: HTML <&#133;>, 2: HTML entities <&hellip;>)
               tagsDenyAll=>0,							# Deny all tags by default
               tagsDeny=>'',							# Denied tags list
               tagsAllow=>'|A:href:title,br,B:STYLE',				# Allowed tags list (exception to "deny all" mode)
               tagCloseSingle=>0,						# Close single tags when they are not
	       tagCloseOpen=>0,							# Close all open tags at the end of the document
               tagNamesToLower=>0,						# Bring tag names to lower case
               tagNamesToUpper=>0,						# Bring tag names to upper case
               tagAttributesToLower=>0,						# Bring tag attributes names to lower case
               tagAttributesToUpper=>0,						# Bring tag attributes names to upper case
               tagQuoteValues=>0,						# Quote tag attribute values
               tagUnQuoteValues=>0,						# Unquote tag attributes values
               links=>1,							# Put urls into <a> tag
               linksAttributes=>{target=>'_blank'},				# Hash containing all new links attributes set
               simpleXSS=>1,							# Detect and prevent XSS
               checkHTML=>0,							# Check for HTML integrity
               logErrors=>0							# Log errors
};

my $text;
my $result;
my $testsCount = 0;
my $errCount = 0;

my $jevix = new Jevix::MakeupUtf;

print "\n\nTesting Jevix Class...\n\n";

$testsCount++;
$jevix->setConf($conf);

my $pTest = $jevix->getConf();
$pTest = $pTest->{tagsAllow};

if(!($pTest->{br} && $pTest->{b} && $pTest->{a} && $pTest->{a}->{validAttributes}->{href} && $pTest->{a}->{validAttributes}->{title})) {
	print "Allowed tags string parser failure\n\n";
	$errCount++;
}

# Perform text tests
foreach my $test (@tests) {
	$testsCount++;
	$text = $test->{q};

	# Reconfiguration
	if($test->{addConf}) {
		while (my ($k,$v) = each(%{$test->{addConf}})) {
			$conf->{$k} = $v
		}
		
		$jevix->setConf($conf);
	}

	$result = $jevix->process(\$text);

	if($test->{a} ne $result->{text}) {
		print 'Test ' . $testsCount . ' failed: [' . $text . "]\n";
		print 'Expected: [' . $test->{a} . "]\n";
		print 'We have:  [' . $result->{text} . "]\n\n";
		$errCount++;
	}
}

print "Tests Perfomed: " . $testsCount . "\n";
print "Tests Failed: " . $errCount . "\n";
print "Well Done!\n\n" if(!$errCount);