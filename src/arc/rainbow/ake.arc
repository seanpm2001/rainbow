
(def match-end (pat str)
  (is (cut str (-:len pat)) pat))

(def is-directory (path)
  (if (dir-exists path) t))

(mac files (root . constraints)
  (let constrain (fn (spec file)
                     (if (is "/" (cut spec -1))
                         (and (is-directory file) 
                              (is (cut spec 0 -1) (last:tokens file #\/)))
                         (is "*" (cut spec 0 1))
                         (or  (is-directory file)
                              (match-end (cut spec 1) file))
                         (is "*" (cut spec -1))
                         (or  (is-directory file) 
                              (headmatch (cut spec 0 -1) (last:tokens file #\/)))))
    `(with  (except (fn specs
                        (fn (file)
                            (if (is file 'describe)
                                `(except ,@specs)
                                (all nil (map [,constrain _ file] specs)))))
             only   (fn specs
                        (fn (file)
                            (if (is file 'describe)
                                `(only ,@specs)
                                (all t   (map [,constrain _ file] specs))))))
      (find-files ,root ,@constraints))))

(def find-files (root . constraints)
  (with (filelist  (if (dir-exists root) 
                       (dir root) 
                       (let fl (list root) (= root ".") fl))
         iterator  nil
         get-file  (fn (s) (string root "/" s))
         allow     (fn (result)
                       (or (no result) 
                           (all t (map [_ result] constraints)))))
    (afn ()
      (let return (fn (file)
                      (if (allow file) 
                          file 
                          (self)))
        (if iterator
            (let result (iterator)
              (if (no result) 
                  (do (wipe iterator) 
                      (self))
                  (return result)))
            filelist
            (let first (get-file:car filelist)
              (zap cdr filelist)
              (while (and filelist first (no:allow first))
                (= first (get-file:car filelist))
                (zap cdr filelist))
              (if (dir-exists first)
                  (do (= iterator (apply find-files first constraints)) (self))
;                  (do (= iterator (apply find-files first nil)) (self))
                  (return first))))))))

(mac pr-files (root . constraints)
  `(let ff (files ,root ,@constraints)
     (while (prn (ff)))))

(with (projects nil
       plugins  nil)
  (mac project (name properties . targets)
    (push name projects)
    (with (flattened (table)
           tdescs    (table))
      (with (names  nil
             ttasks (table)
             tdeps  (table)
             included (table))
        (with (dep-list      (afn (target) 
                                  `(,@(map self tdeps.target) ,target))
               assemble-tasks (afn (deps)
                                  (if deps `(,@(ttasks (car deps)) ,@(self:cdr deps)))))
          (each (target deps desc . tasks) targets
            (push target names)
            (= ttasks.target  tasks)
            (= tdeps.target   deps)
            (= tdescs.target  desc))
          (each target names
            (= flattened.target (assemble-tasks (dedup:flat:dep-list target))))))
      `(mac ,name (invoke (o arg2 nil))
        (with (project-name ',name
               tdescs       ,tdescs
               properties   ',properties
               flattened    ,flattened
               plugins      ',plugins)
          (if (is invoke 'help)
              `(do (maptable (fn (targ desc)
                             (prn "\n" targ " :\n\t" desc))
                             ,tdescs)
                   t)
              (is invoke 'properties)
              `(withs (project-name ',project-name ,@properties)
                 ,@(map (fn (_) `(prn ',(car _) "\t:\t" 
                                      (let value ,(cadr _)
                                           (if (or (isa value 'num) 
                                                   (isa value 'string)
                                                   (isa value 'sym)
                                                   (alist value))
                                               value
                                               "[#((type value))]"))))
                        (pair properties)))
              (is invoke 'show)
              `(each task ',(flattened arg2) (ppr task) (prn))
              `(withs (project-name ',project-name ,@plugins ,@properties)
                ,@(flattened invoke)))))))

  (let add-plugin (fn (name plugin)
                      (push plugin plugins)
                      (push name plugins))
    (mac ake-plugin (plgname args . body)
      `(,add-plugin ',plgname (rfn ,plgname ,args ,@body))))

  (def ake ()
    (load "build.arc")
    (prn `(,(car projects) ,@*argv*))
    (eval `(,(car projects) ,@*argv*))))

(ake-plugin delete (file-spec)
  (withs (delete-file      (fn (file)
                               (prn "deleting " file)
                               (rmfile file))
          delete-directory (fn (directory)
                               (each f (dir directory)
                                 (delete "#(directory)/#(f)"))
                               (delete-file directory)))
    (if (dir-exists file-spec)
        (delete-directory file-spec)
        (file-exists file-spec)
        (delete-file file-spec)
        (whilet f (file-iterator)
          (delete-file f)))))

