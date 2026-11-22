#!/usr/bin/guile -s
!#
;;; ============================================================
;;;   COMPLEX NUMBER LAB  --  Guile Scheme
;;;   auto-log: complex-lab.log (next to the script)
;;; ============================================================

(use-modules (ice-9 format)
             (ice-9 rdelim))

;; ---------------- settings ----------------
(define W 72)
(define *decimals* 4)
(define PI (acos -1))
(define LOG-NAME "complex-lab.log")
(define *log-port* #f)
(define *log-path* #f)

;; ---------------- helpers ----------------
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
    (let loop ((i (- (string-length p) 1)))
      (cond ((< i 0) ".")
            ((char=? (string-ref p i) #\/)
             (if (= i 0) "/" (substring p 0 i)))
            (else (loop (- i 1)))))))

;; ---------------- logging ----------------
(define (log-open!)
  (let ((path (string-append (script-dir) "/" LOG-NAME)))
    (catch #t
      (lambda ()
        (let ((p (open-file path "a")))
          (set! *log-port* p)
          (set! *log-path* path)
          (format p "~%=========== SESSION START  ~a ===========~%" (timestamp))
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

;; print to screen AND append to log
(define (emit thunk)
  (let ((s (call-with-output-string
             (lambda (p) (with-output-to-port p thunk)))))
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
(define (nf x)
  (let ((v (exact->inexact x)))
    (if (= *decimals* 0)
        (number->string (inexact->exact (round v)))
        (let ((s (format #f
                         (string-append "~," (number->string *decimals*) "f")
                         v)))
          (if (and (> (string-length s) 1)
                   (char=? (string-ref s 0) #\-)
                   (zero? (string->number s)))
              (substring s 1)
              s)))))

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
        (show-full (op a b) "w")
        (box-close)))))

(define (inspect-action)
  (newline) (display "  >> INSPECT:  z") (newline)
  (let ((a (read-complex "z")))
    (guarded "INSPECT:  z"
      (lambda ()
        (box-open "INSPECT:  z")
        (show-full a "z")
        (box-close)))))

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
        (show-full (cpow a n) "w")
        (box-close)))))

(define (roots-action)
  (newline) (display "  >> ROOTS:  w = z^(1/n)") (newline)
  (let ((a (read-complex "z"))
        (n (read-integer "    n (1..100) = ")))
    (guarded "ROOTS:  w = z^(1/n)"
      (lambda ()
        (box-open "ROOTS:  w = z^(1/n)")
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
          (box-close))))))

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
  (display "  [q]  Quit") (newline)
  (display (rule #\_)) (newline)
  (display "  Choice: ")
  (force-output))

(define (startup)
  (log-open!)
  (newline)
  (display (rule #\*)) (newline)
  (display (center "<<<<  COMPLEX  NUMBER  LAB  >>>>")) (newline)
  (display (rule #\*)) (newline)
  (if *log-port*
      (format #t "  Log file: ~a   (auto-append)~%" *log-path*)
      (display "  Log file: unavailable (check permissions)\n"))
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
              ((string=? c "5") (inspect-action))
              ((string=? c "6") (power-action))
              ((string=? c "7") (roots-action))
              ((string=? c "8") (precision-action))
              ((string=? c "") #t)
              (else (display "  !! Unknown command. Use 1..8 or q.") (newline)))
            (loop))))))

(main)