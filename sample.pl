#!/usr/bin/perl -w

# Jevix::Makeup Usage example
# Important: this module version accepts refs and returns hashref with the result keys
#    text - text result
#    error - error flag
#    errorLog - array containing all errors

use strict;
use warnings;
use Jevix::Makeup;
use Data::Dumper;

# Russian locale=================================================
use POSIX;
POSIX::setlocale (&POSIX::LC_CTYPE, "ru");
use locale;
# ===============================================================

my $text = 'Ёто - проверка. "Ќа,  говорит, вот тебе  твои рубахи и портки, а € пойду с <b style="color: red">"¬анькой"</b>, он кудр€вей  теб€"...';

# Example 1: with a hashref, containing all the settings
my $conf = {
                isHTML=>1,                  # Hypertext mode (plain text mode is faster)
               	vanish=>0,		    # Convert source into plain text (ignores all other options)        
                lineBreaks=>1,              # Add linebreaks <br />
                paragraphs=>1,              # Add paragraphs <p>
                dashes=>1,                  # Long dashes
                dots=>1,                    # Convert three dots into ellipsis
                edgeSpaces=>1,              # Clear white spaces around string
                tagSpaces=>1,               # Clear white spaces between tags (</td>  <td>)
                multiSpaces=>1,             # Convert multiple white spaces into single
                redundantSpaces=>1,         # Clear white spaces where they should not be
                compositeWords=>0,          # Put composite words inside <nobr> tag
                compositeWordsLength=>10,   # The maximum length of composite word to put inside <nobr>
                nbsp=>1,                    # Convert spaceses into non-breaking spaces where necessary
                quotes=>1,                  # Quotes makeup
                qaType=>0,                  # Outer quotes type (http://jevix.ru/)
                qbType=>1,                  # Inner quotes type
                misc=>1,                    # Little things (&copy, fractions and other)
                codeMode=>2,                # Special chars representation (0: ANSI <...>, 1: HTML <&#133;>, 2: HTML entities <&hellip;>)
                tagsDenyAll=>0,             # Deny all tags by default
                tagsDeny=>'',               # Deny tags list
                tagsAllow=>'',              # Allowed tags list (exception to "deny all" mode)
                tagCloseSingle=>0,          # Close single tags when they are not
                tagCloseOpen=>0,            # Close all open tags at the end of the document
                tagNamesToLower=>0,         # Bring tag names to lower case
                tagNamesToUpper=>0,         # Bring tag names to upper case
                tagAttributesToLower=>0,    # Bring tag attributes names to lower case
                tagAttributesToUpper=>0,    # Bring tag attributes names to upper case
                tagQuoteValues=>0,          # Quote tag attribute values
                tagUnQuoteValues=>0,        # Unquote tag attributes values
                links=>1,                   # Put urls into <a> tag
                linksAttributes=>0,         # Hash containing all new links attributes set
                simpleXSS=>0,               # Detect and prevent XSS
                checkHTML=>0,               # Check for HTML integrity
                logErrors=>0                # Log errors
           };

my $result = Jevix::Makeup->process(\$text, $conf);

# Example 2: Enable "Basic mode", disable non-breakable spaces insertion, set outer quotes type, disble HTML mode
# -----------------------------------------------------------------------------------------------------------------------------------
#
#my $result = Jevix::Makeup->process(\$text, {presetBasic=>1, nbsp=>0, qaType=>1, isHTML=>0});


# Example 3: process the text with the default "basic settints"
# ---------------------------------------------------------------
#
#my $result = Jevix::Makeup->process(\$text);

# tagsAllow и tagsDeny parameters
# -----------------------------------------
#
# tagsAllow and tagsDeny are easy to pass as a string, but also possible as hashes
#
# tagsAllow can just contain tags names separated with commas ('a,br,div'), but there is also some advanced syntax avaiable.
#
# Examples:
#         '|a,br,b' - alllow tags 'a', 'br', 'b', deby any attributes for all tags
#         '|a,br:class,b' - allow tags 'a', 'br', 'b', deny any attributes for all tags, except 'br' tag 'class' attribute
#         'a:href:title,br,b' - allow tags 'a', 'br', 'b', allow any attributes for tags 'br' and 'b', allow attributes 'href' and 'title' for the tag 'a'
#                               только атрибуты 'href' и 'title'
#
# tagsDeny is expected to be string:
#         'script, object' - deny tags 'script' and 'object'
# 


print Dumper $result;