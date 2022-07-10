\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{ncmanual}[2018/01/01 v0.01 North Coast Synthesis documentation]

% handle inheritance from report
% FIXME process and pass options
\ProcessOptions\relax
\LoadClass[letter,twocolumn]{report}

\RequirePackage{ifxetex}
\ifxetex
  \RequirePackage{fontspec}
\fi

\RequirePackage[T1]{fontenc}
\RequirePackage{textcomp}

\RequirePackage{amsmath}
\RequirePackage{calc}
\RequirePackage{chngcntr}
\RequirePackage{graphicx}
\RequirePackage{helvet}
\RequirePackage{longtable}
\RequirePackage{pdfpages}
\RequirePackage{tikz}
\RequirePackage[rigidchapters]{titlesec}
\RequirePackage{tocloft}
\RequirePackage{xcolor}

\usetikzlibrary{arrows}

\definecolor{darkgreen}{rgb}{0,0.35,0}
\definecolor{purplish}{rgb}{0.4,0,0.6}

% must be last
\RequirePackage[letterpaper,breaklinks,bookmarks,plainpages=false,
   colorlinks,citecolor=darkgreen,linkcolor=purplish]{hyperref}

% config file
\InputIfFileExists{ncmanual.cfg}{}{}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% page layout

\setlength{\topmargin}{0.25in}
\setlength{\headheight}{0pt}
\setlength{\headsep}{0pt}

\setlength{\oddsidemargin}{\paperwidth*2/17-1in}
\setlength{\marginparsep}{\paperwidth*1/68}
\setlength{\marginparwidth}{\paperwidth*1/17}
\setlength{\columnsep}{1em}
\setlength{\textwidth}{\paperwidth*13/17}
\setlength{\textheight}{8.5in}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% indentation, lists, line heights

\setlength{\parindent}{1.5em}

\setlength{\topsep}{0pt}
\setlength{\partopsep}{0pt}
\setlength{\itemsep}{0pt}
\setlength{\parsep}{0pt}
\setlength{\listparindent}{1em}

\setlength{\leftmargini}{2.5em}
\setlength{\labelsep}{0.5em}

\dimen@=\f@size\p@\dimen@6\dimen@\divide\dimen@5\edef\l@rgesize{\the\dimen@}
\dimen@=\f@size\p@\dimen@2\dimen@\edef\@hugesize{\the\dimen@}

\renewcommand\normalsize{%
   \@setfontsize\normalsize\@xpt\@xiipt
   \abovedisplayskip 10\p@ \@plus2\p@ \@minus5\p@
   \abovedisplayshortskip \z@ \@plus3\p@
   \belowdisplayshortskip 6\p@ \@plus3\p@ \@minus3\p@
   \belowdisplayskip \abovedisplayskip}
\normalsize
\renewcommand\small{%
   \@setfontsize\small\@ixpt{11}%
   \abovedisplayskip 8.5\p@ \@plus3\p@ \@minus4\p@
   \abovedisplayshortskip \z@ \@plus2\p@
   \belowdisplayshortskip 4\p@ \@plus2\p@ \@minus2\p@
   \belowdisplayskip \abovedisplayskip
}
\renewcommand\footnotesize{%
   \@setfontsize\footnotesize\@viiipt{9.5}%
   \abovedisplayskip 6\p@ \@plus2\p@ \@minus4\p@
   \abovedisplayshortskip \z@ \@plus\p@
   \belowdisplayshortskip 3\p@ \@plus\p@ \@minus2\p@
   \belowdisplayskip \abovedisplayskip
}

\setlength\smallskipamount{3\p@}
\setlength\medskipamount{6\p@}
\setlength\bigskipamount{12\p@}
\def\@listi{\leftmargin\leftmargini\listparindent 1em\relax}
\let\@listI\@listi
\@listi
\def\@listii{\leftmargin\leftmarginii
             \labelwidth\leftmarginii
             \advance\labelwidth-\labelsep
             \listparindent 1em\relax}
