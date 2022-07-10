\paper {
  #(define fonts
    (set-global-fonts
      #:roman "ITC Souvenir Std Light"
      #:factor (/ staff-height pt 20)
  ))
}

#(define (fraction-with-gap gap)
   (lambda (grob)
     (let* ((frac (ly:grob-property grob 'fraction))
            (num (car frac))
            (den (cdr frac))
            (fontsize (magnification->font-size (/ (- 4 gap) 4)))
            (baseline-skip 2)
            (m (markup
                #:vcenter
                #:fontsize fontsize
                #:override `(baseline-skip . ,baseline-skip)
                 #:center-column (#:number (number->string num)
                                   #:number (number->string den)))))
       (grob-interpret-markup grob m))))

music = {
    \tempo 4 = 120

    \clef bass \key c \major
    \override Staff.TimeSignature.stencil = #(fraction-with-gap 0.5)
    \numericTimeSignature
    \time 4/4

    \once \override Score.RehearsalMark.outside-staff-priority = #500
    \mark \markup { \small \italic "legato" }
    \repeat volta 8 { b,4 bis,4 b,4 bes,4 }
}

\score {
  \new Staff { \music }
  \layout { }
}

\score {
  \new Staff { \unfoldRepeats \music }
  \midi { }
}
