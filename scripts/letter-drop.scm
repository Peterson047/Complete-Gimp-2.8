; Letter Drop Script-fu
; by Saul Goode
;  
; --------------------------------------------------------------------
; Based on the PERL plug-in "Impact Letters" by Ky McPherson
; --------------------------------------------------------------------
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; - PhotoComix Sept 2009-
;;  Script is from Saulgoode http://flashingtwelve.brickfilms.com/GIMP/Scripts/
;;  i only changed the registration path:
;;  now the script show up in Video/Animated FX/Letter Drop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(define (script-fu-letter-drop text FGcolor BGcolor font letter-delay word-delay start-size
  end-size frames-per-letter opacity geometric use-gradient gradient)
  ;; This function returns a list of floats evenly spaced in the range start to end
  (define (algebraic-prog start end elements)
    (let* (
      (cnt 1)
      (new-list ())
      )
      (if (= start 0)
        (set! new-list (list 0 (/ end (- elements 1)))) 
        (set! new-list (list 1 (+ 1 (/ (- (/ end start) 1) (- elements 1)))))        
        )
      (while (< cnt (- elements 1))
        (nconc new-list (cons (+ (- (cadr new-list) (car new-list)) (car (last new-list)))))
        (set! cnt (+ cnt 1))
        )
      (if (> start 0)
        (set! new-list (mapcar * new-list (make-list (length new-list) start)))
        )
      new-list
      )
    )
  ;; 'geometric-prog' returns a list of floats with each element being the product of a radix and the 
  ;; preceding element
  (define (geometric-prog start end elements)
    (let* (
      (cnt 2)
      (new-list ())
      )
      (if (= start 0)
        (set! new-list '( 0 0))
        (set! new-list (list 1 (pow (/ end start) (/ (- elements 1))))) ;; nth root
        )
      (while (< cnt elements)
        (nconc new-list (cons (* (cadr new-list) (car (last new-list)))))
        (set! cnt (+ cnt 1))
        )
      (set! new-list (mapcar * new-list (make-list (length new-list) start)))
      )
    )
  ;; This function breaks a word up into a list of characters
  (define (string->list word)
    (let* (
      (i 1)
      (chars (list (substring word 0 1)))
      )
      (while (< i (string-length word))
        (set! chars (append chars (list (substring word i (+ i 1)))))
        (set! i (+ i 1))
        )
      chars
      )
    )
  ;; This function determines the cell width and height for a character
  ;; It is passed two chars because of proportionally-spaced fonts.
  (define (char-width str font size)
    (set! str (string-append str "  ")) ;; just to be safe
    (- (car (gimp-text-get-extents-fontname (substring str 0 2) size PIXELS font))
       (car (gimp-text-get-extents-fontname (substring str 1 2) size PIXELS font))
       )
    )
  ;; This function returns a list with the "union-ed" extents of the passed rectangles)
  (define (update-bounds old-bounds new-bounds)
    (list 
        (min (car old-bounds) (car new-bounds))
        (min (cadr old-bounds) (cadr new-bounds))
        (max (caddr old-bounds) (caddr new-bounds))
        (max (cadr (cddr old-bounds)) (cadr (cddr new-bounds)))
        )
    )
        
  (let* (
      (display)
      (FG-old (car (gimp-context-get-foreground))) 
      (BG-old (car (gimp-context-get-background)))
      (GRAD-old (car (gimp-context-get-gradient)))
      (image)
      (count (* (string-length text) frames-per-letter))
      (i 0)
      (sizes ())
      (size)
      (words ())
      (word)
      (letter)
      (reds ())
      (red)
      (greens ())
      (green)
      (blues ())
      (blue)
      (first-width)
      (last-width)
      (curr-width)
      (x 0)
      (x-base 0)
      (y-base)
      (y-offsets ())
      (tmp-layer)       ;; temporary layer
      (float-layer ())  ;; another temporary layer
      (ref-layer ()) ;; Holds the bounds of the maximum char size for a given letter (at a point in time)
      (src-layer ()) ;; Image of all the previous letters
      (max-width 0)  ;; Used to determine if ref-layer is growing in size
      (image-bounds '(99999 99999 0 0))
      )
    ;; Create the image image (it will be too wide, but we can correct when we are finished drawing)
    (set! win-width (car (gimp-text-get-extents-fontname text end-size PIXELS font)))
    (set! start-height (cadr (gimp-text-get-extents-fontname text start-size PIXELS font)))
    (set! end-height (cadr (gimp-text-get-extents-fontname text end-size PIXELS font)))
    
    ;; widen the window enough for the BIG letter on each end
    (set! win-height (max start-height end-height))
    (set! first-width (char-width (substring text 0 2) font (max start-size end-size))) 
    (if (> start-size end-size)
      (set! x-base (/ first-width 2))
      )
 
    (set! last-width 
        (char-width (string-append (substring text (- (string-length text) 1)) " ") font (max start-size end-size))
        )
      
    (set! win-width (+ win-width first-width last-width))
    (set! image (car (gimp-image-new win-width win-height RGB)))
    ;; Create the layer 
    (set! background (car (gimp-layer-new image win-width win-height RGBA-IMAGE
        (string-append "Background (" (number->string word-delay 10 0 0) "ms) (replace)")
        100 ;; opacity
        NORMAL-MODE ))
        )
    (gimp-image-add-layer image background 0)    
    (gimp-palette-set-background BGcolor)
    (gimp-drawable-fill background BACKGROUND-FILL)
    (set! display (car (gimp-display-new image)))
    (gimp-image-undo-disable image)
    
    (set! word (set! words (strbreakup text " ")))
    (while (car word)
      (set! letter (car word))
      (while (> 0 (string-length letter))
        (set! letter (substring word 1 (string-length letter)))
        )
      (set! word (cdr word))
      )
  
    ;; compute all font sizes, colors and luminosities for the animation (one per frame)
    (if geometric
      (begin
        (if (= start-size 0)
          (set! start-size 1)
          )
        (set! sizes (geometric-prog start-size end-size frames-per-letter))
        )
      (set! sizes (algebraic-prog start-size end-size frames-per-letter))
      )
    (if (= use-gradient TRUE)
      (begin ;; gradient cycle; use algebraic progression to set luminosity
        (set! reds (algebraic-prog (car BGcolor) (car FGcolor) frames-per-letter))
        (set! greens (algebraic-prog (cadr BGcolor) (cadr FGcolor) frames-per-letter))
        (set! blues (algebraic-prog (caddr BGcolor) (caddr FGcolor) frames-per-letter))
        (gimp-context-set-gradient gradient)
        )
      (begin ;; no gradient cycle 
        (set! reds (algebraic-prog (car FGcolor) (car FGcolor) frames-per-letter))
        (set! greens (algebraic-prog (cadr FGcolor) (cadr FGcolor) frames-per-letter))
        (set! blues (algebraic-prog (caddr FGcolor) (caddr FGcolor) frames-per-letter))
        )
      )
    (set! size (cdr sizes)) 
    (set! src-layer (car (gimp-layer-copy background 1)))
    (gimp-image-add-layer image src-layer -1)  ;; 
    ;; Note: start-height and end-height remain the same for all characters of a given size
    ;;       therefore we can pre-calc these values into a list
    (set! y-base (/ win-height 2) )
    (set! y-offsets (list (- y-base (/ start-height 2))))
    (while (car size) ;; compute the y-offsets
      (nconc y-offsets (cons (- y-base (/ (cadr (gimp-text-get-extents-fontname "A" (car size) PIXELS font)) 2))))
      (set! size (cdr size))
      )
    ;; for each word 
    (set! word words)
    (gimp-progress-init "Generating letters" display)
    (while (car word)
      (set! letter (string->list (car word)))
      ;; for each letter
      (while (car letter)
        (set! size sizes)
        (set! y-offset y-offsets)
        (set! red reds)
        (set! green greens)
        (set! blue blues)
        (set! max-width 0) ;; keep track of the biggest char in each frame
        (if (cadr letter)
          (set! x-base (+ x-base (/ (char-width (string-append (car letter) (cadr letter)) font end-size) 2)))
          (set! x-base (+ x-base (/ (char-width (string-append (car letter) " ") font end-size) 2)))
          )
        ;; for each frame
        (while (car size)
          (if (cadr letter)
            (set! curr-width (char-width (string-append (car letter) (cadr letter)) font (car size)))
            (set! curr-width (char-width (string-append (car letter) " ") font (car size))) ;; assume space at end of word
            )
          (set! x (- x-base (/ curr-width 2)))
          (gimp-context-set-foreground (list (car red) (car green) (car blue)))
          (set! layer (car (gimp-text-fontname image -1 x (car y-offset) (car letter) 0 TRUE (car size) PIXELS font)))
          
          ;; Convert the text layer to a "normal" layer
          (plug-in-autocrop-layer RUN-NONINTERACTIVE image layer)
          ;; Text layer is now a graphic layer (so "layer bounds" could be determined, is there another way?)
          (if (and (cdr size) (= use-gradient TRUE))
            (plug-in-gradmap RUN-NONINTERACTIVE image layer)
            )
          (if (> curr-width max-width)
            (begin
              (set! ref-layer layer)
              (set! max-width curr-width)
              )
            )
          (gimp-rect-select image  
              (car (gimp-drawable-offsets ref-layer)) 
              (cadr (gimp-drawable-offsets ref-layer)) 
              (car (gimp-drawable-width ref-layer))
              (car (gimp-drawable-height ref-layer)) 
              CHANNEL-OP-REPLACE 0 0
              )
          (set! image-bounds (update-bounds image-bounds (cdr (gimp-selection-bounds image))))
          (set! tmp-layer (car (gimp-layer-copy src-layer 1)))
          (gimp-image-add-layer image tmp-layer -1)  ;; 
          
          (set! float-layer (car (gimp-selection-float tmp-layer 0 0))) ;; strip out the selected region
          (gimp-floating-sel-to-layer float-layer) ;; into a new layer 
          (gimp-image-remove-layer image tmp-layer) ;; This layer no longer needed
          (gimp-image-lower-layer image float-layer)
          (if (cdr size) ;; if not last frame
            (gimp-layer-set-opacity layer opacity)
            )
          (set! layer (car (gimp-image-merge-down image layer EXPAND-AS-NECESSARY)))  ;; layers should be same size
          (if (>= curr-width max-width) ;; update ref-layer if necessary
            (set! ref-layer layer)
            )
          (gimp-drawable-set-name layer (string-append (car word) "-" (number->string layer 10 0 0)
              "(" (number->string letter-delay 10 0 0) "ms) (combine)"))
          (set! y-offset (cdr y-offset))
          (set! red (cdr red))
          (set! green (cdr green))
          (set! blue (cdr blue))
          (set! size (cdr size)) ;; next frame
          (set! i (+ 1 i))
          (gimp-progress-update (/ i count))
          )
        ;; we need to merge the layer with the previous src-layer
        (gimp-image-raise-layer-to-top image src-layer)
        (set! tmp-layer (car (gimp-layer-copy layer 1))) ;; duplicate the letter
        (gimp-image-add-layer image tmp-layer 0)        ;; and place it on top
        (set! src-layer (car (gimp-image-merge-down image tmp-layer EXPAND-AS-NECESSARY)))
        (set! max-width 0)
        (set! x-base (+ x-base (/ curr-width 2)))
        (set! letter (cdr letter))
        )
      (gimp-drawable-set-name layer (string-append (car word) "-" (number->string layer 10 0 0)
              "(" (number->string word-delay 10 0 0) "ms) (combine)"))
 
      (set! x-base (+ x-base (/ curr-width 2))) ;; increment for space
      (set! word (cdr word))
      )
    (gimp-image-remove-layer image src-layer) ;; This layer no longer needed
    
    (gimp-image-resize image 
        (- (caddr image-bounds) (car image-bounds)) 
        (- (cadr (cddr image-bounds)) (cadr image-bounds))
        (- (car image-bounds))
        (- (cadr image-bounds))
        )
    
    (gimp-image-undo-disable image)
    (gimp-context-set-gradient GRAD-old)
    (gimp-context-set-foreground FG-old ) 
    (gimp-context-set-background BG-old )
    (gimp-image-clean-all image)
    ) ;; end of LET*
  ) ;; end of program
       

(script-fu-register
  "script-fu-letter-drop"
  "<Image>/Video/Animated FX/Letter Drop"
  "Given a text string, generates an animated sequence where letters drop onto the background individually."
  "Saul Goode"
  "Saul Goode"
  "February 2006"
  ""
    SF-STRING _"Text"       
        "GIMPtalk"
    SF-COLOR _"Foreground"  ;;     "color to use for letter"     
        '( 0 0 0 )
    SF-COLOR _"Background"  ;;     "color to use for background"  
        '( 255 255 255 )
    SF-FONT  _"Font"        ;;      "font"     
        "-*-utopia-bold-r-normal-*-50-*-*-*-p-*-*-*"
    SF-ADJUSTMENT _"Letter delay";; "time delay between letter in a word"  
        '( 100 0 5000 1 100 0 0)
    SF-ADJUSTMENT _"Word delay"  ;;  "additional time delay for the space between words"
        '( 300 0 5000 1 100 0 0 )
    SF-ADJUSTMENT _"Starting size" ;;"animated letter initial size"
        '( 48 6 240 1 12 0 0 )
    SF-ADJUSTMENT _"Ending size";;   "animated letter final size"
        '( 12 6 240 1 12 0 0 )
    SF-ADJUSTMENT _"Frames per letter";; "number of frames for each animated letter"
        '( 5 2 200 1 5 0 0 )
    SF-ADJUSTMENT _"Opacity" ;; Opacity of "moving" letters
        '( 100 0 100 1 5 0 0 )
    SF-TOGGLE _"Geometric Progression";; "Letter size doubles each step" 
        FALSE  ;; Otherwise letter size increases linearly
    SF-TOGGLE _"Use Color from Gradient";; "Sweep colors from gradient during animation" 
        FALSE
    SF-GRADIENT _"Color Gradient" ;; "Gradient to use"
        "Full saturation spectrum CW"
  )