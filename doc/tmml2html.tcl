#!/opt/tcl/bin/tclsh
#-----------------------------------------------------------------------------
#   Copyright (c) 1999 Jochen C. Loewer (loewerj@hotmail.com)
#-----------------------------------------------------------------------------
#
#   $Header: $
#
#
#   A TMML to HTML convert written in Tcl using the tDOM package.
#
#
#   The contents of this file are subject to the Mozilla Public License
#   Version 1.1 (the "License"); you may not use this file except in
#   compliance with the License. You may obtain a copy of the License at
#   http://www.mozilla.org/MPL/
#
#   Software distributed under the License is distributed on an "AS IS"
#   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
#   License for the specific language governing rights and limitations
#   under the License.
#
#   The Original Code is tDOM.
#
#   The Initial Developer of the Original Code is Jochen Loewer
#   Portions created by Jochen Loewer are Copyright (C) 1998, 1999
#   Jochen Loewer. All Rights Reserved.
#
#   Contributor(s):            
#
#
#   $Log: $
#
#
#   written by Jochen Loewer
#   August 1999
#
#-----------------------------------------------------------------------------


if {[catch {
    package require tdom
}]} {
    load ../unix/tdom0.6[info sharedlibextension]
    source ../lib/tdom.tcl
}



#-----------------------------------------------------------------------------
#   cgiQuote  -   escapes html-special characters
#
#   @in       s
#   @returns  string with html-special characters escaped
#
#-----------------------------------------------------------------------------
proc cgiQuote { s } {
    regsub -all {&}     $s {\&amp;}     s       ;# must be first!
    regsub -all {"}     $s {\&quot;}    s
    regsub -all {<}     $s {\&lt;}      s
    regsub -all {>}     $s {\&gt;}      s
    return $s
}         


#-----------------------------------------------------------------------------
#   ReadFile
#
#-----------------------------------------------------------------------------
proc ReadFile { fileName } {

    set fd [open $fileName]
    set data [read $fd [file size $fileName]]
    close $fd
    return $data
}



#-----------------------------------------------------------------------------
#   AddGlobalReference
#
#-----------------------------------------------------------------------------
proc AddGlobalReference { name } {

    global gref CurrentHtmlFile

    puts "AddGlobalReference $name"
    set name [string trim $name]
    set gref($name) $CurrentHtmlFile
}


#-----------------------------------------------------------------------------
#   LinkToGlobalReference
#
#-----------------------------------------------------------------------------
proc LinkToGlobalReference { name } {

    global gref

    puts "LinkToGlobalReference $name"
    set name [string trim $name]
    if {[info exists gref($name)]} {
        return "<a href=$gref($name)>"
    } else {
        return "<a href=#missingLink>"
    }
}



#-----------------------------------------------------------------------------
#   ResetLocalReferenceCounter
#
#-----------------------------------------------------------------------------
proc ResetLocalReferenceCounter { } {

    global rCount
    set rCount 0     
}


#-----------------------------------------------------------------------------
#   InitLocalReferences
#
#-----------------------------------------------------------------------------
proc InitLocalReferences { } {

     global ref

     catch { unset ref }
     ResetLocalReferenceCounter
}


#-----------------------------------------------------------------------------
#   AddLocalReference
#
#-----------------------------------------------------------------------------
proc AddLocalReference { name } {

    global ref rCount

    set name [string tolower $name]

    incr rCount
    set ref($name) $rCount
    return "x$rCount"
}


#-----------------------------------------------------------------------------
#   LinkToLocalReference
#
#-----------------------------------------------------------------------------
proc LinkToLocalReference { name } {

    global ref rCount

    set name [string tolower $name]

    if {[info exists ref($name)]} {
        return "<a href=#x$ref($name)>"
    } else {
        return "<a href=#x0>"
    }
}




#-----------------------------------------------------------------------------
#   TmmlGetGlobalReferences
#
#-----------------------------------------------------------------------------
proc TmmlGetGlobalReferences { htmlfile doc } {

    global CurrentHtmlFile

    set CurrentHtmlFile $htmlfile
    set root [$doc documentElement]

    $root simpleTranslate dummy {

        NAME {
            prefix "[AddGlobalReference [$node text]]"
        }
    }
}



#-----------------------------------------------------------------------------
#   TmmlGetLocalReferences
#
#-----------------------------------------------------------------------------
proc TmmlGetLocalReferences { doc } {

    set root [$doc documentElement]

    $root simpleTranslate dummy {

        METHODDEF {
            prefix "<a name=[AddLocalReference [$node @NAME]]><p><dl compact>\n"
            suffix "</dd></dl>"
        }
    }
}


#-----------------------------------------------------------------------------
#   GenSeeAlsoLinks
#
#-----------------------------------------------------------------------------
proc GenSeeAlsoLinks { node } {

    set html ""
    regsub {,}  [$node text] { , } text
    foreach r $text {
        if {$r != ","} {
            append html "&nbsp;[LinkToGlobalReference $r]"
            append html "<b>$r</b></a>"
        } else {
            append html ", "
        }
    }
    return $html
}


#-----------------------------------------------------------------------------
#   Tmml2Html
#
#-----------------------------------------------------------------------------
proc Tmml2Html { doc } {

    set outputHtml ""

    set root [$doc documentElement]
    $root simpleTranslate outputHtml {

        B - L - LIT { tag b      }
        STRONG      { tag strong }
        EM          { tag em     }
        I           { tag i      }
        TT          { tag tt     }
        OL          { tag ol     }
        LI          { tag LI     }
        UL          { tag ul     }
        DL          { tag dl     }
        DD          { tag dd     }
        DT          { tag dt     }
        PRE         { tag pre    }
        P           { tag p      } 

        METHODDEF {
            prefix "<a name=[AddLocalReference [$node @NAME]]><p><dl compact>\n"
            suffix "</dd></dl>"
        }
        METHOD {
            prefix "<b>[LinkToLocalReference [$node text]]"
            suffix "</a></b>"            
        }
        SYNTAX/parent::METHODDEF {
            prefix "<dt><b>"
            suffix "</b></dt>\n<dd>"
        }
        SYNTAX {
            prefix "<p><b>"
            suffix "</b>"        
        }
        M -
        META -
        meta { 
            prefix "<em>"
            suffix "</em>"
        }
        opt -
        OPT {
            prefix "&nbsp;</b>?<b>"
            suffix "</b>?</b>&nbsp;"
        }
        GROUP {
            prefix "("
            suffix ")"
        }
        OR {
            prefix "|"
        }
        EXAMPLE {
            prefix "<blockquote><pre>"
            suffix "</pre></blockquote>"
        }
        HEADING {
            tag h3
        }
        SYNOPSIS {
            prefix "<h3>SYNOPSIS</h3>"
        }
        SEEALSO {
            prefix "<h3>SEE ALSO</h3>"
            start { 
                GenSeeAlsoLinks $node
            }
            stop yes
        }
        KEYWORDS {
            stop yes
        }
        COMMAND { 
            prefix "[LinkToGlobalReference [$node text]]<b>"
            suffix "</b></a>"
        }
        COMMENT {
            prefix "<!--\n"
            suffix "-->\n"
        }
        DESC { 
            prefix "&nbsp; - &nbsp; "
        }
        NAME {
            prefix "<h3>NAME</h3>"
        }
        MANPAGE {
            prefix "<title>[[$node child 1 NAME] text] - [[$node child 1 DESC] text]</title><body bgcolor=white>"
            suffix "</body>"
        }
    }
    return $outputHtml
}


#-----------------------------------------------------------------------------
#        begin of main part
#-----------------------------------------------------------------------------


  #------------------------------------------------------------------
  #   get global (command) reference of all files to process
  #------------------------------------------------------------------
  foreach tmmlFile $argv {

      regsub {\.[^.]*$} $tmmlFile {.html} htmlFile
      puts "Indexing $tmmlFile $htmlFile"

      dom parse [ReadFile $tmmlFile] doc

      TmmlGetGlobalReferences $htmlFile $doc
  }

  foreach tmmlFile $argv {

      regsub {\.[^.]*$} $tmmlFile {.html} htmlFile
      puts "Generating $tmmlFile $htmlFile"
      set html [open $htmlFile w]

      dom parse -keepEmpties [ReadFile $tmmlFile] doc

      #------------------------------------------------------------------
      #   in the first pass process the XML to get the local references
      #------------------------------------------------------------------
      InitLocalReferences
      TmmlGetLocalReferences $doc
      ResetLocalReferenceCounter

      #------------------------------------------------------------------
      #  in the second pass generate the HTML
      #------------------------------------------------------------------
      puts  $html [Tmml2Html $doc]
      close $html
  }

#-----------------------------------------------------------------------------
#        end of main part
#-----------------------------------------------------------------------------

