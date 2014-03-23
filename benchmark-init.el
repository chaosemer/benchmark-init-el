;;; benchmark-init.el --- Benchmarks Emacs require and load calls

;; Copyright (C) 2013 Steve Purcell
;; Copyright (C) 2013-2014 David Holm

;; Author: Steve Purcell
;; Maintainer: David Holm <dholmster@gmail.com>
;; Created: 25 Apr 2013
;; Keywords: benchmark

;; This file is not part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this file.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This is a simple benchmark of calls to Emacs require and load functions.
;; It can be used to keep track of where time is being spent during Emacs
;; startup in order to optimize startup times.
;; The code is based on init-benchmarking.el by Steve Purcell.

;;; Installation:

;; Place this file in your load path and add the following code to the
;; beginning of your Emacs initialization script:

;; (require 'benchmark-init)

;; Data collection will begin as soon as benchmark-init is loaded.

;;; Usage:

;; After Emacs has finished loading the following function will bring up
;; the results:
;;
;;  - benchmark-init/show-durations
;;
;; Data collection can be controlled using the following two functions:
;;
;;  - benchmark-init/activate
;;  - benchmark-init/deactivate

;;; Code:

(require 'tabulated-list)

(defconst benchmark-init/buffer-name "*Benchmark Init*"
  "Name of benchmark-init list buffer.")

(defconst benchmark-init/list-format
  [("Module" 65 t)
   ("Type" 7 t)
   ("ms" 7 (lambda (a b) (< (string-to-number (aref (cadr a) 2))
                            (string-to-number (aref (cadr b) 2))))
    :right-align t)]
  "Benchmark list format.")

(defconst benchmark-init/list-sort-key
  '("ms" . t)
  "Benchmark list sort key.")

(defvar benchmark-init/durations (make-hash-table :test 'equal)
  "A hash table of (MODULE . (LOAD-TYPE LOAD-DURATION)).
LOAD-DURATION is the time taken in milliseconds to load FEATURE.")

(define-derived-mode benchmark-init/list-mode tabulated-list-mode
  "Benchmark Init"
  "Mode for displaying benchmark-init results."
  (setq tabulated-list-format benchmark-init/list-format)
  (setq tabulated-list-padding 2)
  (setq tabulated-list-sort-key benchmark-init/list-sort-key)
  (tabulated-list-init-header))

(defun benchmark-init/show-durations ()
  "Show the benchmark for the specified HASH-TABLE with primary column NAME."
  (interactive)
  (with-current-buffer (get-buffer-create benchmark-init/buffer-name)
    (benchmark-init/list-mode)
    (setq tabulated-list-entries 'benchmark-init/list-entries)
    (tabulated-list-print t)
    (switch-to-buffer (current-buffer))))

(defun benchmark-init/list-entries ()
  "Generate benchmark-init list entries from HASH-TABLE."
  (let (entries)
    (maphash
     (lambda (key value)
       (let ((type (car value))
             (duration (round (cadr value))))
         (push (list key `[,key ,type ,(format "%d" duration)]) entries)))
     benchmark-init/durations)
    entries))

(defun benchmark-init/time-subtract-millis (b a)
  "Calculate the number of milliseconds that have elapsed between B and A."
  (* 1000.0 (float-time (time-subtract b a))))

(defun benchmark-init/add-entry (duration name type)
  "Store DURATION for NAME of TYPE into benchmark table."
  (puthash name (list (symbol-name type) duration)
           benchmark-init/durations))

(defmacro benchmark-init/measure-around (name type inner should-record-p)
  "Save duration spent in NAME of TYPE around INNER if SHOULD-RECORD-P."
  `(let ((entry (symbol-name ,type))
         (start-time (current-time)))
     (prog1
         ,inner
       (let ((duration (benchmark-init/time-subtract-millis
                        (current-time) start-time)))
         (when (funcall ,should-record-p)
           (benchmark-init/add-entry duration ,name ,type))))))

(defadvice require
  (around build-require-durations (feature &optional filename noerror) activate)
  "Note in `benchmark-init/durations' the time taken to require each feature."
  (let ((name (symbol-name feature))
        (already-loaded (memq feature features))
        (should-record-p (lambda ()
                           (and (not already-loaded) (memq feature features)))))
    (benchmark-init/measure-around name 'require ad-do-it should-record-p)))

(defadvice load
  (around build-load-durations (file &optional noerror nomessage nosuffix
                                     must-suffix) activate)
  "Note in `benchmark-init/durations' the time taken to load each file."
  (let* ((name (abbreviate-file-name file))
         (should-record-p (lambda ()
                            (eq (gethash name benchmark-init/durations) nil))))
    (benchmark-init/measure-around name 'load ad-do-it should-record-p)))

(defun benchmark-init/deactivate ()
  "Deactivate benchmark-init."
  (interactive)
  (ad-deactivate 'require)
  (ad-deactivate 'load))

;;;###autoload
(defun benchmark-init/activate ()
  "Activate benchmark-init and start collecting data."
  (interactive)
  (ad-activate 'require)
  (ad-activate 'load))

(define-obsolete-function-alias 'benchmark-init/install
  'benchmark-init/activate)

(provide 'benchmark-init)
;;; benchmark-init.el ends here
