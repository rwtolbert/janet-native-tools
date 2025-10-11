(import spork/sh)
(import spork/path)

(var *verbose* false)
(when (os/getenv "VERBOSE")
  (set *verbose* true))

(defn error-exit [msg &opt code]
  (default code 1)
  (printf msg)
  (os/exit code))

(defn- set-command [cmd todyn]
  "Look for executable on PATH"
  (if (sh/which cmd)
    (setdyn todyn (sh/which cmd))
    (error-exit (string/format "Unable to find command: %s" cmd))))

(defdyn *cmakepath* "Which cmake command to use")

(defn cmake
  "Make a call to cmake."
  [& args]
  (when *verbose*
    (printf "Running cmake %j" args))
  (sh/exec (dyn *cmakepath* "cmake") ;args))

(defn require-cmake
  ``Look for cmake command on PATH, set if found or fail if not``
  []
  (set-command "cmake" *cmakepath*))

(defn declare-cmake
  [&named name source-dir build-dir build-type cmake-flags build-dir cmake-build-flags]
  (assert (string? name))
  (assert (sh/exists? source-dir))
  (default build-dir (path/join "_build" name))
  (default build-type "Release")
  (default cmake-flags @[])
  (def full-cmake-flags @["-B" build-dir "-S" source-dir (string/format "-DCMAKE_BUILD_TYPE=%s" build-type) ;cmake-flags])
  (default cmake-build-flags @["--build" build-dir "--parallel" "--config" build-type])
  (def build-tgt (fn []
                   (unless (sh/exists? (string/format "%s/%s" build-dir "CMakeCache.txt"))
                     (cmake ;full-cmake-flags))
                   (do (cmake ;cmake-build-flags))))
  (def clean-tgt (fn [&]
                   (printf "removing %s" build-dir)
                   (sh/rm build-dir)))
  [build-tgt clean-tgt])

######### GIT ###########
(defdyn *gitpath* "Which git command to use")
(defn require-git []
  (set-command "git" *gitpath*))
(defn git
  "Make a call to git."
  [& args]
  (when *verbose*
    (printf "Running git %j" args))
  (sh/exec (dyn *gitpath* "git") ;args))

######### MAKE ###########
(defdyn *makepath* "Which make command to use")
(defn require-make []
  (set-command "make" *makepath*))
(defn make
  "Make a call to make."
  [& args]
  (when *verbose*
    (printf "Running make %j" args))
  (sh/exec (dyn *makepath* "make") ;args))

######### NINJA ##########
(defdyn *ninjapath* "Which ninja command to use")
(defn require-ninja []
  (set-command "ninja" *ninjapath*))
(defn ninja
  "Make a call to ninja."
  [& args]
  (when *verbose*
    (printf "Running ninja %j" args))
  (sh/exec (dyn *ninjapath* "ninja") ;args))


######### RUST/CARGO ###########

################################
(defn- lib-prefix []
  (if (= (os/which) :windows)
    ""
    "lib"))

(defn- lib-suffix []
  (if (= (os/which) :windows)
    ".lib"
    ".a"))

(defn gen-static-libname
  ``Generate appropriate static lib name``
  [basename]
  (string/format "%s%s%s" (lib-prefix) basename (lib-suffix)))

(defn fix-up-ldflags
  ``Fix up meta file so that linker looks in :syspath for some link libs``
  [name meta-name]
  # TODO - add mod-name and meta-file as arguments along with list of libs to modify
  (def bundle-dir (path/join (dyn *syspath*) name))
  (def meta-file (path/join bundle-dir meta-name))
  (unless (sh/exists? meta-file)
    (printf "Unable to find meta file: %s" meta-file)
    (os/exit 1))
  # get the contents of the current meta file
  (def meta-data (slurp meta-file))
  # find the header/comment if it exists
  (var comment (string/format "# meta file for %s" name))
  (let [parts (string/split "\n" meta-data)]
    (when (string/find "#" (parts 0))
      (set comment (parts 0))))
  # parse the current data into a struct
  (def old-meta (parse meta-data))
  # create new lflags that point to the :syspath location
  (def new-lflags @[(string/format (if (= (os/which) :windows) "/LIBPATH:%s" "-L%s") bundle-dir)])
  # TODO - how to generically pass which lflags to change?
  (loop [item :in (old-meta :lflags)]
    (when (not (string/has-prefix? "-L" item))
      (array/push new-lflags item)))
  (def new-meta-data @{})
  (loop [key :in (keys old-meta)]
    (if (= key :lflags)
      (set (new-meta-data key) new-lflags)
      (set (new-meta-data key) (old-meta key))))
  (spit meta-file (string/format "%s\n\n%m" comment (table/to-struct new-meta-data))))
