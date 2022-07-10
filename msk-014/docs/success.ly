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

    \clef treble \key c \major
    \override Staff.TimeSignature.stencil = #(fraction-with-gap 0.5)
    \numericTimeSignature
    \time 4/4

    \slurDown
    \repeat volta 8 { d'8([ fis'8 a'8] d''8[ fis''8 a''8]) r4 }
}

\score {
  \new Staff { \music }
  \layout { }
}

\score {
  \new Staff { \unfoldRepeats \music }
  \midi { }
}
