#!/usr/bin/guile -s
!#
;;; ============================================================
;;;   COMPLEX NUMBER LAB  --  Guile Scheme + gnuplot
;;;   log : complex-lab.log   (next to the script, append)
;;;   png : plot-<session>-<n>.png (auto, next to the script)
;;; ============================================================

(use-modules (ice-9 format)
             (ice-9 rdelim)
             (ice-9 popen))

;; ---------------- settings / state ----------------
(define W 72)
(define *decimals* 4)
(define PI (acos -1))
(define LOG-NAME "complex-lab.log")
(define *log-port* #f)
(define *log-path* #f)
(define *script-dir* ".")
(define *session-id* "session")
(define *plot-counter* 0)
(define *gnuplot?* #f)
(define *auto-png?* #t)

;; ---------------- string / port helpers ----------------
(define (trim s)
  (let* ((len (string-length s))
         (a (let loop ((i 0))
              (if (and (< i len) (char-whitespace? (string-ref s i)))
                  (loop (+ i 1))
                  i)))
         (b (let loop ((i len))
              (if (and (> i a) (char-whitespace? (string-ref s (- i 1))))
                  (loop (- i 1))
                  i))))
    (substring s a b)))

(define (capture thunk)
  (let ((p (open-output-string))
        (old (current-output-port)))
    (dynamic-wind
      (lambda () (set-current-output-port p))
      thunk
      (lambda () (set-current-output-port old)))
    (get-output-string p)))

(define (rule ch) (make-string W ch))

(define (pad s n)
  (let ((k (- n (string-length s))))
    (if (> k 0) (string-append s (make-string k #\space)) s)))

(define (center s)
  (let ((k (max 0 (- W (string-length s)))))
    (string-append (make-string (quotient k 2) #\space) s)))

(define (timestamp)
  (strftime "%Y-%m-%d %H:%M:%S" (localtime (current-time))))

(define (script-dir)
  (let* ((argv (command-line))
         (p (if (and (pair? argv) (string? (car argv))) (car argv) "")))
    (let ((path (or (false-if-exception (canonicalize-path p)) p)))
      (let loop ((i (- (string-length path) 1)))
        (cond ((< i 0) ".")
              ((char=? (string-ref path i) #\/)
               (if (= i 0) "/" (substring path 0 i)))
              (else (loop (- i 1))))))))

;; ---------------- logging ----------------
(define (log-open!)
  (let ((path (string-append *script-dir* "/" LOG-NAME)))
    (catch #t
      (lambda ()
        (let ((p (open-file path "a")))
          (set! *log-port* p)
          (set! *log-path* path)
          (format p "~%=========== SESSION START  ~a ===========~%" (timestamp))
          (format p "script dir: ~a~%" *script-dir*)
          (format p "gnuplot: ~a | auto PNG: ~a~%"
                  (if *gnuplot?* "yes" "no") (if *auto-png?* "on" "off"))
          (force-output p)))
      (lambda (key . args)
        (set! *log-path* path)
        (set! *log-port* #f)))))

(define (log-close!)
  (if *log-port*
      (begin
        (format *log-port* "=========== SESSION END    ~a ===========~%~%" (timestamp))
        (force-output *log-port*)
        (close-port *log-port*)
        (set! *log-port* #f))))

(define (emit thunk)
  (let ((s (capture thunk)))
    (display s)
    (force-output)
    (if *log-port*
        (begin
          (format *log-port* "~%[~a]~%" (timestamp))
          (display s *log-port*)
          (force-output *log-port*)))))

(define (report-error key args)
  (display "  !! ERROR: ")
  (if (and (pair? args) (pair? (cdr args)) (string? (cadr args)))
      (display (cadr args))
      (begin (display key) (display " ") (write args)))
  (newline))

(define (guarded title thunk)
  (catch #t
    (lambda () (emit thunk))
    (lambda (key . args)
      (if (eq? key 'quit)
          (apply throw key args)
          (emit (lambda ()
                  (box-open title)
                  (report-error key args)
                  (box-close)))))))

;; ---------------- framing ----------------
(define (box-open title)
  (newline)
  (display (rule #\*)) (newline)
  (display (center (string-append "<<<<  " title "  >>>>"))) (newline)
  (display (rule #\_)) (newline))

(define (box-close)
  (display (rule #\_)) (newline)
  (display (rule #\*)) (newline))

(define (sep) (display (rule #\-)) (newline))

;; ---------------- numbers ----------------
(define (fin? x) (and (real? x) (not (inf? x)) (not (nan? x))))

(define (nf x)
  (let ((v (exact->inexact x)))
    (cond ((not (fin? v)) (number->string v))
          ((= *decimals* 0) (number->string (inexact->exact (round v))))
          (else
           (let ((s (format #f
                            (string-append "~," (number->string *decimals*) "f")
                            v)))
             (if (and (> (string-length s) 1)
                      (char=? (string-ref s 0) #\-)
                      (zero? (string->number s)))
                 (substring s 1)
                 s))))))

(define (gn x) (number->string (exact->inexact x)))

(define (make-c re im) (cons re im))
(define (cre z) (car z))
(define (cim z) (cdr z))

(define (c+ a b) (make-c (+ (cre a) (cre b)) (+ (cim a) (cim b))))
(define (c- a b) (make-c (- (cre a) (cre b)) (- (cim a) (cim b))))

(define (c* a b)
  (make-c (- (* (cre a) (cre b)) (* (cim a) (cim b)))
          (+ (* (cre a) (cim b)) (* (cim a) (cre b)))))

(define (c/ a b)
  (let ((d (+ (* (cre b) (cre b)) (* (cim b) (cim b)))))
    (if (zero? d)
        (error "Division by zero: z2 = 0")
        (make-c (/ (+ (* (cre a) (cre b)) (* (cim a) (cim b))) d)
                (/ (- (* (cim a) (cre b)) (* (cre a) (cim b))) d)))))

(define (cabs z) (sqrt (+ (* (cre z) (cre z)) (* (cim z) (cim z)))))
(define (carg z) (atan (cim z) (cre z)))
(define (deg r) (* r (/ 180.0 PI)))

;; ---------------- forms ----------------
(define (alg-form z)
  (string-append (nf (cre z))
                 (if (negative? (cim z)) " - " " + ")
                 (nf (abs (cim z))) "*i"))

(define (paren z) (string-append "(" (alg-form z) ")"))

(define (arg-str z)
  (string-append (nf (carg z)) " rad   (" (nf (deg (carg z))) " deg)"))

(define (trig-rad z)
  (let ((r (nf (cabs z))) (p (nf (carg z))))
    (string-append r " * (cos(" p ") + i*sin(" p "))")))

(define (trig-deg z)
  (let ((r (nf (cabs z))) (d (nf (deg (carg z)))))
    (string-append r " * (cos(" d " deg) + i*sin(" d " deg))")))

(define (exp-rad z)
  (string-append (nf (cabs z)) " * e^(i*" (nf (carg z)) ")"))

(define (exp-deg z)
  (string-append (nf (cabs z)) " * e^(i*" (nf (deg (carg z))) " deg)"))

;; ---------------- power / roots ----------------
(define (cpow z n)
  (cond ((not (integer? n)) (error "Exponent must be an integer"))
        ((> (abs n) 1000)   (error "Exponent too large: |n| must be <= 1000"))
        ((= n 0) (make-c 1 0))
        ((> n 0) (let loop ((i 1) (acc z))
                   (if (= i n) acc (loop (+ i 1) (c* acc z)))))
        (else (c/ (make-c 1 0) (cpow z (- n))))))

(define (croot z n)
  (cond ((not (integer? n)) (error "Root degree must be an integer"))
        ((<= n 0)           (error "Root degree must be positive"))
        ((> n 100)          (error "Root degree too large: n must be <= 100"))
        (else
         (let* ((r (cabs z))
                (phi (carg z))
                (rn (expt r (/ 1.0 n))))
           (let loop ((k 0) (acc '()))
             (if (= k n)
                 (reverse acc)
                 (let ((ang (/ (+ phi (* 2 PI k)) n)))
                   (loop (+ k 1)
                         (cons (make-c (* rn (cos ang))
                                       (* rn (sin ang)))
                               acc)))))))))

;; ---------------- rendering ----------------
(define (row label value)
  (format #t "  ~a = ~a~%" (pad label 14) value))

(define (show-brief z sym)
  (row sym (alg-form z))
  (row (string-append "|" sym "|") (nf (cabs z)))
  (row (string-append "arg(" sym ")") (arg-str z)))

(define (show-full z sym)
  (row sym (alg-form z))
  (row (string-append "Re(" sym ")") (nf (cre z)))
  (row (string-append "Im(" sym ")") (nf (cim z)))
  (row (string-append "|" sym "|") (nf (cabs z)))
  (row (string-append "arg(" sym ")") (arg-str z))
  (row "trig (rad)" (trig-rad z))
  (row "trig (deg)" (trig-deg z))
  (row "exp (rad)"  (exp-rad z))
  (row "exp (deg)"  (exp-deg z))
  (display "  full view:") (newline)
  (format #t "      ~a = ~a~%" sym (alg-form z))
  (format #t "        = ~a~%" (trig-deg z))
  (format #t "        = ~a~%" (exp-deg z)))

;; ---------------- gnuplot ----------------
(define (gnuplot-available?)
  (zero? (system "command -v gnuplot >/dev/null 2>&1")))

(define (run-gnuplot script persist?)
  (catch #t
    (lambda ()
      (let ((p (open-output-pipe
                 (if persist?
                     "gnuplot -persist 2>/dev/null"
                     "gnuplot 2>/dev/null"))))
        (display script p)
        (force-output p)
        (zero? (close-pipe p))))
    (lambda (key . args) #f)))

(define (datablock name pts)
  (capture
    (lambda ()
      (format #t "~a << EOD~%" name)
      (for-each (lambda (pt)
                  (format #t "~a ~a~%" (gn (car pt)) (gn (cdr pt))))
                pts)
      (display "EOD\n"))))

(define (color-for i)
  (list-ref '("#ff0000" "#0000ff" "#008000" "#ff8c00" "#800080")
              (modulo i 5)))

(define (numbers-plot-cmd entries)
  (capture
    (lambda ()
      (display "plot ")
      (let loop ((i 0) (es entries) (first? #t))
        (if (null? es)
            (newline)
            (begin
              (if (not first?) (display ", \\\n     "))
              (format #t "$P~a using 1:2 with points pt 7 ps 1.8 lc rgb '~a' title '~a'"
                      i (color-for i) (caar es))
              (loop (+ i 1) (cdr es) #f)))))))

(define (plot-numbers-body entries maxmod)
  (if (> maxmod 0)
      (format #t "set object 1 circle at 0,0 size ~a fs empty border lc rgb 'gray60'~%"
              (gn maxmod)))
  (let loop ((i 0) (es entries))
    (if (null? es)
        #t
        (let* ((e (car es)) (sym (car e)) (z (cdr e)) (col (color-for i)))
          (format #t "set arrow ~a from 0,0 to ~a,~a lw 2 lc rgb '~a'~%"
                  (+ i 1) (gn (cre z)) (gn (cim z)) col)
          (format #t "set label ~a '~a' at ~a,~a offset 1,1 tc rgb '~a'~%"
                  (+ i 1) sym (gn (cre z)) (gn (cim z)) col)
          (display (datablock (string-append "$P" (number->string i))
                              (list (cons (cre z) (cim z)))))
          (loop (+ i 1) (cdr es)))))
  (display (numbers-plot-cmd entries)))

(define (plot-roots-body roots)
  (let* ((rn (if (null? roots) 0.0 (cabs (car roots))))
         (pts (map (lambda (w) (cons (cre w) (cim w))) roots)))
    (if (> rn 0)
        (format #t "set object 1 circle at 0,0 size ~a fs empty border lc rgb 'gray60'~%"
                (gn rn)))
    (display (datablock "$G" (append pts (list (car pts)))))
    (display (datablock "$R" pts))
    (let loop ((k 0) (xs roots))
      (if (null? xs)
          #t
          (let ((w (car xs)))
            (format #t "set label ~a 'z_~a' at ~a,~a offset 1,1 tc rgb '#ff0000'~%"
                    (+ k 1) k (gn (cre w)) (gn (cim w)))
            (loop (+ k 1) (cdr xs)))))
    (display "plot $G using 1:2 with lines lc rgb 'gray40' title 'polygon', \\\n")
    (display "     $R using 1:2 with points pt 7 ps 1.8 lc rgb '#ff0000' title 'roots'\n")))

(define (plot-script kind title data)
  (capture
    (lambda ()
      (display "set xlabel 'Re'\nset ylabel 'Im'\n")
      (display "set size ratio -1\nset grid\nset zeroaxis lt 1 lc rgb 'black'\nset key outside\n")
      (format #t "set title '~a'~%" title)
      (let* ((zs (if (eq? kind 'roots) (car data) (map cdr data)))
             (maxmod (apply max (cons 0 (map cabs zs))))
             (R (max 1.0 (* 1.35 maxmod))))
        (format #t "set xrange [~a:~a]~%" (gn (- R)) (gn R))
        (format #t "set yrange [~a:~a]~%" (gn (- R)) (gn R))
        (if (eq? kind 'roots)
            (plot-roots-body (car data))
            (plot-numbers-body data maxmod))))))

(define (open-window! body)
  (let loop ((terms (list "set terminal qt size 760,760\n"
                          "set terminal wxt size 760,760 persist\n"
                          "set terminal x11 size 760,760\n")))
    (if (null? terms)
        #f
        (if (run-gnuplot (string-append (car terms) body) #t)
            #t
            (loop (cdr terms))))))

(define (plot-rows! kind title data window?)
  (let* ((zs (if (eq? kind 'roots) (car data) (map cdr data)))
         (finite-ok (let loop ((xs zs))
                      (cond ((null? xs) #t)
                            ((and (fin? (cre (car xs))) (fin? (cim (car xs))))
                             (loop (cdr xs)))
                            (else #f)))))
    (cond
      ((not finite-ok) (row "plot" "skipped (non-finite value)"))
      ((not *gnuplot?*) (row "plot" "skipped (gnuplot not found)"))
      ((and (not window?) (not *auto-png?*)) (row "plot" "off (auto PNG disabled)"))
      (else
       (set! *plot-counter* (+ *plot-counter* 1))
       (let* ((path (string-append *script-dir* "/plot-" *session-id* "-"
                                   (number->string *plot-counter*) ".png"))
              (body (plot-script kind title data))
              (png-term (string-append "set terminal pngcairo size 800,800 enhanced\n"
                                       "set output '" path "'\n"))
              (png-ok (run-gnuplot (string-append png-term body) #f)))
         (row "plot" (if png-ok path "failed (gnuplot error)"))
         (if window?
             (row "window" (if (open-window! body) "opened" "failed (no display?)"))))))))

;; ---------------- input ----------------
(define (bye)
  (newline)
  (display "  Log saved: ") (display (or *log-path* LOG-NAME)) (newline)
  (display "  Goodbye!") (newline) (newline)
  (log-close!)
  (exit 0))

(define (read-number prompt)
  (display prompt) (force-output)
  (let ((line (read-line)))
    (if (eof-object? line)
        (bye)
        (let ((v (string->number (trim line))))
          (if (and v (real? v))
              v
              (begin (display "  !! Please enter a real number.\n")
                     (read-number prompt)))))))

(define (read-integer prompt)
  (let ((v (read-number prompt)))
    (if (integer? v)
        (inexact->exact v)
        (begin (display "  !! Please enter an integer.\n")
               (read-integer prompt)))))

(define (read-complex name)
  (format #t "  Enter ~a:~%" name)
  (let ((re (read-number (string-append "    Re(" name ") = ")))
        (im (read-number (string-append "    Im(" name ") = "))))
    (make-c re im)))

;; ---------------- actions ----------------
(define (binary title opsym op)
  (newline) (display "  >> ") (display title) (newline)
  (let ((a (read-complex "z1"))
        (b (read-complex "z2")))
    (guarded title
      (lambda ()
        (box-open title)
        (show-brief a "z1")
        (newline)
        (show-brief b "z2")
        (sep)
        (row "expression" (string-append (paren a) " " opsym " " (paren b)))
        (newline)
        (let ((w (op a b)))
          (show-full w "w")
          (plot-rows! 'numbers title
                      (list (cons "z1" a) (cons "z2" b) (cons "w" w)) #f))
        (box-close)))))

(define (inspect-action window?)
  (let ((title (if window? "PLOT:  z" "INSPECT:  z")))
    (newline) (display "  >> ") (display title) (newline)
    (let ((a (read-complex "z")))
      (guarded title
        (lambda ()
          (box-open title)
          (show-full a "z")
          (plot-rows! 'numbers title (list (cons "z" a)) window?)
          (box-close))))))

(define (power-action)
  (newline) (display "  >> POWER:  w = z^n") (newline)
  (let ((a (read-complex "z"))
        (n (read-integer "    n (integer, |n| <= 1000) = ")))
    (guarded "POWER:  w = z^n"
      (lambda ()
        (box-open "POWER:  w = z^n")
        (show-brief a "z")
        (row "n" (number->string n))
        (sep)
        (row "expression" (string-append (paren a) "^" (number->string n)))
        (newline)
        (let ((w (cpow a n)))
          (show-full w "w")
          (plot-rows! 'numbers "POWER:  w = z^n"
                      (list (cons "z" a) (cons "w" w)) #f))
        (box-close)))))

(define (roots-action window?)
  (let ((title (if window? "PLOT ROOTS:  z^(1/n)" "ROOTS:  w = z^(1/n)")))
    (newline) (display "  >> ") (display title) (newline)
    (let ((a (read-complex "z"))
          (n (read-integer "    n (1..100) = ")))
      (guarded title
        (lambda ()
          (box-open title)
          (show-brief a "z")
          (row "n" (number->string n))
          (sep)
          (row "expression" (string-append (paren a) "^(1/" (number->string n) ")"))
          (let ((rs (croot a n)))
            (format #t "  ~a root(s):~%" (length rs))
            (let loop ((k 0) (xs rs))
              (if (null? xs)
                  #t
                  (begin
                    (newline)
                    (show-full (car xs) (string-append "z_" (number->string k)))
                    (loop (+ k 1) (cdr xs)))))
            (plot-rows! 'roots title (list rs n) window?)
            (box-close)))))))

(define (precision-action)
  (newline) (display "  >> DISPLAY PRECISION") (newline)
  (format #t "  Current precision: ~a decimal place(s)~%" *decimals*)
  (let ((n (read-integer "    New precision (0..12) = ")))
    (guarded "DISPLAY PRECISION"
      (lambda ()
        (box-open "DISPLAY PRECISION")
        (if (and (>= n 0) (<= n 12))
            (begin (set! *decimals* n)
                   (row "decimals" (number->string n))
                   (row "pi" (nf PI))
                   (row "1/3" (nf (/ 1 3))))
            (display "  !! Out of range (0..12). Precision unchanged.\n"))
        (box-close)))))

(define (toggle-png-action)
  (set! *auto-png?* (not *auto-png?*))
  (emit (lambda ()
          (box-open "AUTO PNG")
          (row "auto PNG" (if *auto-png?* "on" "off"))
          (box-close))))

;; ---------------- menu / main ----------------
(define (menu)
  (newline)
  (display (rule #\*)) (newline)
  (display (center "<<<<  COMPLEX  NUMBER  LAB  >>>>")) (newline)
  (display (rule #\*)) (newline)
  (display "  [1]  Addition         w = z1 + z2") (newline)
  (display "  [2]  Subtraction      w = z1 - z2") (newline)
  (display "  [3]  Multiplication   w = z1 * z2") (newline)
  (display "  [4]  Division         w = z1 / z2") (newline)
  (display "  [5]  Inspect          Re(z), Im(z), |z|, arg(z)") (newline)
  (display "  [6]  Power            w = z^n") (newline)
  (display "  [7]  Roots            w = z^(1/n)") (newline)
  (format #t "  [8]  Precision        ~a decimal place(s)~%" *decimals*)
  (display "  [9]  Plot z           gnuplot window + PNG") (newline)
  (display "  [0]  Plot roots       gnuplot window + PNG") (newline)
  (format #t "  [p]  Auto PNG         ~a~%" (if *auto-png?* "on" "off"))
  (display "  [q]  Quit") (newline)
  (display (rule #\_)) (newline)
  (display "  Choice: ")
  (force-output))

(define (startup)
  (set! *script-dir* (script-dir))
  (set! *session-id*
        (format #f "~a-~a"
                (strftime "%Y%m%d-%H%M%S" (localtime (current-time)))
                (getpid)))
  (set! *gnuplot?* (gnuplot-available?))
  (log-open!)
  (newline)
  (display (rule #\*)) (newline)
  (display (center "<<<<  COMPLEX  NUMBER  LAB  >>>>")) (newline)
  (display (rule #\*)) (newline)
  (format #t "  Log file: ~a~%" (or *log-path* LOG-NAME))
  (format #t "  gnuplot : ~a~%" (if *gnuplot?* "found" "not found (plots skipped)"))
  (format #t "  auto PNG: ~a~%" (if *auto-png?* "on" "off"))
  (force-output))

(define (main)
  (startup)
  (let loop ()
    (menu)
    (let ((line (read-line)))
      (if (eof-object? line)
          (bye)
          (let ((c (trim line)))
            (cond
              ((string-ci=? c "q") (bye))
              ((string=? c "1") (binary "ADDITION:  w = z1 + z2" "+" c+))
              ((string=? c "2") (binary "SUBTRACTION:  w = z1 - z2" "-" c-))
              ((string=? c "3") (binary "MULTIPLICATION:  w = z1 * z2" "*" c*))
              ((string=? c "4") (binary "DIVISION:  w = z1 / z2" "/" c/))
              ((string=? c "5") (inspect-action #f))
              ((string=? c "6") (power-action))
              ((string=? c "7") (roots-action #f))
              ((string=? c "8") (precision-action))
              ((string=? c "9") (inspect-action #t))
              ((string=? c "0") (roots-action #t))
              ((string-ci=? c "p") (toggle-png-action))
              ((string=? c "") #t)
              (else (display "  !! Unknown command. Use 1..9, 0, p or q.") (newline)))
            (loop))))))

(main)