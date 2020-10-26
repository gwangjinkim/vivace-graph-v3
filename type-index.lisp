(in-package :graph-db)

(defstruct (type-index
             (:constructor %make-type-index)
             (:print-function
              (lambda (i s d)
                (declare (ignore d))
                (format s "#<TYPE-INDEX ~A" (type-index-table i)))))
  table
  (locks (map-into (make-array +max-node-types+)
                   #+ccl 'make-lock
                   #+lispworks 'mp:make-lock
                   #+sbcl 'sb-thread:make-mutex))
  (cache
   #+sbcl (make-hash-table :test 'eq :synchronized t)
   #+lispworks (make-hash-table :test 'eq :single-thread nil)
   #+ccl (make-hash-table :test 'eq :shared t)))

(defun make-type-index (location heap)
  (let* ((table (mmap-file location
                           :size (* +max-node-types+ +index-list-bytes+)))
         (idx (%make-type-index :table table)))
    (dotimes (i +max-node-types+)
      (let ((offset (* i +index-list-bytes+)))
        (let ((index-list (make-index-list heap)))
          (serialize-index-list table index-list offset)
          (setf (gethash i (type-index-cache idx)) index-list))))
    idx))

(defun open-type-index (location heap)
  (let* ((table (mmap-file location :create-p nil))
         (idx (%make-type-index :table table)))
    (dotimes (i +max-node-types+)
      (let ((offset (* i +index-list-bytes+)))
        (let ((index-list (deserialize-index-list table offset)))
          (setf (gethash i (type-index-cache idx)) index-list))))
    idx))

(defmethod close-type-index ((index type-index))
  (munmap-file (type-index-table index) :save-p t))

(defgeneric add-to-type-index (node graph &key unless-present))
(defgeneric remove-from-type-index (node graph))

(defmethod type-index-push ((uuid array) (type-id integer) (idx type-index)
                            &key unless-present)
  (let ((lock (aref (type-index-locks idx) type-id)))
    (with-lock (lock)
      (let ((il (gethash type-id (type-index-cache idx))))
        (if unless-present
            (index-list-pushnew uuid il)
            (index-list-push uuid il))
        ;; FIXME: could be optimized to only write the new head
        (serialize-index-list (type-index-table idx)
                              il
                              (* type-id +index-list-bytes+))
        il))))

(defmethod type-index-remove ((uuid array) (type-id integer) (idx type-index))
  (let ((lock (aref (type-index-locks idx) type-id)))
    (with-lock (lock)
      (let ((il (gethash type-id (type-index-cache idx))))
        (remove-from-index-list uuid il)
        (serialize-index-list (type-index-table idx)
                              il
                              (* type-id +index-list-bytes+))
        il))))

(defmethod get-type-index-list ((idx type-index) (type-id integer))
  (gethash type-id (type-index-cache idx)))