\def\@listiii{\leftmargin\leftmarginiii
              \labelwidth\leftmarginiii
              \advance\labelwidth-\labelsep
              \listparindent 1em\relax}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% heading formatting

% chapter head copied from report, just adding \@afterheading in 2col case
\def\@chapter[#1]#2{\ifnum \c@secnumdepth >\m@ne
                         \refstepcounter{chapter}%
                         \typeout{\@chapapp\space\thechapter.}%
                         \addcontentsline{toc}{chapter}%
                                   {\protect\numberline{\thechapter}#1}%
                    \else
                      \addcontentsline{toc}{chapter}{#1}%
                    \fi
                    \chaptermark{#1}%
                    \addtocontents{lof}{\protect\addvspace{10\p@}}%
                    \addtocontents{lot}{\protect\addvspace{10\p@}}%
                    \if@twocolumn
                      \@topnewpage[\@makechapterhead{#2}]%
                      \@afterheading
                    \else
                      \@makechapterhead{#2}%
                      \@afterheading
                    \fi}

\newcommand{\ch@pterform@t}[1]{%
  \begin{@twocolumnfalse}%
    \fontsize{\@hugesize}{3\baselineskip}\sffamily\bfseries\selectfont
    #1\,\leaders\hrule height 0.2ex\hfill\null
  \end{@twocolumnfalse}%
}%
\titlespacing*{\chapter}{0pt}{6\baselineskip}{2\baselineskip}
\titleformat{\chapter}[hang]{}{}{0pt}{\ch@pterform@t}

\titleformat{\section}[runin]%
   {\fontsize{\l@rgesize}{\baselineskip}\sffamily\bfseries}{}{0pt}{}%
   [\,\leaders\hrule height 0.16ex\hfill\null\\]
\titlespacing*{\section}{0pt}{\baselineskip}{0pt}

\titleformat{\subsection}[runin]{\sffamily\bfseries}{}{0pt}{}
\titlespacing*{\subsection}{0pt}{\baselineskip}{0.666em}

\titleformat{\subsubsection}[runin]{\rmfamily\scshape}{}{0pt}{}
\titlespacing*{\subsubsection}{0pt}{\baselineskip}{0.666em}

\titleformat{\paragraph}[runin]{\rmfamily\itshape}{}{0pt}{}
\titlespacing*{\paragraph}{\parindent}{0pt}{0.666em}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% title page

\renewcommand\maketitle{%
  \begin{titlepage}\begin{center}%
      \let\footnotesize\small
      \let\footnoterule\relax
      \let \footnote \thanks
      \vspace*{\fill}
      \phantomsection\belowpdfbookmark{Title Page}{bkm:title}
      \vspace*{\fill}
      {\sffamily\bfseries\huge\@title\null\par}
      \vspace{\fill}
      {\sffamily\bfseries\Large
        North Coast Synthesis Ltd.\null\par
       \@author\null\par}
      \vspace{\fill}
      \vspace{\fill}
      \vspace{\fill}
      \vspace{\fill}
      \vspace{\fill}
    \end{center}
    {\sffamily\bfseries\Large \hfill\@date\par}
    \vspace*{\fill}
    \@thanks\par
    \null
  \end{titlepage}%
  \setcounter{footnote}{0}%
  \global\let\thanks\relax
  \global\let\maketitle\relax
  \global\let\@thanks\@empty
  \global\let\@author\@empty
  \global\let\@date\@empty
  \global\let\@title\@empty
  \global\let\title\relax
  \global\let\author\relax
  \global\let\date\relax
  \global\let\and\relax
  \setcounter{page}{2}
}

\def\@maketitle{%
  \newpage\noindent
  \null
  \begingroup
    \let\footnote\thanks
    {\fontsize{\@hugesize}{2\baselineskip}\sffamily\bfseries\selectfont
      \@title\,\leaders\hrule height 0.2ex\hfill\null}\par\noindent
    {\fontsize{\l@rgesize}{\baselineskip}\sffamily\bfseries
      \@author\hfill\@date}\par
  \endgroup
  \dimen@=0.5\baselineskip\relax\advance\dimen@-0.5\p@\relax
  \vspace{\dimen@}\noindent
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% copyright

\newenvironment{copyrightpage}
    {%
      \if@twocolumn
        \@restonecoltrue\onecolumn
      \else
        \@restonecolfalse\newpage
      \fi
      \thispagestyle{plain}%
      \vspace*{\fill}

      \phantomsection\belowpdfbookmark{Copyright}{bkm:copyright}

      \noindent\begin{minipage}{\linewidth}
      \setlength{\parskip}{\baselineskip}
    }%
    {%
      \end{minipage}
      \if@restonecol\twocolumn \else \newpage \fi
      \clearpage
    }

\newcommand{\GPLThreeStatement}%
{This documentation is free: you can redistribute
it and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, version 3.

This documentation is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this documentation.  If not, see \url{http://www.gnu.org/licenses/}.

}


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% table of contents

\renewcommand{\cfttoctitlefont}{%
  \huge\sffamily\bfseries}
\renewcommand{\cftaftertoctitle}{%
  {\huge\,\leaders\hrule height 0.2ex\hfill\null\vspace*{-4ex}}%
   \phantomsection\belowpdfbookmark{Contents}{bkm:contents}}

\def\gobbtohfil#1{%
  \begingroup\if#1\hfil\else\aftergroup\gobbtohfil\fi\endgroup}

\renewcommand{\cftchappresnum}{\gobbtohfil}
\renewcommand{\cftchapnumwidth}{0pt}
\renewcommand{\cftchapindent}{0pt}
\renewcommand{\cftchapfont}{\sffamily\bfseries}
\renewcommand{\cftchappagefont}{\sffamily\bfseries}

\renewcommand{\cftsecpresnum}{\gobbtohfil}
\renewcommand{\cftsecnumwidth}{0pt}
\renewcommand{\cftsecindent}{1.5em}

\renewcommand{\cftsubsecpresnum}{\gobbtohfil}
\renewcommand{\cftsubsecnumwidth}{0pt}
\renewcommand{\cftsubsecindent}{3.0em}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% bibliography

\let\mitsu@bibliography\bibliography\relax
\renewcommand{\bibliography}[1]{%
  \clearpage
  \phantomsection\addcontentsline{toc}{chapter}{Bibliography}%
  \mitsu@bibliography{#1}%
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% miscellaneous

\newcommand{\DangerousBend}{\marginpar{\large\hfill\dbend\hfill\null}}
\newcommand{\DangerousSection}{\marginpar{\large\hfill
\raisebox{-0.5\baselineskip}[0pt][0pt]{\dbend}\hfill\null}}

\newcommand{\FiveIntegral}[1]{%
  \edef\ints@c{\noexpand\intop\noexpand\intkern@
    \noexpand\intop\noexpand\intkern@
    \noexpand\intop\noexpand\intkern@
    \noexpand\intop\noexpand\intkern@
    \noexpand\intop
    \noexpand\ilimits@
  }%
  \futurelet\@let@token\ints@a
}

\ams@newcommand{\iiiiint}{\DOTSI\protect\FiveIntegral}

\renewcommand{\thefootnote}{\fnsymbol{footnote}}

\counterwithout{figure}{chapter}
\counterwithout{table}{chapter}
\counterwithout{equation}{chapter}

\newcommand{\texdependspdfworkaround}{%
\ifx\TD@Gread@pdf\relax\else\let\Gread@pdf\TD@orig@Gread@pdf\fi
\ifx\TD@Ginclude@pdf\relax\else\let\Ginclude@pdf\TD@orig@Ginclude@pdf\fi}

\raggedbottom
